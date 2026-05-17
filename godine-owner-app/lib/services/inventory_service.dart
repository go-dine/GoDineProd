/// GoDine — Inventory Service
/// Handles CRUD operations for inventory items via Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';

class InventoryService {
  static final _client = Supabase.instance.client;

  /// Fetch all inventory items for a restaurant, ordered by name.
  static Future<List<InventoryItem>> fetchItems(String restaurantId) async {
    final res = await _client
        .from('inventory_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('name');

    return (res as List).map((r) => InventoryItem.fromJson(r)).toList();
  }

  /// Create a new inventory item.
  static Future<InventoryItem?> createItem({
    required String restaurantId,
    required String name,
    required String unit,
    double quantity = 0,
    double lowStockThreshold = 5,
    double? costPrice,
  }) async {
    final res = await _client
        .from('inventory_items')
        .insert({
          'restaurant_id': restaurantId,
          'name': name,
          'unit': unit,
          'quantity': quantity,
          'low_stock_threshold': lowStockThreshold,
          if (costPrice != null) 'cost_price': costPrice,
        })
        .select()
        .single();

    return InventoryItem.fromJson(res);
  }

  /// Update quantity of an inventory item.
  static Future<void> updateQuantity(String itemId, String restaurantId, double quantity) async {
    await _client
        .from('inventory_items')
        .update({'quantity': quantity})
        .eq('id', itemId)
        .eq('restaurant_id', restaurantId);
  }

  /// Update an inventory item's details.
  static Future<void> updateItem(String itemId, String restaurantId, Map<String, dynamic> updates) async {
    await _client
        .from('inventory_items')
        .update(updates)
        .eq('id', itemId)
        .eq('restaurant_id', restaurantId);
  }

  /// Delete an inventory item.
  static Future<void> deleteItem(String itemId, String restaurantId) async {
    await _client
        .from('inventory_items')
        .delete()
        .eq('id', itemId)
        .eq('restaurant_id', restaurantId);
  }

  /// Subscribe to realtime changes on inventory_items for a restaurant.
  static RealtimeChannel subscribeToChanges(
    String channelName,
    String restaurantId,
    void Function(dynamic payload) onData,
  ) {
    return _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) => onData(payload),
        )
        .subscribe();
  }

  /// Unsubscribe from a realtime channel.
  static void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  /// Get count of low-stock items for a restaurant.
  static Future<int> getLowStockCount(String restaurantId) async {
    final items = await fetchItems(restaurantId);
    return items.where((i) => i.isLowStock || i.isOutOfStock).length;
  }
}
