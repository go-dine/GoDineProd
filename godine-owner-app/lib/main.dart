import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'theme.dart';
import 'app_config.dart';
import 'models/restaurant.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/overview_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/revenue_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/qr_codes_screen.dart';
import 'services/notification_service.dart';
import 'models/order.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.bg,
    statusBarIconBrightness: Brightness.light,
  ));
  // Launch the UI immediately — initialization happens inside the splash screen
  runApp(const GoDineApp());
}

class GoDineApp extends StatelessWidget {
  const GoDineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Dine',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Restaurant? _restaurant;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initAndAutoLogin();
  }

  Future<void> _initAndAutoLogin() async {
    try {
      // Initialize Supabase (with timeout)
      await SupabaseService.init().timeout(const Duration(seconds: 5));
    } catch (_) {
      // If Supabase init fails/times out, we'll just show login screen
    }

    try {
      // Initialize notifications (with timeout, non-blocking)
      await NotificationService.init().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Notifications are non-critical
    }

    Restaurant? restaurant;
    try {
      // Try auto-login (with timeout)
      restaurant = await SupabaseService.autoLogin()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isInitializing = false;
        _restaurant = restaurant;
      });
    }
  }

  void _handleLogin(Restaurant restaurant) {
    setState(() => _restaurant = restaurant);
  }

  Future<void> _handleLogout() async {
    await SupabaseService.clearAuth();
    setState(() => _restaurant = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_restaurant != null) {
      return _MainScaffold(restaurant: _restaurant!, onLogout: _handleLogout);
    }

    return LoginScreen(
      onLogin: _handleLogin,
      isInitializing: _isInitializing,
    );
  }
}

class _MainScaffold extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onLogout;

  const _MainScaffold({required this.restaurant, required this.onLogout});

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  int _currentIndex = 0;
  int _pendingCount = 0;
  RealtimeChannel? _adminChannel;

  @override
  void initState() {
    super.initState();
    _adminChannel = SupabaseService.subscribeToOrders(
      'owner-notifications-${widget.restaurant.id}',
      widget.restaurant.id,
      (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final newRecord = payload.newRecord;
          if (newRecord != null) {
            final order = Order.fromJson(newRecord);
            if (order.status == 'pending') {
              NotificationService.showNewOrderNotification(order);
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    if (_adminChannel != null) {
      SupabaseService.unsubscribe(_adminChannel!);
    }
    super.dispose();
  }

  void _onPendingCount(int count) {
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OverviewScreen(restaurant: widget.restaurant),
      OrdersScreen(restaurant: widget.restaurant, onPendingCount: _onPendingCount),
      RevenueScreen(restaurant: widget.restaurant),
      MenuScreen(restaurant: widget.restaurant),
      QrCodesScreen(restaurant: widget.restaurant),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset('assets/splash-icon.png', height: 24, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.restaurant.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lime),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, size: 20, color: AppColors.muted),
            tooltip: 'Share Menu Link',
            onPressed: () {
              final url = AppConfig.menuUrl(widget.restaurant.slug);
              Share.share(
                '${widget.restaurant.name} — Order from our menu!\n$url',
              );
            },
          ),
          GestureDetector(
            onTap: widget.onLogout,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface1,
          selectedItemColor: AppColors.lime,
          unselectedItemColor: AppColors.muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(icon: Text('📊', style: TextStyle(fontSize: 20)), label: 'Overview'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _pendingCount > 0,
                label: Text(
                  '$_pendingCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                ),
                backgroundColor: AppColors.lime,
                child: const Text('🧾', style: TextStyle(fontSize: 20)),
              ),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(icon: Text('💰', style: TextStyle(fontSize: 20)), label: 'Revenue'),
            const BottomNavigationBarItem(icon: Text('🍽', style: TextStyle(fontSize: 20)), label: 'Menu'),
            const BottomNavigationBarItem(icon: Text('📱', style: TextStyle(fontSize: 20)), label: 'QR Codes'),
          ],
        ),
      ),
    );
  }
}
