import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import StatusBadge from './StatusBadge';
import { Order } from '../lib/supabase';

interface OrderCardProps {
  order: Order;
  onAdvanceStatus: (id: string, newStatus: string) => void;
  onComplete: (id: string) => void;
}

const NEXT_STATUS: Record<string, { status: string; label: string }> = {
  pending: { status: 'preparing', label: '🔥 Start Preparing' },
  preparing: { status: 'ready', label: '✅ Mark Ready' },
  ready: { status: 'completed', label: '🎉 Complete' },
};

export default function OrderCard({ order, onAdvanceStatus, onComplete }: OrderCardProps) {
  const next = NEXT_STATUS[order.status];
  const borderColor =
    order.status === 'pending' ? 'rgba(251,191,36,0.2)' :
    order.status === 'preparing' ? 'rgba(182,255,42,0.2)' :
    order.status === 'ready' ? 'rgba(74,222,128,0.25)' :
    COLORS.border;

  return (
    <View style={[styles.card, { borderColor }, order.status === 'completed' && styles.completed]}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.tableText}>Table {order.table_number}</Text>
          <Text style={styles.timeText}>{timeAgo(order.created_at)}</Text>
        </View>
        <StatusBadge status={order.status} />
      </View>

      {/* Items */}
      <View style={styles.items}>
        {order.items.map((item, i) => (
          <Text key={i} style={styles.itemText}>
            {item.emoji || '🍽'} <Text style={styles.itemBold}>{item.qty}×</Text> {item.name} — ₹{item.price * item.qty}
          </Text>
        ))}
      </View>

      {/* Note */}
      {order.note ? (
        <View style={styles.noteBox}>
          <Text style={styles.noteText}>📝 {order.note}</Text>
        </View>
      ) : null}

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.total}>Total: ₹{order.total}</Text>
        <View style={styles.actions}>
          {next && (
            <TouchableOpacity
              style={styles.btnLime}
              onPress={() => onAdvanceStatus(order.id, next.status)}
              activeOpacity={0.7}
            >
              <Text style={styles.btnLimeText}>{next.label}</Text>
            </TouchableOpacity>
          )}
          {order.status !== 'completed' && order.status !== 'ready' && (
            <TouchableOpacity
              style={styles.btnGhost}
              onPress={() => onComplete(order.id)}
              activeOpacity={0.7}
            >
              <Text style={styles.btnGhostText}>Complete</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>
    </View>
  );
}

function timeAgo(iso: string): string {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + ' min ago';
  return Math.floor(diff / 3600) + ' hr ago';
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.surface1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.md,
    padding: 18,
    marginBottom: 12,
  },
  completed: {
    opacity: 0.5,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  tableText: {
    fontSize: 16,
    color: COLORS.white,
    ...FONTS.bold,
  },
  timeText: {
    fontSize: 11,
    color: COLORS.muted,
    marginTop: 2,
  },
  items: {
    marginBottom: 14,
    gap: 6,
  },
  itemText: {
    fontSize: 13,
    color: COLORS.muted,
    lineHeight: 20,
  },
  itemBold: {
    color: COLORS.white,
    ...FONTS.semibold,
  },
  noteBox: {
    backgroundColor: COLORS.surface2,
    borderRadius: 8,
    padding: 10,
    marginBottom: 14,
  },
  noteText: {
    fontSize: 12,
    color: COLORS.muted,
    fontStyle: 'italic',
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: 10,
  },
  total: {
    fontSize: 15,
    color: COLORS.lime,
    ...FONTS.bold,
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
  },
  btnLime: {
    backgroundColor: COLORS.lime,
    borderRadius: RADIUS.sm,
    paddingVertical: 8,
    paddingHorizontal: 14,
  },
  btnLimeText: {
    color: '#050505',
    fontSize: 12,
    ...FONTS.bold,
  },
  btnGhost: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.sm,
    paddingVertical: 8,
    paddingHorizontal: 14,
  },
  btnGhostText: {
    color: COLORS.muted,
    fontSize: 12,
    ...FONTS.medium,
  },
});
