import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';

interface StatCardProps {
  label: string;
  value: string;
  sub: string;
  accent?: boolean;
}

export default function StatCard({ label, value, sub, accent = false }: StatCardProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.label}>{label}</Text>
      <Text style={[styles.value, accent && styles.accentValue]}>{value}</Text>
      <Text style={styles.sub}>{sub}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    backgroundColor: COLORS.surface1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.md,
    padding: 16,
    minWidth: '45%',
  },
  label: {
    fontSize: 10,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
    color: COLORS.muted,
    marginBottom: 6,
    ...FONTS.medium,
  },
  value: {
    fontSize: 26,
    color: COLORS.white,
    letterSpacing: -1,
    ...FONTS.bold,
  },
  accentValue: {
    color: COLORS.lime,
  },
  sub: {
    fontSize: 10,
    color: COLORS.muted,
    marginTop: 3,
  },
});
