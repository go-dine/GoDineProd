import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OverviewScreen extends StatefulWidget {
  final Restaurant restaurant;
  const OverviewScreen({super.key, required this.restaurant});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _orderCount = 0;
  double _revenue = 0;
  int _pending = 0;
  int _activeDishes = 0;
  List<Order> _recentOrders = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.subscribeToOrders(
      'owner-overview-${widget.restaurant.id}', 
      widget.restaurant.id, 
      (payload) => _load(),
    );
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await SupabaseService.fetchTodayAllOrders(widget.restaurant.id);
      final dishes = await SupabaseService.fetchDishes(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _orderCount = orders.length;
        _revenue = orders.fold(0, (sum, o) => sum + o.total);
        _pending = orders.where((o) => o.status == 'pending').length;
        _activeDishes = dishes.where((d) => d.available).length;
        _recentOrders = orders.reversed.take(5).toList();
      });
    } catch (_) {}
  }

  String _timeAgo(String iso) {
    final diff = DateTime.now().difference(DateTime.parse(iso)).inSeconds;
    if (diff < 60) return 'just now';
    if (diff < 3600) return '${diff ~/ 60} min ago';
    return '${diff ~/ 3600} hr ago';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final revenueStr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(_revenue);

    return RefreshIndicator(
      color: AppColors.lime,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
          const SizedBox(height: 4),
          Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 22),

          // Stats row 1
          Row(
            children: [
              StatCard(label: "Today's Orders", value: '$_orderCount', sub: 'Total orders today', accent: true),
              const SizedBox(width: 12),
              StatCard(label: 'Revenue', value: revenueStr, sub: "Today's earnings", accent: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatCard(label: 'Pending', value: '$_pending', sub: 'Awaiting action'),
              const SizedBox(width: 12),
              StatCard(label: 'Menu Items', value: '$_activeDishes', sub: 'Active dishes'),
            ],
          ),
          const SizedBox(height: 20),

          // Recent orders
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
                ),
                const SizedBox(height: 16),
                if (_recentOrders.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Text('🕐', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('No orders yet today', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_recentOrders.map((o) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Table ${o.tableNumber} · ₹${o.total.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_timeAgo(o.createdAt)} · ${o.items.length} item(s)',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: o.status, small: true),
                          ],
                        ),
                      ))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
