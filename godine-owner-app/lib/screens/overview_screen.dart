import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shimmer/shimmer.dart';
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
import '../app_config.dart';
import '../services/notification_service.dart';

class OverviewScreen extends StatefulWidget {
  final Restaurant restaurant;
  const OverviewScreen({super.key, required this.restaurant});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Restaurant _restaurant;
  int _orderCount = 0;
  double _revenue = 0;
  int _pending = 0;
  int _activeDishes = 0;
  List<Order> _recentOrders = [];
  RealtimeChannel? _channel;
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;
  bool _isLoading = true;
  int _selectedPlanId = 2;

  static const String _supabaseUrl = 'https://qqnrucnsvupfywyzlofa.supabase.co';

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _load();
    _channel = SupabaseService.subscribeToOrders(
      'owner-overview-${_restaurant.id}', 
      _restaurant.id, 
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
    setState(() => _isLoading = true);
    try {
      final updatedRestaurant = await SupabaseService.fetchCurrentRestaurant();
      final orders = await SupabaseService.fetchTodayAllOrders(_restaurant.id);
      final dishes = await SupabaseService.fetchDishes(_restaurant.id);
      if (!mounted) return;
      setState(() {
        if (updatedRestaurant != null) _restaurant = updatedRestaurant;
        final activeOrders = orders.where((o) => o.status != 'cancelled').toList();
        _orderCount = activeOrders.length;
        _revenue = activeOrders.fold(0, (sum, o) => sum + o.total);
        _pending = activeOrders.where((o) => o.status == 'pending').length;
        _activeDishes = dishes.where((d) => d.available).length;
        _recentOrders = orders.reversed.take(5).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
    _checkSubscriptionStatus();
  }

  void _checkSubscriptionStatus() {
    if (_restaurant.plan == 'lifetime') return;
    final subEnd = _restaurant.subscriptionEnd;
    if (subEnd == null) return;

    final diffDays = subEnd.difference(DateTime.now()).inDays;
    if (diffDays <= 7) {
      final msg = diffDays <= 0 
          ? 'Your GoDine subscription has expired. Please renew to continue accepting orders.'
          : 'Your GoDine subscription expires in $diffDays days. Renew now to avoid interruption.';
      
      NotificationService.showLocalNotification(
        id: 999, // Unique ID for subscription alerts
        title: '💳 Payment Due',
        body: msg,
      );
    }
  }

  String _timeAgo(String iso) {
    final diff = DateTime.now().difference(DateTime.parse(iso)).inSeconds;
    if (diff < 60) return 'just now';
    if (diff < 3600) return '${diff ~/ 60} min ago';
    return '${diff ~/ 3600} hr ago';
  }

  // ── Razorpay Payment Flow ──

  void _showPlanSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Your Plan', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select a subscription tier to upgrade your experience.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 24),
            
            _PlanOption(
              title: 'Advanced Pro',
              price: '₹249',
              subtitle: 'Monthly • All premium features',
              onTap: () {
                Navigator.pop(ctx);
                _selectedPlanId = 2;
                _startRazorpayCheckout(24900);
              },
            ),
            const SizedBox(height: 12),
            
            _PlanOption(
              title: 'Lifetime Access',
              price: '₹3,500',
              subtitle: 'One-time • Never pay again',
              isBestValue: true,
              onTap: () {
                Navigator.pop(ctx);
                _selectedPlanId = 3;
                _startRazorpayCheckout(350000);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _startRazorpayCheckout(int amountInPaise) async {
    if (_isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/create-razorpay-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amountInPaise, 'currency': 'INR'}),
      );

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Failed to create order');
      }

      final orderData = jsonDecode(res.body);

      final options = {
        'key': AppConfig.razorpayKeyId,
        'amount': orderData['amount'],
        'currency': orderData['currency'],
        'name': 'Go Dine',
        'description': 'Plan Upgrade',
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
          'restaurant_id': _restaurant.id,
          'plan_id': _selectedPlanId,
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
      _load();
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
    final subEnd = _restaurant.subscriptionEnd;
    if (subEnd == null) return null;

    final diffDays = subEnd.difference(DateTime.now()).inDays;
    final isTrial = _restaurant.isTrial;
    final typeStr = isTrial ? 'Trial' : 'Subscription';
    final renewDateStr = DateFormat('dd MMM yyyy').format(subEnd);

    Color bgColor;
    Color borderColor;
    Color textColor;
    String text;
    IconData icon;

    if (diffDays <= 0) {
      bgColor = const Color(0xFF450A0A);
      borderColor = const Color(0xFF7F1D1D);
      textColor = const Color(0xFFFCA5A5);
      text = 'Your $typeStr has expired (Renew Date: $renewDateStr). Renew to continue.';
      icon = Icons.warning_amber_rounded;
    } else if (diffDays <= 7) {
      bgColor = const Color(0xFF451A03);
      borderColor = const Color(0xFF78350F);
      textColor = const Color(0xFFFCD34D);
      text = 'Your $typeStr ends in $diffDays day${diffDays > 1 ? 's' : ''} (Renew Date: $renewDateStr). Renew soon.';
      icon = Icons.hourglass_bottom_rounded;
    } else {
      bgColor = const Color(0xFF064E3B);
      borderColor = const Color(0xFF065F46);
      textColor = const Color(0xFF6EE7B7);
      text = '$typeStr Active: $diffDays day${diffDays > 1 ? 's' : ''} remaining (Renew Date: $renewDateStr).';
      icon = Icons.check_circle_outline_rounded;
    }

    final String btnLabel = diffDays <= 0 ? 'Renew Now' : diffDays <= 7 ? 'Renew Early' : 'Upgrade';

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
              onPressed: _isProcessingPayment ? null : _showPlanSelectionDialog,
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600;
    
    int statColumns = isDesktop ? 4 : (isTablet ? 2 : 2);
    int toolColumns = isDesktop ? 4 : (isTablet ? 3 : 2);
    double horizontalPadding = isDesktop ? (width - 1000) / 2 : 20;
    if (horizontalPadding < 20) horizontalPadding = 20;

    final dateStr = DateFormat('EEEE, dd MMM').format(DateTime.now());
    final revenueStr = '₹${_revenue.toStringAsFixed(0)}';

    return RefreshIndicator(
      color: AppColors.lime,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: _isLoading 
        ? _buildSkeleton(statColumns, toolColumns, horizontalPadding) 
        : _buildContent(dateStr, revenueStr, statColumns, toolColumns, horizontalPadding),
    );
  }

  Widget _buildSkeleton(int statCols, int toolCols, double px) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface1,
      highlightColor: AppColors.surface2,
      child: ListView(
        padding: EdgeInsets.fromLTRB(px, 16, px, 40),
        children: [
          Container(width: 150, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(width: 200, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 22),
          
          // Stats grid skeleton
          GridView.count(
            crossAxisCount: statCols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: List.generate(4, (index) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))),
          ),
          const SizedBox(height: 32),
          
          Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          
          // Grid skeleton
          GridView.count(
            crossAxisCount: toolCols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: List.generate(4, (index) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ),
          const SizedBox(height: 32),
          
          // Orders list skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: List.generate(3, (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 100, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 4),
                          Container(width: 150, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                    ),
                    Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                  ],
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String dateStr, String revenueStr, int statCols, int toolCols, double px) {
    return ListView(
      padding: EdgeInsets.fromLTRB(px, 16, px, 40),
      children: [
        const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
        const SizedBox(height: 4),
        Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 22),

        if (_buildSubscriptionBanner() != null) _buildSubscriptionBanner()!,

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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveHoursScreen(restaurant: _restaurant))),
            ),
            _ManagementCard(
              title: 'Announce',
              icon: Icons.campaign_rounded,
              color: Colors.pinkAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementScreen(restaurant: _restaurant))),
            ),
            _ManagementCard(
              title: 'Analytics',
              icon: Icons.analytics_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen(restaurant: _restaurant))),
            ),
            _ManagementCard(
              title: 'AI Insights',
              icon: Icons.auto_awesome_rounded,
              color: AppColors.lime,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsScreen(restaurant: _restaurant))),
            ),
          ],
        ),
        const SizedBox(height: 32),

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
                ..._recentOrders.map((o) => Container(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                o.paymentStatus == 'paid' ? 'PAID' : 'UNPAID',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: o.paymentStatus == 'paid' ? AppColors.lime : const Color(0xFFFF4444),
                                ),
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(status: o.status, small: true),
                            ],
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool isBestValue;
  final VoidCallback onTap;

  const _PlanOption({
    required this.title,
    required this.price,
    required this.subtitle,
    this.isBestValue = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: isBestValue ? AppColors.limeAlpha30 : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(4)),
                          child: const Text('BEST VALUE', style: TextStyle(color: AppColors.bg, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
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
