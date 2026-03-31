import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/order.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _notifications.initialize(settings: initSettings);
    
    // Request permission on Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNewOrderNotification(Order order) async {
    const androidDetails = AndroidNotificationDetails(
      'godine_new_orders',
      'New Orders',
      channelDescription: 'Notifications for new customer orders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final title = 'New Order (Table ${order.tableNumber})';
    final nameStr = order.customerName != null ? '${order.customerName} ordered' : 'Order:';
    final body = '$nameStr ₹${order.total}';

    await _notifications.show(
      id: order.id.hashCode, // Unique ID per order
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
