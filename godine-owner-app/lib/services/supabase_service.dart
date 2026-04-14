import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../models/feedback.dart';

const String _supabaseUrl = 'https://qqnrucnsvupfywyzlofa.supabase.co';
const String _supabaseKey =
    'sb_publishable_v0HfrI2OaKkBXJhqrU9EOA_05uRuFYx';

const _storage = FlutterSecureStorage();
const _authKey = 'gd_auth';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call once in main()
  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseKey,
      );
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
      rethrow;
    }
  }

  // ───── Auth Persistence ─────

  static Future<void> saveAuth(String id, String slug) async {
    await _storage.write(key: _authKey, value: jsonEncode({'id': id, 'slug': slug}));
  }

  static Future<String?> getSavedAuthId() async {
    final saved = await _storage.read(key: _authKey);
    if (saved == null) return null;
    try {
      final map = jsonDecode(saved) as Map<String, dynamic>;
      return map['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAuth() async {
    await _storage.delete(key: _authKey);
  }

  // ───── Admin Auth Persistence ─────

  static Future<void> saveAdminAuth() async {
    await _storage.write(key: 'gd_admin_auth', value: 'true');
  }

  static Future<bool> getSavedAdminAuth() async {
    return await _storage.read(key: 'gd_admin_auth') == 'true';
  }

  static Future<void> clearAdminAuth() async {
    await _storage.delete(key: 'gd_admin_auth');
  }

  // ───── Restaurant Auth ─────

  static Future<Restaurant?> login(String slug, String password) async {
    final res = await client
        .from('restaurants')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    if (res == null) return null;
    final restaurant = Restaurant.fromJson(res);
    if (!restaurant.isActive) {
      throw Exception('suspended');
    }
    if (restaurant.ownerPassword != password) return null;
    await saveAuth(restaurant.id, restaurant.slug);
    return restaurant;
  }

  static Future<Restaurant?> register({
    required String name,
    required String slug,
    required String password,
    required int totalTables,
  }) async {
    final res = await client
        .from('restaurants')
        .insert({
          'name': name,
          'slug': slug,
          'owner_password': password,
          'total_tables': totalTables,
        })
        .select()
        .single();
    final restaurant = Restaurant.fromJson(res);
    await saveAuth(restaurant.id, restaurant.slug);
    return restaurant;
  }

  static Future<Restaurant?> autoLogin() async {
    final id = await getSavedAuthId();
    if (id == null) return null;
    final res = await client
        .from('restaurants')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    final restaurant = Restaurant.fromJson(res);
    if (!restaurant.isActive) {
      await clearAuth();
      return null;
    }
    return restaurant;
  }

  // ───── Restaurant Management ─────

  static Future<void> registerFcmToken(String restaurantId, String token, String platform) async {
    // Store in owner_fcm_tokens for multi-device support
    await client.from('owner_fcm_tokens').upsert(
      {
        'restaurant_id': restaurantId,
        'token': token,
        'platform': platform,
      },
      onConflict: 'restaurant_id,token',
    );
    // Also update restaurants.fcm_token for backward compatibility with edge function
    await client.from('restaurants').update({'fcm_token': token}).eq('id', restaurantId);
  }

  static Future<void> removeFcmToken(String restaurantId, String token) async {
    try {
      // Remove from multi-device table
      await client.from('owner_fcm_tokens').delete().eq('restaurant_id', restaurantId).eq('token', token);
      
      // Also clear from main restaurant table if it matches
      final res = await client.from('restaurants').select('fcm_token').eq('id', restaurantId).maybeSingle();
      if (res != null && res['fcm_token'] == token) {
        await client.from('restaurants').update({'fcm_token': null}).eq('id', restaurantId);
      }
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  static Future<void> updateRestaurantAnnouncement(String restaurantId, String? announcement) async {
    await client.from('restaurants').update({'announcement': announcement}).eq('id', restaurantId);
  }

  static Future<void> updateBranchHours(String restaurantId, List<Map<String, dynamic>> hours) async {
    for (var h in hours) {
      await client.from('active_hours').upsert({
        'restaurant_id': restaurantId,
        'day_of_week': h['day_of_week'],
        'open_time': h['open_time'],
        'close_time': h['close_time'],
        'is_open': h['is_open'],
      });
    }
  }

  static Future<Map<String, dynamic>> fetchStats(String restaurantId) async {
    // Current simple implementation: count orders and sum total for completed/ready/pending
    final orders = await client
        .from('orders')
        .select('total')
        .eq('restaurant_id', restaurantId)
        .neq('status', 'cancelled');
    final List<dynamic> data = orders as List<dynamic>;
    
    double totalRevenue = 0;
    for (var o in data) {
      totalRevenue += (o['total'] ?? 0).toDouble();
    }
    
    return {
      'total_orders': data.length,
      'total_revenue': totalRevenue,
      'avg_order_value': data.isEmpty ? 0 : totalRevenue / data.length,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchActiveHours(String restaurantId) async {
    final res = await client.from('active_hours').select().eq('restaurant_id', restaurantId).order('day_of_week');
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<List<Dish>> fetchDishes(String restaurantId) async {
    final res = await client
        .from('dishes')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('category')
        .order('name');
    return (res as List).map((e) => Dish.fromJson(e)).toList();
  }

  static Future<void> addDish({
    required String restaurantId,
    required String name,
    required double price,
    required String category,
    required String emoji,
    String? imageUrl,
    required String description,
    required bool isFeatured,
  }) async {
    await client.from('dishes').insert({
      'restaurant_id': restaurantId,
      'name': name,
      'price': price,
      'category': category,
      'emoji': emoji.isEmpty ? '🍽️' : emoji,
      'image_url': imageUrl,
      'description': description,
      'is_featured': isFeatured,
    });
  }

  static Future<void> updateDish({
    required String dishId,
    required String name,
    required double price,
    required String category,
    required String emoji,
    String? imageUrl,
    required String description,
    required bool isFeatured,
  }) async {
    await client.from('dishes').update({
      'name': name,
      'price': price,
      'category': category,
      'emoji': emoji.isEmpty ? '🍽️' : emoji,
      'image_url': imageUrl,
      'description': description,
      'is_featured': isFeatured,
    }).eq('id', dishId);
  }

  static Future<void> toggleDish(String dishId, bool available) async {
    await client.from('dishes').update({'available': available}).eq('id', dishId);
  }

  static Future<void> toggleFeatured(String dishId, bool isFeatured) async {
    await client.from('dishes').update({'is_featured': isFeatured}).eq('id', dishId);
  }

  static Future<void> deleteDish(String dishId) async {
    await client.from('dishes').delete().eq('id', dishId);
  }

  // ───── Orders ─────

  static Future<List<Order>> fetchTodayActiveOrders(String restaurantId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final res = await client
        .from('orders')
        .select()
        .eq('restaurant_id', restaurantId)
        .gte('created_at', startOfDay.toUtc().toIso8601String())
        .neq('status', 'cancelled')
        .or('bill_sent.eq.false,bill_sent.is.null')
        .order('created_at', ascending: false);
    return (res as List).map((e) => Order.fromJson(e)).toList();
  }

  static Future<List<Order>> fetchTodayAllOrders(String restaurantId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final res = await client
        .from('orders')
        .select()
        .eq('restaurant_id', restaurantId)
        .gte('created_at', startOfDay.toUtc().toIso8601String());
    return (res as List).map((e) => Order.fromJson(e)).toList();
  }

  static Future<List<Order>> fetchOrders(String restaurantId, {DateTime? from}) async {
    var query = client
        .from('orders')
        .select()
        .eq('restaurant_id', restaurantId);
        
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    
    final res = await query.order('created_at', ascending: false);
    return (res as List).map((e) => Order.fromJson(e)).toList();
  }

  static Future<void> updateOrderStatus(String orderId, String status, {String? estimatedTime}) async {
    final payload = <String, dynamic>{'status': status};
    if (estimatedTime != null) payload['estimated_time'] = estimatedTime;
    await client.from('orders').update(payload).eq('id', orderId);
  }

  static Future<void> sendTableBill(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    await client.from('orders').update({
      'status': 'completed',
      'bill_sent': true,
    }).inFilter('id', orderIds);
  }

  // ───── Realtime ─────

  static RealtimeChannel subscribeToOrders(String channelName, String restaurantId, void Function(PostgresChangePayload payload) onEvent) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'restaurant_id',
        value: restaurantId,
      ),
      callback: (payload) {
        onEvent(payload);
      },
    );
    channel.subscribe();
    return channel;
  }

  static RealtimeChannel subscribeToAllOrders(String channelName, void Function(PostgresChangePayload payload) onEvent) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        onEvent(payload);
      },
    );
    channel.subscribe();
    return channel;
  }

  static void unsubscribe(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  // ───── Waiter Calls ─────

  static Future<List<Map<String, dynamic>>> fetchActiveWaiterCalls(String restaurantId) async {
    final res = await client
        .from('waiter_calls')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_completed', false)
        .order('called_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> dismissWaiterCall(String callId) async {
    await client.from('waiter_calls').update({
      'is_completed': true,
      'dismissed_at': DateTime.now().toUtc().toIso8601String(),
      'dismissed_by': 'owner',
    }).eq('id', callId);
  }

  static RealtimeChannel subscribeToWaiterCalls(
      String channelName, String restaurantId, void Function(PostgresChangePayload payload) onEvent) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'waiter_calls',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'restaurant_id',
        value: restaurantId,
      ),
      callback: (payload) {
        onEvent(payload);
      },
    );
    channel.subscribe();
    return channel;
  }

  // ───── Feedback ─────

  static Future<List<FeedbackModel>> fetchFeedback(String restaurantId) async {
    final res = await client
        .from('feedback')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => FeedbackModel.fromJson(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchAllFeedback() async {
    final res = await client
        .from('feedback')
        .select('*, restaurants(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }
}
