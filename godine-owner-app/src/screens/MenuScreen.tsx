import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, ScrollView, RefreshControl, TouchableOpacity,
  TextInput, Modal, Alert, StyleSheet,
} from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import { supabase, Restaurant, Dish } from '../lib/supabase';
import DishRow from '../components/DishRow';
import { Utensils, Plus } from 'lucide-react-native';

interface MenuScreenProps {
  restaurant: Restaurant;
}

export default function MenuScreen({ restaurant }: MenuScreenProps) {
  const [dishes, setDishes] = useState<Dish[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [showAdd, setShowAdd] = useState(false);

  // Form state
  const [fName, setFName] = useState('');
  const [fPrice, setFPrice] = useState('');
  const [fCategory, setFCategory] = useState('Main Course');
  const [fEmoji, setFEmoji] = useState('');
  const [fDesc, setFDesc] = useState('');
  const [saving, setSaving] = useState(false);

  const categories = ['Main Course', 'Starters', 'Beverages', 'Desserts', 'Breads', 'Specials'];

  const load = useCallback(async () => {
    try {
      const { data } = await supabase
        .from('dishes')
        .select('*')
        .eq('restaurant_id', restaurant.id)
        .order('category')
        .order('name');
      setDishes((data || []) as Dish[]);
    } catch (e) {
      setDishes([]);
    }
  }, [restaurant.id]);

  useEffect(() => { load(); }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  async function addDish() {
    const name = fName.trim();
    const price = parseFloat(fPrice);
    if (!name || !price) { Alert.alert('Required', 'Name and price are required'); return; }
    setSaving(true);
    try {
      const { error } = await supabase.from('dishes').insert({
        restaurant_id: restaurant.id,
        name,
        price,
        category: fCategory,
        emoji: fEmoji.trim() || '🍽️',
        description: fDesc.trim(),
      });
      if (error) throw error;
      clearForm();
      setShowAdd(false);
      await load();
    } catch (e) {
      Alert.alert('Error', 'Failed to add dish');
    }
    setSaving(false);
  }

  function clearForm() {
    setFName(''); setFPrice(''); setFCategory('Main Course'); setFEmoji(''); setFDesc('');
  }

  async function toggleDish(id: string, available: boolean) {
    try {
      await supabase.from('dishes').update({ available }).eq('id', id);
      setDishes(prev => prev.map(d => d.id === id ? { ...d, available } : d));
    } catch (e) {
      Alert.alert('Error', 'Failed to update dish');
    }
  }

  function deleteDish(id: string, name: string) {
    Alert.alert('Delete Dish', `Remove "${name}" from your menu?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive',
        onPress: async () => {
          try {
            await supabase.from('dishes').delete().eq('id', id);
            setDishes(prev => prev.filter(d => d.id !== id));
          } catch (e) {
            Alert.alert('Error', 'Failed to delete dish');
          }
        },
      },
    ]);
  }

  // Group by category
  const grouped = dishes.reduce<Record<string, Dish[]>>((acc, d) => {
    if (!acc[d.category]) acc[d.category] = [];
    acc[d.category].push(d);
    return acc;
  }, {});

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={COLORS.lime} colors={[COLORS.lime]} />}
      >
        <View style={styles.header}>
          <View>
            <Text style={styles.title}>Menu</Text>
            <Text style={styles.sub}>{dishes.length} items · Pull to refresh</Text>
          </View>
        </View>

        {dishes.length === 0 ? (
          <View style={styles.empty}>
            <Utensils size={36} color={COLORS.muted} style={{ marginBottom: 12 }} />
            <Text style={styles.emptyText}>No dishes yet. Tap + to add your first dish!</Text>
          </View>
        ) : (
          Object.entries(grouped).map(([cat, items]) => (
            <View key={cat} style={styles.section}>
              <Text style={styles.sectionTitle}>{cat}</Text>
              {items.map(d => (
                <DishRow key={d.id} dish={d} onToggle={toggleDish} onDelete={deleteDish} />
              ))}
            </View>
          ))
        )}
      </ScrollView>

      {/* FAB */}
      <TouchableOpacity style={styles.fab} onPress={() => setShowAdd(true)} activeOpacity={0.8}>
        <Plus size={28} color="#050505" />
      </TouchableOpacity>

      {/* Add Dish Modal */}
      <Modal visible={showAdd} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalBox}>
            <Text style={styles.modalTitle}>Add New Dish</Text>

            <Text style={styles.label}>Dish Name *</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g. Butter Chicken"
              placeholderTextColor={COLORS.muted}
              value={fName}
              onChangeText={setFName}
            />

            <View style={styles.row}>
              <View style={styles.half}>
                <Text style={styles.label}>Price (₹) *</Text>
                <TextInput
                  style={styles.input}
                  placeholder="280"
                  placeholderTextColor={COLORS.muted}
                  value={fPrice}
                  onChangeText={setFPrice}
                  keyboardType="numeric"
                />
              </View>
              <View style={styles.half}>
                <Text style={styles.label}>Emoji</Text>
                <TextInput
                  style={styles.input}
                  placeholder="🍛"
                  placeholderTextColor={COLORS.muted}
                  value={fEmoji}
                  onChangeText={setFEmoji}
                  maxLength={4}
                />
              </View>
            </View>

            <Text style={styles.label}>Category</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.catScroll}>
              {categories.map(c => (
                <TouchableOpacity
                  key={c}
                  style={[styles.catPill, fCategory === c && styles.catActive]}
                  onPress={() => setFCategory(c)}
                >
                  <Text style={[styles.catText, fCategory === c && styles.catTextActive]}>{c}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            <Text style={styles.label}>Description</Text>
            <TextInput
              style={[styles.input, { height: 60 }]}
              placeholder="Short description"
              placeholderTextColor={COLORS.muted}
              value={fDesc}
              onChangeText={setFDesc}
              multiline
            />

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelBtn}
                onPress={() => { setShowAdd(false); clearForm(); }}
              >
                <Text style={styles.cancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.addBtn, saving && { opacity: 0.6 }]}
                onPress={addDish}
                disabled={saving}
              >
                <Text style={styles.addBtnText}>{saving ? 'Adding...' : '+ Add to Menu'}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.bg },
  content: { padding: 20, paddingTop: 16, paddingBottom: 80 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  title: { fontSize: 24, color: COLORS.white, ...FONTS.bold },
  sub: { fontSize: 13, color: COLORS.muted, marginTop: 4 },

  section: { marginBottom: 20 },
  sectionTitle: {
    fontSize: 13, color: COLORS.lime, letterSpacing: 1, textTransform: 'uppercase',
    marginBottom: 8, ...FONTS.semibold,
  },

  empty: { alignItems: 'center', paddingVertical: 60 },
  emptyIcon: { fontSize: 36, marginBottom: 12 },
  emptyText: { fontSize: 14, color: COLORS.muted, textAlign: 'center' },

  fab: {
    position: 'absolute', bottom: 24, right: 24,
    width: 56, height: 56, borderRadius: 28,
    backgroundColor: COLORS.lime, alignItems: 'center', justifyContent: 'center',
    elevation: 6,
    shadowColor: COLORS.lime, shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3, shadowRadius: 8,
  },

  modalOverlay: {
    flex: 1, backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  modalBox: {
    backgroundColor: COLORS.surface1, borderTopLeftRadius: RADIUS.lg, borderTopRightRadius: RADIUS.lg,
    padding: 24, paddingBottom: 40, borderWidth: 1, borderColor: COLORS.border,
  },
  modalTitle: { fontSize: 18, color: COLORS.white, marginBottom: 20, ...FONTS.bold },

  label: { fontSize: 12, color: COLORS.muted, marginBottom: 6, marginTop: 4 },
  input: {
    backgroundColor: COLORS.surface2, borderWidth: 1, borderColor: COLORS.border,
    borderRadius: RADIUS.sm, padding: 12, fontSize: 14, color: COLORS.white, marginBottom: 8,
  },
  row: { flexDirection: 'row', gap: 12 },
  half: { flex: 1 },

  catScroll: { marginBottom: 10 },
  catPill: {
    paddingHorizontal: 14, paddingVertical: 8, borderRadius: RADIUS.full,
    borderWidth: 1, borderColor: COLORS.border, marginRight: 8, backgroundColor: COLORS.surface2,
  },
  catActive: { borderColor: COLORS.limeAlpha30, backgroundColor: COLORS.limeAlpha08 },
  catText: { fontSize: 12, color: COLORS.muted },
  catTextActive: { color: COLORS.lime, ...FONTS.semibold },

  modalActions: { flexDirection: 'row', gap: 12, marginTop: 16 },
  cancelBtn: {
    flex: 1, borderWidth: 1, borderColor: COLORS.border, borderRadius: RADIUS.sm,
    padding: 14, alignItems: 'center',
  },
  cancelText: { color: COLORS.muted, fontSize: 14, ...FONTS.medium },
  addBtn: {
    flex: 2, backgroundColor: COLORS.lime, borderRadius: RADIUS.sm,
    padding: 14, alignItems: 'center',
  },
  addBtnText: { color: '#050505', fontSize: 14, ...FONTS.bold },
});
