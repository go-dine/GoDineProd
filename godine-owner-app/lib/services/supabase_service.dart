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

  // ───── Dishes ─────

  static Future<void> updateFcmToken(String restaurantId, String? token) async {
    await client.from('restaurants').update({'fcm_token': token}).eq('id', restaurantId);
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
    required String description,
  }) async {
    await client.from('dishes').insert({
      'restaurant_id': restaurantId,
      'name': name,
      'price': price,
      'category': category,
      'emoji': emoji.isEmpty ? '🍽️' : emoji,
      'description': description,
    });
  }

  static Future<void> toggleDish(String dishId, bool available) async {
    await client.from('dishes').update({'available': available}).eq('id', dishId);
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
