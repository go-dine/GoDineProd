import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, RefreshControl, StyleSheet, Alert,
} from 'react-native';
import { COLORS, FONTS } from '../theme';
import { supabase, Restaurant, Order } from '../lib/supabase';
import OrderCard from '../components/OrderCard';

interface OrdersScreenProps {
  restaurant: Restaurant;
  onPendingCount?: (count: number) => void;
}

export default function OrdersScreen({ restaurant, onPendingCount }: OrdersScreenProps) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const { data } = await supabase.from('orders')
        .select('*')
        .eq('restaurant_id', restaurant.id)
        .gte('created_at', today.toISOString())
        .not('status', 'eq', 'completed')
        .order('created_at', { ascending: false });
      const list = (data || []) as Order[];
      setOrders(list);
      onPendingCount?.(list.filter(o => o.status === 'pending').length);
    } catch (e) {
      setOrders([]);
    }
    setLoading(false);
  }, [restaurant.id, onPendingCount]);

  useEffect(() => {
    load();
    const channel = supabase.channel(`owner-orders-${restaurant.id}`)
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'orders', filter: `restaurant_id=eq.${restaurant.id}` }, 
        (payload) => {
          load();
          if (payload.eventType === 'INSERT') {
            const newOrder = payload.new as Order;
            Alert.alert(
              '🔔 New Order!',
              `Table ${newOrder.table_number} just placed an order (₹${newOrder.total}).`,
              [{ text: 'View', onPress: () => load() }]
            );
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [load, restaurant.id]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  async function updateStatus(id: string, status: string) {
    let estimatedTime = '';
    
    if (status === 'preparing') {
      // Simple prompt for mobile (Alert.prompt is iOS only, using a basic selection or just update for now)
      // To stay cross-platform and simple for this MVP update:
      return new Promise((resolve) => {
        Alert.alert(
          'Preparation Time',
          'How long will this take?',
          [
            { text: '10 mins', onPress: () => performUpdate(id, status, '10 mins') },
            { text: '20 mins', onPress: () => performUpdate(id, status, '20 mins') },
            { text: '30 mins', onPress: () => performUpdate(id, status, '30 mins') },
            { text: 'Skip', onPress: () => performUpdate(id, status) },
          ]
        );
      });
    }

    await performUpdate(id, status);
  }

  async function performUpdate(id: string, status: string, eta?: string) {
    try {
      const payload: any = { status };
      if (eta) payload.estimated_time = eta;

      await supabase.from('orders').update(payload).eq('id', id);
      
      // Optimistic update
      setOrders(prev => prev.map(o => o.id === id ? { ...o, status: status as Order['status'], estimated_time: eta || o.estimated_time } : o));
      const newPending = orders.filter(o => o.id !== id ? o.status === 'pending' : status === 'pending').length;
      onPendingCount?.(newPending);
    } catch (e) {
      Alert.alert('Error', 'Failed to update order status');
    }
  }

  function handleComplete(id: string) {
    Alert.alert('Complete Order', 'Mark this order as completed?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Complete', onPress: () => updateStatus(id, 'completed') },
    ]);
  }

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={COLORS.lime} colors={[COLORS.lime]} />}
    >
      <Text style={styles.title}>Live Orders</Text>
      <Text style={styles.sub}>Auto-refreshes every 15s · Pull to refresh</Text>

      {loading ? (
        <View style={styles.empty}>
          <Text style={styles.emptyIcon}>⏳</Text>
          <Text style={styles.emptyText}>Loading orders...</Text>
        </View>
      ) : orders.length === 0 ? (
        <View style={styles.empty}>
          <Text style={styles.emptyIcon}>✅</Text>
          <Text style={styles.emptyText}>No active orders right now</Text>
        </View>
      ) : (
        orders.map(o => (
          <OrderCard
            key={o.id}
            order={o}
            onAdvanceStatus={updateStatus}
            onComplete={handleComplete}
          />
        ))
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  content: {
    padding: 20,
    paddingTop: 16,
    paddingBottom: 40,
  },
  title: {
    fontSize: 24,
    color: COLORS.white,
    marginBottom: 4,
    ...FONTS.bold,
  },
  sub: {
    fontSize: 13,
    color: COLORS.muted,
    marginBottom: 22,
  },
  empty: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyIcon: {
    fontSize: 36,
    marginBottom: 12,
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.muted,
  },
});
