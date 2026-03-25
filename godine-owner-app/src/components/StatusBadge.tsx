import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';

type Status = 'pending' | 'preparing' | 'ready' | 'completed';

const STATUS_STYLES: Record<Status, { bg: string; color: string; label: string }> = {
  pending: { bg: COLORS.amberAlpha, color: COLORS.amber, label: 'PENDING' },
  preparing: { bg: COLORS.limeAlpha08, color: COLORS.lime, label: 'PREPARING' },
  ready: { bg: COLORS.greenAlpha, color: COLORS.green, label: 'READY' },
  completed: { bg: COLORS.surface3, color: COLORS.muted, label: 'COMPLETED' },
};

interface StatusBadgeProps {
  status: Status;
  small?: boolean;
}

export default function StatusBadge({ status, small = false }: StatusBadgeProps) {
  const s = STATUS_STYLES[status] || STATUS_STYLES.pending;
  return (
    <View style={[styles.badge, { backgroundColor: s.bg }, small && styles.small]}>
      <Text style={[styles.text, { color: s.color }, small && styles.smallText]}>
        {s.label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: RADIUS.full,
  },
  small: {
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  text: {
    fontSize: 11,
    letterSpacing: 0.3,
    ...FONTS.bold,
  },
  smallText: {
    fontSize: 9,
  },
});
