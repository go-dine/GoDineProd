import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/order_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  final Restaurant restaurant;
  final void Function(int count)? onPendingCount;
  const OrdersScreen({super.key, required this.restaurant, this.onPendingCount});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.subscribeToOrders(
      'owner-orders-screen-${widget.restaurant.id}',
      widget.restaurant.id,
      (payload) {
        _load();
      },
    );
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await SupabaseService.fetchTodayActiveOrders(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
      widget.onPendingCount?.call(orders.where((o) => o.status == 'pending').length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _advanceStatus(String id, String status) {
    if (status == 'preparing') {
      _showEtaDialog(id, status);
    } else {
      _performUpdate(id, status);
    }
  }

  void _showEtaDialog(String id, String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Preparation Time', style: TextStyle(color: AppColors.white)),
        content: const Text('How long will this take?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _performUpdate(id, status, eta: '10 mins'); }, child: const Text('10 mins', style: TextStyle(color: AppColors.lime))),
          TextButton(onPressed: () { Navigator.pop(ctx); _performUpdate(id, status, eta: '20 mins'); }, child: const Text('20 mins', style: TextStyle(color: AppColors.lime))),
          TextButton(onPressed: () { Navigator.pop(ctx); _performUpdate(id, status, eta: '30 mins'); }, child: const Text('30 mins', style: TextStyle(color: AppColors.lime))),
          TextButton(onPressed: () { Navigator.pop(ctx); _performUpdate(id, status); }, child: const Text('Skip', style: TextStyle(color: AppColors.muted))),
        ],
      ),
    );
  }

  Future<void> _performUpdate(String id, String status, {String? eta}) async {
    try {
      await SupabaseService.updateOrderStatus(id, status, estimatedTime: eta);
      setState(() {
        _orders = _orders.map((o) {
          if (o.id == id) return o.copyWith(status: status, estimatedTime: eta ?? o.estimatedTime);
          return o;
        }).toList();
      });
      widget.onPendingCount?.call(_orders.where((o) => o.status == 'pending').length);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status')),
        );
      }
    }
  }

  void _handleComplete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Complete Order', style: TextStyle(color: AppColors.white)),
        content: const Text('Mark this order as completed?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performUpdate(id, 'completed');
            },
            child: const Text('Complete', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
  }

  void _handleCancel(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Cancel Order', style: TextStyle(color: AppColors.white)),
        content: const Text('Are you sure you want to cancel this order?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performUpdate(id, 'cancelled');
            },
            child: const Text('Cancel Order', style: TextStyle(color: Color(0xFFFF4444))),
          ),
        ],
      ),
    );
  }

  void _handleSendBill(String tableNumber, List<String> ids) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Send Bill', style: TextStyle(color: AppColors.white)),
        content: Text('Send final bill to Table $tableNumber? This will clear these orders from your active view.', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.sendTableBill(ids);
                _load();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send bill')),
                  );
                }
              }
            },
            child: const Text('Send Bill', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Order>> tableGroups = {};
    for (final o in _orders) {
      tableGroups.putIfAbsent(o.tableNumber, () => []).add(o);
    }
    
    final tables = tableGroups.keys.toList()..sort();

    return RefreshIndicator(
      color: AppColors.lime,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const Text('Live Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
          const SizedBox(height: 4),
          const Text('Auto-refreshes · Pull to refresh', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 22),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Text('⏳', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 12),
                    Text('Loading orders...', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
              ),
            )
          else if (_orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Text('✅', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 12),
                    Text('No active orders right now', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
              ),
            )
          else
            ...tables.map((table) {
              final groupOrders = tableGroups[table]!;
              final groupTotal = groupOrders.fold<double>(0, (sum, o) => sum + o.total);
              final hasCompletedOrReady = groupOrders.any((o) => o.status == 'completed' || o.status == 'ready' || o.status == 'preparing');
              final orderIds = groupOrders.map((o) => o.id).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Table $table', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
                        Text('Total: ₹${groupTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.lime)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...groupOrders.map((o) => OrderCard(
                          order: o,
                          onAdvanceStatus: _advanceStatus,
                          onComplete: _handleComplete,
                          onCancel: _handleCancel,
                        )),
                    if (hasCompletedOrReady)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: const Color(0xFF050505),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: () => _handleSendBill(table, orderIds),
                            child: Text('📋 Send Bill to Table (₹${groupTotal.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
