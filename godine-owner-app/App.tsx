import React, { useState, useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { View, StyleSheet, ActivityIndicator, Text } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { COLORS, FONTS } from './src/theme';
import { supabase, SecureStorage, Restaurant } from './src/lib/supabase';
import LoginScreen from './src/screens/LoginScreen';
import AppNavigator from './src/navigation/AppNavigator';

export default function App() {
  const [restaurant, setRestaurant] = useState<Restaurant | null>(null);
  const [loading, setLoading] = useState(true);

  // Auto-login from SecureStore
  useEffect(() => {
    (async () => {
      try {
        const saved = await SecureStorage.get('gd_auth');
        if (saved) {
          const { id } = JSON.parse(saved);
          const { data, error } = await supabase
            .from('restaurants')
            .select('*')
            .eq('id', id)
            .single();
          if (!error && data) {
            setRestaurant(data as Restaurant);
          }
        }
      } catch (e) {
        // Failed to auto-login, show login screen
      }
      setLoading(false);
    })();
  }, []);

  function handleLogin(r: Restaurant) {
    setRestaurant(r);
  }

  async function handleLogout() {
    await SecureStorage.remove('gd_auth');
    setRestaurant(null);
  }

  if (loading) {
    return (
      <View style={styles.loader}>
        <StatusBar style="light" />
        <Text style={styles.loaderLogo}>Go<Text style={{ color: COLORS.lime }}>Dine</Text></Text>
        <ActivityIndicator color={COLORS.lime} size="large" style={{ marginTop: 20 }} />
      </View>
    );
  }

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container} edges={['top']}>
        <StatusBar style="light" backgroundColor={COLORS.bg} />
        {restaurant ? (
          <View style={styles.app}>
            {/* Header bar */}
            <View style={styles.headerBar}>
              <Text style={styles.headerLogo}>Go<Text style={{ color: COLORS.lime }}>Dine</Text></Text>
              <Text style={styles.headerRestName}>{restaurant.name}</Text>
              <Text style={styles.logoutBtn} onPress={handleLogout}>Sign Out</Text>
            </View>
            <AppNavigator restaurant={restaurant} />
          </View>
        ) : (
          <LoginScreen onLogin={handleLogin} />
        )}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  app: {
    flex: 1,
  },
  loader: {
    flex: 1,
    backgroundColor: COLORS.bg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loaderLogo: {
    fontSize: 28,
    color: COLORS.white,
    ...FONTS.bold,
  },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: COLORS.surface1,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  headerLogo: {
    fontSize: 18,
    color: COLORS.white,
    ...FONTS.bold,
  },
  headerRestName: {
    flex: 1,
    fontSize: 12,
    color: COLORS.lime,
    marginLeft: 12,
    ...FONTS.semibold,
  },
  logoutBtn: {
    fontSize: 12,
    color: COLORS.muted,
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    overflow: 'hidden',
  },
});
