import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { COLORS, FONTS } from '../theme';
import { Restaurant } from '../lib/supabase';
import OverviewScreen from '../screens/OverviewScreen';
import OrdersScreen from '../screens/OrdersScreen';
import RevenueScreen from '../screens/RevenueScreen';
import MenuScreen from '../screens/MenuScreen';

const Tab = createBottomTabNavigator();

const DarkTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: COLORS.bg,
    card: COLORS.surface1,
    border: COLORS.border,
    text: COLORS.white,
    primary: COLORS.lime,
  },
};

interface AppNavigatorProps {
  restaurant: Restaurant;
}

export default function AppNavigator({ restaurant }: AppNavigatorProps) {
  const [pendingCount, setPendingCount] = useState(0);

  const handlePendingCount = useCallback((count: number) => {
    setPendingCount(count);
  }, []);

  return (
    <NavigationContainer theme={DarkTheme}>
      <Tab.Navigator
        screenOptions={{
          headerShown: false,
          tabBarStyle: styles.tabBar,
          tabBarActiveTintColor: COLORS.lime,
          tabBarInactiveTintColor: COLORS.muted,
          tabBarLabelStyle: styles.tabLabel,
          tabBarItemStyle: styles.tabItem,
        }}
      >
        <Tab.Screen
          name="Overview"
          options={{
            tabBarIcon: ({ focused }) => <Text style={styles.tabIcon}>📊</Text>,
            tabBarLabel: 'Overview',
          }}
        >
          {() => <OverviewScreen restaurant={restaurant} />}
        </Tab.Screen>

        <Tab.Screen
          name="Orders"
          options={{
            tabBarIcon: ({ focused }) => <Text style={styles.tabIcon}>🧾</Text>,
            tabBarLabel: 'Orders',
            tabBarBadge: pendingCount > 0 ? pendingCount : undefined,
            tabBarBadgeStyle: styles.badge,
          }}
        >
          {() => <OrdersScreen restaurant={restaurant} onPendingCount={handlePendingCount} />}
        </Tab.Screen>

        <Tab.Screen
          name="Revenue"
          options={{
            tabBarIcon: ({ focused }) => <Text style={styles.tabIcon}>💰</Text>,
            tabBarLabel: 'Revenue',
          }}
        >
          {() => <RevenueScreen restaurant={restaurant} />}
        </Tab.Screen>

        <Tab.Screen
          name="Menu"
          options={{
            tabBarIcon: ({ focused }) => <Text style={styles.tabIcon}>🍽</Text>,
            tabBarLabel: 'Menu',
          }}
        >
          {() => <MenuScreen restaurant={restaurant} />}
        </Tab.Screen>
      </Tab.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: COLORS.surface1,
    borderTopColor: COLORS.border,
    borderTopWidth: 1,
    height: 60,
    paddingBottom: 6,
    paddingTop: 6,
  },
  tabLabel: {
    fontSize: 11,
    ...FONTS.semibold,
  },
  tabItem: {
    paddingVertical: 2,
  },
  tabIcon: {
    fontSize: 20,
  },
  badge: {
    backgroundColor: COLORS.lime,
    color: '#050505',
    fontSize: 10,
    fontWeight: '800',
    minWidth: 18,
    height: 18,
    lineHeight: 18,
    borderRadius: 9,
  },
});
