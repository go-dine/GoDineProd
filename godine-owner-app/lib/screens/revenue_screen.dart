import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/status_badge.dart';

class RevenueScreen extends StatefulWidget {
  final Restaurant restaurant;
  const RevenueScreen({super.key, required this.restaurant});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

enum DateFilter { today, week, month, all }

class _RevenueScreenState extends State<RevenueScreen> {
  List<Order> _orders = [];
  DateFilter _filter = DateFilter.today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _getDateFrom(DateFilter f) {
    final d = DateTime.now();
    final start = DateTime(d.year, d.month, d.day);
    switch (f) {
      case DateFilter.today:
        return start;
      case DateFilter.week:
        return start.subtract(const Duration(days: 7));
      case DateFilter.month:
        return DateTime(d.year, d.month - 1, d.day);
      case DateFilter.all:
        return null;
    }
  }

  Future<void> _load() async {
    try {
      final orders = await SupabaseService.fetchOrders(
        widget.restaurant.id,
        from: _getDateFrom(_filter),
      );
      if (mounted) setState(() => _orders = orders);
    } catch (_) {
      if (mounted) setState(() => _orders = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = _orders.where((o) => o.status != 'cancelled').toList();
    final totalRevenue = activeOrders.fold<double>(0, (s, o) => s + o.total);
    final completedOrders = activeOrders.where((o) => o.status == 'completed').toList();
    final avgOrder = activeOrders.isNotEmpty ? (totalRevenue / activeOrders.length).round() : 0;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Top items
    final itemCounts = <String, _ItemStat>{};
    for (final o in activeOrders) {
      for (final item in o.items) {
        final stat = itemCounts.putIfAbsent(item.name, () => _ItemStat(item.name, item.emoji));
        stat.qty += item.qty;
        stat.revenue += item.qty * item.price;
      }
    }
    final topItems = itemCounts.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    final top5 = topItems.take(5).toList();

    // Hourly distribution
    final hourlyRevenue = <int, double>{};
    for (final o in activeOrders) {
      final h = DateTime.parse(o.createdAt).toLocal().hour;
      hourlyRevenue[h] = (hourlyRevenue[h] ?? 0) + o.total;
    }
    String peakHourStr = '—';
    if (hourlyRevenue.isNotEmpty) {
      final peak = hourlyRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakHourStr = '${peak.key.toString().padLeft(2, '0')}:00';
    }

    const filterLabels = {
      DateFilter.today: 'Today',
      DateFilter.week: 'This Week',
      DateFilter.month: 'This Month',
      DateFilter.all: 'All Time',
    };

    return RefreshIndicator(
      color: AppColors.lime,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const Text('Revenue', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
          const SizedBox(height: 4),
          const Text('Earnings and order analytics', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),

          // Filter pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DateFilter.values.map((f) {
              final active = _filter == f;
              return GestureDetector(
                onTap: () {
                  setState(() => _filter = f);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.limeAlpha08 : AppColors.surface1,
                    border: Border.all(color: active ? AppColors.limeAlpha30 : AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    filterLabels[f]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? AppColors.lime : AppColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Big revenue card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.limeAlpha18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL REVENUE',
                  style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFmt.format(totalRevenue),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.lime, letterSpacing: -2),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_orders.length} orders · Avg ${currencyFmt.format(avgOrder)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick stats
          Row(
            children: [
              _QuickStat(label: 'Peak Hour', value: peakHourStr),
              const SizedBox(width: 10),
              _QuickStat(label: 'Completed', value: '${completedOrders.length}'),
              const SizedBox(width: 10),
              _QuickStat(label: 'Pending', value: '${_orders.where((o) => o.status == 'pending').length}'),
            ],
          ),
          const SizedBox(height: 14),

          // Top items
          if (top5.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏆 Top Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
                  const SizedBox(height: 16),
                  ...top5.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(item.emoji, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.white)),
                                Text('${item.qty} sold', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text(currencyFmt.format(item.revenue), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.lime)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Order history
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
                const Text('Order History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
                const SizedBox(height: 16),
                if (_orders.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('No orders in this period', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ..._orders.take(20).map((o) => Container(
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
                                    'Table ${o.tableNumber}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('hh:mm a').format(DateTime.parse(o.createdAt).toLocal())} · ${o.items.length} item(s)',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${o.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.lime)),
                                const SizedBox(height: 2),
                                Text(
                                  o.paymentStatus == 'paid' ? 'PAID' : 'UNPAID',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: o.paymentStatus == 'paid' ? AppColors.lime : Color(0xFFFF4444),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                StatusBadge(status: o.status, small: true),
                              ],
                            ),
                          ],
                        ),
                      )),
                  if (_orders.length > 20)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Showing 20 of ${_orders.length} orders',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemStat {
  final String name;
  final String emoji;
  int qty = 0;
  double revenue = 0;
  _ItemStat(this.name, this.emoji);
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}
