import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, RefreshControl, TouchableOpacity, StyleSheet,
} from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import { supabase, Restaurant, Order } from '../lib/supabase';
import StatusBadge from '../components/StatusBadge';

interface RevenueScreenProps {
  restaurant: Restaurant;
}

type DateFilter = 'today' | 'week' | 'month' | 'all';

export default function RevenueScreen({ restaurant }: RevenueScreenProps) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [filter, setFilter] = useState<DateFilter>('today');
  const [refreshing, setRefreshing] = useState(false);

  const getDateFrom = useCallback((f: DateFilter): Date | null => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    switch (f) {
      case 'today': return d;
      case 'week': d.setDate(d.getDate() - 7); return d;
      case 'month': d.setMonth(d.getMonth() - 1); return d;
      case 'all': return null;
    }
  }, []);

  const load = useCallback(async () => {
    try {
      let query = supabase.from('orders')
        .select('*')
        .eq('restaurant_id', restaurant.id)
        .order('created_at', { ascending: false });
      const dateFrom = getDateFrom(filter);
      if (dateFrom) {
        query = query.gte('created_at', dateFrom.toISOString());
      }
      const { data } = await query;
      setOrders((data || []) as Order[]);
    } catch (e) {
      setOrders([]);
    }
  }, [restaurant.id, filter, getDateFrom]);

  useEffect(() => { load(); }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  // Computed stats
  const totalRevenue = orders.reduce((s, o) => s + Number(o.total), 0);
  const completedOrders = orders.filter(o => o.status === 'completed');
  const avgOrder = completedOrders.length > 0 ? Math.round(totalRevenue / orders.length) : 0;

  // Top items
  const itemCounts: Record<string, { name: string; emoji: string; qty: number; revenue: number }> = {};
  orders.forEach(o => {
    o.items.forEach(item => {
      if (!itemCounts[item.name]) {
        itemCounts[item.name] = { name: item.name, emoji: item.emoji || '🍽', qty: 0, revenue: 0 };
      }
      itemCounts[item.name].qty += item.qty;
      itemCounts[item.name].revenue += item.qty * item.price;
    });
  });
  const topItems = Object.values(itemCounts).sort((a, b) => b.revenue - a.revenue).slice(0, 5);

  // Hourly distribution
  const hourlyRevenue: Record<number, number> = {};
  orders.forEach(o => {
    const h = new Date(o.created_at).getHours();
    hourlyRevenue[h] = (hourlyRevenue[h] || 0) + Number(o.total);
  });
  const peakHour = Object.entries(hourlyRevenue).sort(([, a], [, b]) => b - a)[0];
  const peakHourStr = peakHour ? `${peakHour[0].padStart(2, '0')}:00` : '—';

  const filterLabels: Record<DateFilter, string> = {
    today: 'Today', week: 'This Week', month: 'This Month', all: 'All Time',
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={COLORS.lime} colors={[COLORS.lime]} />}
    >
      <Text style={styles.title}>Revenue</Text>
      <Text style={styles.sub}>Earnings and order analytics</Text>

      {/* Filter Pills */}
      <View style={styles.filterRow}>
        {(['today', 'week', 'month', 'all'] as DateFilter[]).map(f => (
          <TouchableOpacity
            key={f}
            style={[styles.filterPill, filter === f && styles.filterActive]}
            onPress={() => setFilter(f)}
            activeOpacity={0.7}
          >
            <Text style={[styles.filterText, filter === f && styles.filterTextActive]}>
              {filterLabels[f]}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Big Revenue */}
      <View style={styles.revenueCard}>
        <Text style={styles.revLabel}>TOTAL REVENUE</Text>
        <Text style={styles.revValue}>₹{totalRevenue.toLocaleString('en-IN')}</Text>
        <Text style={styles.revSub}>{orders.length} orders · Avg ₹{avgOrder.toLocaleString('en-IN')}</Text>
      </View>

      {/* Quick Stats */}
      <View style={styles.quickRow}>
        <View style={styles.quickCard}>
          <Text style={styles.quickLabel}>Peak Hour</Text>
          <Text style={styles.quickValue}>{peakHourStr}</Text>
        </View>
        <View style={styles.quickCard}>
          <Text style={styles.quickLabel}>Completed</Text>
          <Text style={styles.quickValue}>{completedOrders.length}</Text>
        </View>
        <View style={styles.quickCard}>
          <Text style={styles.quickLabel}>Pending</Text>
          <Text style={styles.quickValue}>{orders.filter(o => o.status === 'pending').length}</Text>
        </View>
      </View>

      {/* Top Items */}
      {topItems.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>🏆 Top Items</Text>
          {topItems.map((item, i) => (
            <View key={item.name} style={styles.topRow}>
              <Text style={styles.topRank}>{i + 1}</Text>
              <Text style={styles.topEmoji}>{item.emoji}</Text>
              <View style={styles.topInfo}>
                <Text style={styles.topName}>{item.name}</Text>
                <Text style={styles.topMeta}>{item.qty} sold</Text>
              </View>
              <Text style={styles.topRev}>₹{item.revenue.toLocaleString('en-IN')}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Order History */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Order History</Text>
        {orders.length === 0 ? (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>📊</Text>
            <Text style={styles.emptyText}>No orders in this period</Text>
          </View>
        ) : (
          orders.slice(0, 20).map(o => (
            <View key={o.id} style={styles.histRow}>
              <View style={styles.histInfo}>
                <Text style={styles.histName}>Table {o.table_number}</Text>
                <Text style={styles.histMeta}>
                  {new Date(o.created_at).toLocaleString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })}
                  {' · '}{o.items.length} item(s)
                </Text>
              </View>
              <View style={styles.histRight}>
                <Text style={styles.histTotal}>₹{o.total}</Text>
                <StatusBadge status={o.status} small />
              </View>
            </View>
          ))
        )}
        {orders.length > 20 && (
          <Text style={styles.moreText}>Showing 20 of {orders.length} orders</Text>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.bg },
  content: { padding: 20, paddingTop: 16, paddingBottom: 40 },
  title: { fontSize: 24, color: COLORS.white, marginBottom: 4, ...FONTS.bold },
  sub: { fontSize: 13, color: COLORS.muted, marginBottom: 18 },

  filterRow: { flexDirection: 'row', gap: 8, marginBottom: 20, flexWrap: 'wrap' },
  filterPill: {
    paddingHorizontal: 16, paddingVertical: 8,
    borderRadius: RADIUS.full,
    borderWidth: 1, borderColor: COLORS.border,
    backgroundColor: COLORS.surface1,
  },
  filterActive: { borderColor: COLORS.limeAlpha30, backgroundColor: COLORS.limeAlpha08 },
  filterText: { fontSize: 12, color: COLORS.muted, ...FONTS.medium },
  filterTextActive: { color: COLORS.lime, ...FONTS.semibold },

  revenueCard: {
    backgroundColor: COLORS.surface1, borderWidth: 1, borderColor: COLORS.limeAlpha18,
    borderRadius: RADIUS.md, padding: 24, alignItems: 'center', marginBottom: 14,
  },
  revLabel: { fontSize: 11, letterSpacing: 2, color: COLORS.muted, marginBottom: 8, ...FONTS.semibold },
  revValue: { fontSize: 40, color: COLORS.lime, letterSpacing: -2, ...FONTS.bold },
  revSub: { fontSize: 12, color: COLORS.muted, marginTop: 6 },

  quickRow: { flexDirection: 'row', gap: 10, marginBottom: 14 },
  quickCard: {
    flex: 1, backgroundColor: COLORS.surface1, borderWidth: 1, borderColor: COLORS.border,
    borderRadius: RADIUS.md, padding: 14, alignItems: 'center',
  },
  quickLabel: { fontSize: 10, color: COLORS.muted, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 4 },
  quickValue: { fontSize: 20, color: COLORS.white, ...FONTS.bold },

  card: {
    backgroundColor: COLORS.surface1, borderWidth: 1, borderColor: COLORS.border,
    borderRadius: RADIUS.md, padding: 20, marginBottom: 14,
  },
  cardTitle: { fontSize: 16, color: COLORS.white, marginBottom: 16, ...FONTS.semibold },

  topRow: {
    flexDirection: 'row', alignItems: 'center', paddingVertical: 10,
    borderBottomWidth: 1, borderBottomColor: COLORS.border, gap: 10,
  },
  topRank: { fontSize: 14, color: COLORS.muted, width: 20, textAlign: 'center', ...FONTS.bold },
  topEmoji: { fontSize: 20, width: 28, textAlign: 'center' },
  topInfo: { flex: 1 },
  topName: { fontSize: 13, color: COLORS.white, ...FONTS.semibold },
  topMeta: { fontSize: 11, color: COLORS.muted },
  topRev: { fontSize: 14, color: COLORS.lime, ...FONTS.bold },

  histRow: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: COLORS.border,
  },
  histInfo: { flex: 1 },
  histName: { fontSize: 14, color: COLORS.white, ...FONTS.semibold },
  histMeta: { fontSize: 11, color: COLORS.muted, marginTop: 2 },
  histRight: { alignItems: 'flex-end', gap: 4 },
  histTotal: { fontSize: 14, color: COLORS.lime, ...FONTS.bold },

  empty: { alignItems: 'center', paddingVertical: 30 },
  emptyIcon: { fontSize: 32, marginBottom: 8 },
  emptyText: { fontSize: 14, color: COLORS.muted },
  moreText: { fontSize: 12, color: COLORS.muted, textAlign: 'center', marginTop: 12 },
});
