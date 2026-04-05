import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../app_config.dart';
import '../models/restaurant.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'overview_screen.dart';
import 'orders_screen.dart';
import 'revenue_screen.dart';
import 'menu_screen.dart';
import 'qr_codes_screen.dart';
import 'feedback_screen.dart';
import 'admin_dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Restaurant? _restaurant;
  bool _isAdmin = false;
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
    } catch (e) {
      debugPrint('Supabase Initialization Failed: $e');
      // If Supabase init fails, we continue to login screen but might be in a broken state
    }

    try {
      // Initialize notifications (with timeout, non-blocking)
      await NotificationService.init().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Notifications are non-critical
    }

    bool isAdmin = false;
    try {
      isAdmin = await SupabaseService.getSavedAdminAuth();
    } catch (_) {}

    Restaurant? restaurant;
    if (!isAdmin) {
      try {
        restaurant = await SupabaseService.autoLogin()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Auto-login error: $e');
      }
    }

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isAdmin = isAdmin;
          _restaurant = restaurant;
        });
        if (restaurant != null) {
          _registerFcmToken(restaurant.id);
        }
      }
    }

    Future<void> _registerFcmToken(String restaurantId) async {
      try {
        final token = await NotificationService.getDeviceToken();
        if (token != null) {
          final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';
          await SupabaseService.registerFcmToken(restaurantId, token, platform);
        }
      } catch (e) {
        debugPrint('Failed to register FCM token: $e');
      }
    }

  void _handleLogin(Restaurant restaurant) {
    setState(() => _restaurant = restaurant);
    _registerFcmToken(restaurant.id);
  }

  void _handleAdminLogin() {
    setState(() => _isAdmin = true);
  }

  Future<void> _handleLogout() async {
    await SupabaseService.clearAuth();
    await SupabaseService.clearAdminAuth();
    setState(() {
      _restaurant = null;
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdmin && _restaurant == null) {
      return AdminDashboardScreen(
        onLogout: _handleLogout,
        onImpersonate: _handleLogin,
      );
    }
    
    if (_restaurant != null) {
      return MainScaffold(
        restaurant: _restaurant!, 
        onLogout: () {
          if (_isAdmin) {
            setState(() => _restaurant = null);
          } else {
            _handleLogout();
          }
        },
      );
    }

    return LoginScreen(
      onLogin: _handleLogin,
      onAdminLogin: _handleAdminLogin,
      isInitializing: _isInitializing,
    );
  }
}

class MainScaffold extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onLogout;

  const MainScaffold({super.key, required this.restaurant, required this.onLogout});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
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

    // Subscribe to waiter calls
    SupabaseService.client
        .channel('waiter-calls-${widget.restaurant.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'waiter_calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurant.id,
          ),
          callback: (payload) {
            final nr = payload.newRecord;
            if (nr != null) {
              NotificationService.showLocalNotification(
                id: nr['id'].hashCode,
                title: '🔔 Waiter Call (Table ${nr['table_number']})',
                body: 'A customer is requesting assistance.',
              );
            }
          },
        )
        .subscribe();
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
      FeedbackScreen(restaurant: widget.restaurant),
      MenuScreen(restaurant: widget.restaurant),
      QrCodesScreen(restaurant: widget.restaurant),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
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
            const BottomNavigationBarItem(icon: Text('💬', style: TextStyle(fontSize: 20)), label: 'Feedback'),
            const BottomNavigationBarItem(icon: Text('🍽', style: TextStyle(fontSize: 20)), label: 'Menu'),
            const BottomNavigationBarItem(icon: Text('📱', style: TextStyle(fontSize: 20)), label: 'QR Codes'),
          ],
        ),
      ),
    ));
  }
}
