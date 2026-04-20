import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_hours_screen.dart';
import 'analytics_screen.dart';
import 'announcement_screen.dart';
import 'suggestions_screen.dart';
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
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;

  static const String _razorpayKeyId = 'rzp_test_Sftzc4oWuOEUPH';
  static const String _supabaseUrl = 'https://qqnrucnsvupfywyzlofa.supabase.co';

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.subscribeToOrders(
      'owner-overview-${widget.restaurant.id}', 
      widget.restaurant.id, 
      (payload) => _load(),
    );

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.unsubscribe(_channel!);
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await SupabaseService.fetchTodayAllOrders(widget.restaurant.id);
      final dishes = await SupabaseService.fetchDishes(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        final activeOrders = orders.where((o) => o.status != 'cancelled').toList();
        _orderCount = activeOrders.length;
        _revenue = activeOrders.fold(0, (sum, o) => sum + o.total);
        _pending = activeOrders.where((o) => o.status == 'pending').length;
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

  // ── Razorpay Payment Flow ──

  Future<void> _startRazorpayCheckout() async {
    if (_isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    try {
      // 1. Create order via Edge Function
      final res = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/create-razorpay-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': 24900, 'currency': 'INR'}),
      );

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Failed to create order');
      }

      final orderData = jsonDecode(res.body);

      // 2. Open Razorpay native checkout
      final options = {
        'key': _razorpayKeyId,
        'amount': orderData['amount'],
        'currency': orderData['currency'],
        'name': 'Go Dine',
        'description': 'Subscription Renewal',
        'order_id': orderData['id'],
        'theme': {'color': '#b6ff2a'},
      };
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFF7F1D1D),
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/verify-razorpay-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
          'restaurant_id': widget.restaurant.id,
          'plan_id': 2,
        }),
      );

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Verification failed');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment successful! Subscription extended.'),
            backgroundColor: Color(0xFF064E3B),
          ),
        );
      }
      _load(); // Reload data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Verification error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFF7F1D1D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessingPayment = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
          backgroundColor: const Color(0xFF7F1D1D),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessingPayment = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External wallet selected: ${response.walletName}')),
      );
    }
  }

  Widget? _buildSubscriptionBanner() {
    final subEnd = widget.restaurant.subscriptionEnd;
    if (subEnd == null) return null;

    final diffDays = subEnd.difference(DateTime.now()).inDays;
    final isTrial = widget.restaurant.isTrial;
    final typeStr = isTrial ? 'Trial' : 'Subscription';

    Color bgColor;
    Color borderColor;
    Color textColor;
    String text;
    IconData icon;

    if (diffDays <= 0) {
      bgColor = const Color(0xFF450A0A);
      borderColor = const Color(0xFF7F1D1D);
      textColor = const Color(0xFFFCA5A5);
      text = 'Your $typeStr has expired. Renew to continue.';
      icon = Icons.warning_amber_rounded;
    } else if (diffDays <= 7) {
      bgColor = const Color(0xFF451A03);
      borderColor = const Color(0xFF78350F);
      textColor = const Color(0xFFFCD34D);
      text = 'Your $typeStr ends in $diffDays day${diffDays > 1 ? 's' : ''}. Renew soon.';
      icon = Icons.hourglass_bottom_rounded;
    } else {
      bgColor = const Color(0xFF064E3B);
      borderColor = const Color(0xFF065F46);
      textColor = const Color(0xFF6EE7B7);
      text = '$typeStr Active: $diffDays day${diffDays > 1 ? 's' : ''} remaining.';
      icon = Icons.check_circle_outline_rounded;
    }

    final String btnLabel = diffDays <= 0
        ? 'Renew Now'
        : diffDays <= 7
            ? 'Renew Early'
            : 'Upgrade';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _startRazorpayCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                  : Text(btnLabel),
            ),
          ),
        ],
      ),
    );
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

          if (_buildSubscriptionBanner() != null) _buildSubscriptionBanner()!,

          // Stats row 1
          Row(
            children: [
              StatCard(label: "Today's Orders", value: '$_orderCount', sub: 'Total orders today', accent: true),
              const SizedBox(width: 12),
              StatCard(label: 'Revenue', value: revenueStr, sub: "Today's earnings", accent: true),
            ],
          )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
          Row(
            children: [
              StatCard(label: 'Pending', value: '$_pending', sub: 'Awaiting action'),
              const SizedBox(width: 12),
              StatCard(label: 'Menu Items', value: '$_activeDishes', sub: 'Active dishes'),
            ],
          )
          .animate()
          .fadeIn(duration: 400.ms, delay: 100.ms)
          .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 100.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),

          const Text('Store Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _ManagementCard(
                title: 'Timings',
                icon: Icons.access_time_filled_rounded,
                color: Colors.orangeAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveHoursScreen(restaurant: widget.restaurant))),
              ),
              _ManagementCard(
                title: 'Announce',
                icon: Icons.campaign_rounded,
                color: Colors.pinkAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementScreen(restaurant: widget.restaurant))),
              ),
              _ManagementCard(
                title: 'Analytics',
                icon: Icons.analytics_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen(restaurant: widget.restaurant))),
              ),
              _ManagementCard(
                title: 'AI Insights',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.lime,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsScreen(restaurant: widget.restaurant))),
              ),
            ],
          ),
          const SizedBox(height: 32),

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

class _ManagementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
