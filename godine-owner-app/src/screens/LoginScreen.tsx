import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ScrollView, ActivityIndicator,
} from 'react-native';
import { COLORS, RADIUS, FONTS } from '../theme';
import { supabase, SecureStorage, Restaurant } from '../lib/supabase';

interface LoginScreenProps {
  onLogin: (restaurant: Restaurant) => void;
}

export default function LoginScreen({ onLogin }: LoginScreenProps) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [slug, setSlug] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [tables, setTables] = useState('10');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const autoSlug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  async function handleLogin() {
    const s = slug.trim().toLowerCase();
    const pw = password.trim();
    if (!s || !pw) { setError('Please enter slug and password'); return; }
    setLoading(true);
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('restaurants')
        .select('*')
        .eq('slug', s)
        .single();
      if (err || !data) { setError('Restaurant not found'); setLoading(false); return; }
      if (data.owner_password !== pw) { setError('Incorrect password'); setLoading(false); return; }
      await SecureStorage.save('gd_auth', JSON.stringify({ id: data.id, slug: data.slug }));
      onLogin(data as Restaurant);
    } catch (e) {
      setError('Connection error. Check internet and try again.');
    }
    setLoading(false);
  }

  async function handleRegister() {
    const n = name.trim();
    const s = (slug.trim() || autoSlug).toLowerCase().replace(/[^a-z0-9-]/g, '');
    const pw = password.trim();
    const t = parseInt(tables) || 10;
    if (!n || !s || !pw) { setError('Name, slug and password are required'); return; }
    if (s.length < 3) { setError('Slug must be at least 3 characters'); return; }
    setLoading(true);
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('restaurants')
        .insert({ name: n, slug: s, owner_password: pw, total_tables: t })
        .select()
        .single();
      if (err) {
        if (err.message.includes('duplicate') || err.message.includes('unique')) {
          setError('This slug is already taken. Try another.');
        } else {
          setError('Failed to register: ' + err.message);
        }
        setLoading(false);
        return;
      }
      await SecureStorage.save('gd_auth', JSON.stringify({ id: data.id, slug: data.slug }));
      onLogin(data as Restaurant);
    } catch (e) {
      setError('Connection error. Try again.');
    }
    setLoading(false);
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        contentContainerStyle={styles.scroll}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.box}>
          {/* Logo */}
          <Text style={styles.logo}>Go<Text style={styles.logoAccent}>Dine</Text></Text>
          <Text style={styles.subtitle}>
            {mode === 'login' ? 'Owner Dashboard · Sign In' : 'Register your restaurant'}
          </Text>

          {/* Register: Name */}
          {mode === 'register' && (
            <>
              <Text style={styles.label}>Restaurant Name *</Text>
              <TextInput
                style={styles.input}
                placeholder="e.g. The Rustic Fork"
                placeholderTextColor={COLORS.muted}
                value={name}
                onChangeText={(t) => { setName(t); if (!slug) {} }}
                autoCapitalize="words"
              />
            </>
          )}

          {/* Slug */}
          <Text style={styles.label}>{mode === 'login' ? 'Restaurant Slug' : 'URL Slug *'}</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g. rustic-fork"
            placeholderTextColor={COLORS.muted}
            value={slug || (mode === 'register' ? autoSlug : '')}
            onChangeText={setSlug}
            autoCapitalize="none"
            autoCorrect={false}
          />
          {mode === 'register' && (
            <Text style={styles.slugPreview}>
              Menu URL: <Text style={styles.slugAccent}>menu.html?r={slug || autoSlug || 'your-slug'}</Text>
            </Text>
          )}

          {/* Password */}
          <Text style={styles.label}>Password{mode === 'register' ? ' *' : ''}</Text>
          <TextInput
            style={styles.input}
            placeholder={mode === 'login' ? 'Enter owner password' : 'Create a password'}
            placeholderTextColor={COLORS.muted}
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            onSubmitEditing={mode === 'login' ? handleLogin : handleRegister}
          />

          {/* Register: Tables */}
          {mode === 'register' && (
            <>
              <Text style={styles.label}>Number of Tables</Text>
              <TextInput
                style={styles.input}
                placeholder="10"
                placeholderTextColor={COLORS.muted}
                value={tables}
                onChangeText={setTables}
                keyboardType="number-pad"
              />
            </>
          )}

          {/* Error */}
          {error ? <Text style={styles.error}>{error}</Text> : null}

          {/* Button */}
          <TouchableOpacity
            style={[styles.btn, loading && styles.btnDisabled]}
            onPress={mode === 'login' ? handleLogin : handleRegister}
            activeOpacity={0.7}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#050505" size="small" />
            ) : (
              <Text style={styles.btnText}>
                {mode === 'login' ? 'Sign In →' : 'Create Restaurant →'}
              </Text>
            )}
          </TouchableOpacity>

          {/* Toggle */}
          <View style={styles.toggle}>
            <Text style={styles.toggleText}>
              {mode === 'login' ? 'New restaurant? ' : 'Already registered? '}
            </Text>
            <TouchableOpacity onPress={() => { setMode(mode === 'login' ? 'register' : 'login'); setError(''); }}>
              <Text style={styles.toggleLink}>
                {mode === 'login' ? 'Register here' : 'Sign in'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  scroll: {
    flexGrow: 1,
    justifyContent: 'center',
    padding: 20,
  },
  box: {
    backgroundColor: COLORS.surface1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.lg,
    padding: 32,
    width: '100%',
    maxWidth: 420,
    alignSelf: 'center',
  },
  logo: {
    fontSize: 24,
    color: COLORS.white,
    textAlign: 'center',
    marginBottom: 6,
    ...FONTS.bold,
  },
  logoAccent: {
    color: COLORS.lime,
  },
  subtitle: {
    fontSize: 13,
    color: COLORS.muted,
    textAlign: 'center',
    marginBottom: 28,
  },
  label: {
    fontSize: 12,
    color: COLORS.muted,
    marginBottom: 6,
    marginTop: 4,
  },
  input: {
    backgroundColor: COLORS.surface2,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: RADIUS.sm,
    padding: 12,
    fontSize: 14,
    color: COLORS.white,
    marginBottom: 10,
  },
  slugPreview: {
    fontSize: 11,
    color: COLORS.muted,
    marginTop: -4,
    marginBottom: 8,
  },
  slugAccent: {
    color: COLORS.lime,
    ...FONTS.semibold,
  },
  error: {
    fontSize: 12,
    color: COLORS.red,
    marginTop: 6,
    marginBottom: 4,
    textAlign: 'center',
  },
  btn: {
    backgroundColor: COLORS.lime,
    borderRadius: RADIUS.sm,
    padding: 14,
    alignItems: 'center',
    marginTop: 10,
  },
  btnDisabled: {
    opacity: 0.6,
  },
  btnText: {
    color: '#050505',
    fontSize: 14,
    ...FONTS.bold,
  },
  toggle: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 18,
  },
  toggleText: {
    fontSize: 13,
    color: COLORS.muted,
  },
  toggleLink: {
    fontSize: 13,
    color: COLORS.lime,
    ...FONTS.semibold,
  },
});
