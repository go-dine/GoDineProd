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

  @override
  Widget build(BuildContext context) {
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
            ..._orders.map((o) => OrderCard(
                  order: o,
                  onAdvanceStatus: _advanceStatus,
                  onComplete: _handleComplete,
                )),
        ],
      ),
    );
  }
}
