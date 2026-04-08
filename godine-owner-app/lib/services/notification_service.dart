import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _notifications.initialize(settings: initSettings);
    
    // Create dedicated notification channels
    await _createNotificationChannels();

    // Request local notification permission on Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request Firebase Messaging permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Setup foreground message handler
    setupForegroundHandler();
  }

  /// Create Android notification channels for different notification types
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // High-priority channel for new orders (matches edge function's channel_id)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'godine_new_orders',
        'New Orders',
        description: 'High-priority alerts for incoming customer orders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // General notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'godine_general',
        'General Notifications',
        description: 'Notifications for general updates',
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Waiter call notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'godine_waiter_calls',
        'Waiter Calls',
        description: 'High-priority alerts when a customer calls the waiter',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );
  }

  static Future<String?> getDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Listen for FCM messages while the app is in the foreground
  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground FCM: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: notification.title ?? 'GoDine',
          body: notification.body ?? 'New notification',
          data: message.data,
          isOrder: message.data['type'] == 'new_order',
        );
      }
    });
  }

  /// Show a new order notification with high-priority channel
  static Future<void> showNewOrderNotification(Order order) async {
    const androidDetails = AndroidNotificationDetails(
      'godine_new_orders',
      'New Orders',
      channelDescription: 'High-priority alerts for incoming customer orders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'New Order! 🔔 Table ${order.tableNumber}',
      body: '${order.customerName ?? "Customer"} — ₹${order.total} (${order.items.length} items)',
      notificationDetails: platformDetails,
      payload: order.id,
    );
  }

  /// Show a generic local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool isOrder = false,
  }) async {
    final channelId = isOrder ? 'godine_new_orders' : 'godine_general';
    final channelName = isOrder ? 'New Orders' : 'General Notifications';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isOrder
          ? 'High-priority alerts for incoming customer orders'
          : 'Notifications for general updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      fullScreenIntent: isOrder,
    );
    const iosDets = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDets,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: data != null ? data.toString() : null,
    );
  }

  /// Show a waiter call notification with dedicated high-priority channel
  static Future<void> showWaiterCallNotification({
    required String tableNumber,
    String? callId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'godine_waiter_calls',
      'Waiter Calls',
      channelDescription: 'High-priority alerts when a customer calls the waiter',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🔔 Waiter Call — Table $tableNumber',
      body: 'A customer is requesting assistance at Table $tableNumber',
      notificationDetails: platformDetails,
      payload: callId,
    );
  }
}
