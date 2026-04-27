import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'waiter_calls_screen.dart';

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
    // Unregister FCM token before clearing auth
    if (_restaurant != null) {
      try {
        final token = await NotificationService.getDeviceToken();
        if (token != null) {
          await SupabaseService.removeFcmToken(_restaurant!.id, token);
        }
      } catch (e) {
        debugPrint('Logout FCM cleanup failed: $e');
      }
    }

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
        onLogout: () async {
          if (_isAdmin) {
            // If admin is impersonating, we should unregister the token for THIS restaurant 
            // before returning to admin view.
            try {
              final token = await NotificationService.getDeviceToken();
              if (token != null) {
                await SupabaseService.removeFcmToken(_restaurant!.id, token);
              }
            } catch (_) {}
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
  int _waiterCallCount = 0;
  RealtimeChannel? _adminChannel;
  RealtimeChannel? _waiterChannel;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _waiterCallsSubscription;
  StreamSubscription? _billRequestsSubscription;
  StreamSubscription? _paymentsSubscription;

  @override
  void initState() {
    super.initState();
    _adminChannel = SupabaseService.subscribeToOrders(
      'owner-notifications-${widget.restaurant.id}',
      widget.restaurant.id,
      (payload) {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final nr = payload.newRecord;
          if (nr != null) {
            final order = Order.fromJson(nr);
            // Only show system notification if NOT on Orders tab (index 1)
            // If on Orders tab, the screen itself shows a banner.
            if (_currentIndex != 1) {
              NotificationService.showNewOrderNotification(order);
            }
          }
        }
      },
    );

    // 3. Listen for Waiter Calls
    _waiterCallsSubscription = Supabase.instance.client
        .from('waiter_calls')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', widget.restaurant.id)
        .listen((data) {
          if (data.isNotEmpty) {
            final latest = data.last;
            final isCompleted = latest['is_completed'] ?? false;
            final calledAt = DateTime.parse(latest['created_at']);
            
            // Only notify if it's very recent (within last 30s) and not completed
            if (!isCompleted && DateTime.now().difference(calledAt).inSeconds < 30) {
              // Only show system notification if NOT on the calls tab
              if (_currentIndex != 2) {
                NotificationService.showWaiterCallNotification(
                  tableNumber: latest['table_number'].toString(),
                  callId: latest['id'],
                );
              }
              HapticFeedback.heavyImpact();
            }
          }
        });

    // 4. Listen for Bill Requests
    _billRequestsSubscription = Supabase.instance.client
        .from('bill_requests')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', widget.restaurant.id)
        .listen((data) {
          if (data.isNotEmpty) {
            final latest = data.last;
            final isCompleted = latest['is_completed'] ?? false;
            final requestedAt = DateTime.parse(latest['created_at']);
            
            if (!isCompleted && DateTime.now().difference(requestedAt).inSeconds < 30) {
              NotificationService.showBillRequestNotification(
                tableNumber: latest['table_number'].toString(),
                requestId: latest['id'],
              );
              HapticFeedback.vibrate();
            }
          }
        });

    // 5. Listen for Payments
    _paymentsSubscription = Supabase.instance.client
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', widget.restaurant.id)
        .listen((data) {
          if (data.isNotEmpty) {
            final latest = data.last;
            final status = latest['status'];
            final createdAt = DateTime.parse(latest['created_at']);
            
            if (status == 'successful' && DateTime.now().difference(createdAt).inSeconds < 30) {
              NotificationService.showPaymentNotification(
                tableNumber: 'Unknown', // Payment table doesn't have table_number, might need to link via order_id
                amount: latest['amount'].toString(),
              );
            }
          }
        });

    _loadWaiterCallCount();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _waiterCallsSubscription?.cancel();
    _billRequestsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    if (_adminChannel != null) {
      SupabaseService.unsubscribe(_adminChannel!);
    }
    if (_waiterChannel != null) {
      SupabaseService.unsubscribe(_waiterChannel!);
    }
    super.dispose();
  }

  Future<void> _loadWaiterCallCount() async {
    try {
      final calls = await SupabaseService.fetchActiveWaiterCalls(widget.restaurant.id);
      if (mounted) setState(() => _waiterCallCount = calls.length);
    } catch (_) {}
  }

  void _onPendingCount(int count) {
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OverviewScreen(restaurant: widget.restaurant),
      OrdersScreen(restaurant: widget.restaurant, onPendingCount: _onPendingCount),
      WaiterCallsScreen(restaurant: widget.restaurant, onActiveCount: (c) {
        if (mounted) setState(() => _waiterCallCount = c);
      }),
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
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _waiterCallCount > 0,
                label: Text(
                  '$_waiterCallCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                ),
                backgroundColor: const Color(0xFFFF6B35),
                child: const Text('🔔', style: TextStyle(fontSize: 20)),
              ),
              label: 'Calls',
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
