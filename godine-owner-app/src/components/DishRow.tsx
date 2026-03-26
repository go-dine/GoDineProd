import React from 'react';
import { View, Text, Switch, TouchableOpacity, StyleSheet } from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import { Utensils } from 'lucide-react-native';
import { Dish } from '../lib/supabase';

interface DishRowProps {
  dish: Dish;
  onToggle: (id: string, available: boolean) => void;
  onDelete: (id: string, name: string) => void;
}

export default function DishRow({ dish, onToggle, onDelete }: DishRowProps) {
  return (
    <View style={styles.row}>
      <View style={styles.iconContainer}>
        {dish.emoji && dish.emoji !== '🍽️' ? (
          <Text style={styles.emoji}>{dish.emoji}</Text>
        ) : (
          <Utensils size={20} color={COLORS.muted} />
        )}
      </View>
      <View style={styles.info}>
        <Text style={styles.name}>{dish.name}</Text>
        <Text style={styles.meta} numberOfLines={1}>
          {dish.category} · ₹{dish.price}{dish.description ? ' · ' + dish.description : ''}
        </Text>
      </View>
      <View style={styles.actions}>
        <Switch
          value={dish.available}
          onValueChange={(val) => onToggle(dish.id, val)}
          trackColor={{ false: COLORS.surface3, true: COLORS.limeAlpha30 }}
          thumbColor={dish.available ? COLORS.lime : COLORS.muted}
          ios_backgroundColor={COLORS.surface3}
        />
        <TouchableOpacity
          style={styles.deleteBtn}
          onPress={() => onDelete(dish.id, dish.name)}
          activeOpacity={0.7}
        >
          <Text style={styles.deleteText}>Delete</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    gap: 12,
  },
  iconContainer: {
    width: 36,
    height: 36,
    borderRadius: 8,
    backgroundColor: COLORS.surface2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emoji: {
    fontSize: 20,
    textAlign: 'center',
  },
  info: {
    flex: 1,
    minWidth: 0,
  },
  name: {
    fontSize: 14,
    color: COLORS.white,
    marginBottom: 2,
    ...FONTS.semibold,
  },
  meta: {
    fontSize: 11,
    color: COLORS.muted,
  },
  actions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  deleteBtn: {
    backgroundColor: COLORS.redAlpha,
    borderWidth: 1,
    borderColor: COLORS.redBorder,
    borderRadius: 8,
    paddingVertical: 5,
    paddingHorizontal: 10,
  },
  deleteText: {
    fontSize: 11,
    color: COLORS.red,
    ...FONTS.semibold,
  },
});
