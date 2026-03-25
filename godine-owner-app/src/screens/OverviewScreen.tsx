import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, RefreshControl, StyleSheet } from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import { supabase, Restaurant, Order } from '../lib/supabase';
import StatCard from '../components/StatCard';
import StatusBadge from '../components/StatusBadge';

interface OverviewScreenProps {
  restaurant: Restaurant;
}

export default function OverviewScreen({ restaurant }: OverviewScreenProps) {
  const [stats, setStats] = useState({ orders: 0, revenue: 0, pending: 0, dishes: 0 });
  const [recentOrders, setRecentOrders] = useState<Order[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const [dishRes, orderRes] = await Promise.all([
        supabase.from('dishes').select('id,available').eq('restaurant_id', restaurant.id),
        supabase.from('orders').select('*').eq('restaurant_id', restaurant.id).gte('created_at', today.toISOString()),
      ]);
      const allOrders = (orderRes.data || []) as Order[];
      const revenue = allOrders.reduce((s, o) => s + Number(o.total), 0);
      const pending = allOrders.filter(o => o.status === 'pending').length;
      const activeDishes = (dishRes.data || []).filter((d: any) => d.available).length;
      setStats({ orders: allOrders.length, revenue, pending, dishes: activeDishes });
      setRecentOrders(allOrders.slice(-5).reverse());
    } catch (e) {
      setStats({ orders: 0, revenue: 0, pending: 0, dishes: 0 });
    }
  }, [restaurant.id]);

  useEffect(() => {
    load();
    const channel = supabase.channel(`owner-stats-${restaurant.id}`)
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'orders', filter: `restaurant_id=eq.${restaurant.id}` }, 
        () => {
          load();
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

  const dateStr = new Date().toLocaleDateString('en-IN', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={COLORS.lime} colors={[COLORS.lime]} />}
    >
      <Text style={styles.title}>Overview</Text>
      <Text style={styles.date}>{dateStr}</Text>

      {/* Stats */}
      <View style={styles.statsRow}>
        <StatCard label="Today's Orders" value={String(stats.orders)} sub="Total orders today" accent />
        <StatCard label="Revenue" value={'₹' + stats.revenue.toLocaleString('en-IN')} sub="Today's earnings" accent />
      </View>
      <View style={styles.statsRow}>
        <StatCard label="Pending" value={String(stats.pending)} sub="Awaiting action" />
        <StatCard label="Menu Items" value={String(stats.dishes)} sub="Active dishes" />
      </View>

      {/* Recent Orders */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Recent Orders</Text>
        {recentOrders.length === 0 ? (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>🕐</Text>
            <Text style={styles.emptyText}>No orders yet today</Text>
          </View>
        ) : (
          recentOrders.map((o) => (
            <View key={o.id} style={styles.recentRow}>
              <View style={styles.recentInfo}>
                <Text style={styles.recentName}>Table {o.table_number} · ₹{o.total}</Text>
                <Text style={styles.recentMeta}>{timeAgo(o.created_at)} · {o.items.length} item(s)</Text>
              </View>
              <StatusBadge status={o.status} small />
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

function timeAgo(iso: string): string {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + ' min ago';
  return Math.floor(diff / 3600) + ' hr ago';
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  content: {
    padding: 20,
    paddingTop: 16,
  },
  title: {
    fontSize: 24,
    color: COLORS.white,
    marginBottom: 4,
    ...FONTS.bold,
  },
  date: {
    fontSize: 13,
    color: COLORS.muted,
    marginBottom: 22,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 12,
  },
  card: {
    backgroundColor: COLORS.surface1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.md,
    padding: 20,
    marginTop: 8,
  },
  cardTitle: {
    fontSize: 16,
    color: COLORS.white,
    marginBottom: 16,
    ...FONTS.semibold,
  },
  recentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  recentInfo: {
    flex: 1,
  },
  recentName: {
    fontSize: 14,
    color: COLORS.white,
    ...FONTS.semibold,
  },
  recentMeta: {
    fontSize: 11,
    color: COLORS.muted,
    marginTop: 2,
  },
  empty: {
    alignItems: 'center',
    paddingVertical: 30,
  },
  emptyIcon: {
    fontSize: 32,
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.muted,
  },
});
