import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  final void Function(Restaurant restaurant) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String _error = '';

  final _slugCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _tablesCtrl = TextEditingController(text: '10');

  String get _autoSlug =>
      _nameCtrl.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  @override
  void dispose() {
    _slugCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _tablesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final slug = _slugCtrl.text.trim().toLowerCase();
    final pw = _passwordCtrl.text.trim();
    if (slug.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Please enter slug and password');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final restaurant = await SupabaseService.login(slug, pw);
      if (restaurant == null) {
        setState(() => _error = 'Invalid slug or password');
      } else {
        widget.onLogin(restaurant);
      }
    } catch (e) {
      setState(() => _error = 'Connection error. Check internet and try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final slug = (_slugCtrl.text.trim().isEmpty ? _autoSlug : _slugCtrl.text.trim())
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final pw = _passwordCtrl.text.trim();
    final tables = int.tryParse(_tablesCtrl.text) ?? 10;
    if (name.isEmpty || slug.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Name, slug and password are required');
      return;
    }
    if (slug.length < 3) {
      setState(() => _error = 'Slug must be at least 3 characters');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final restaurant = await SupabaseService.register(
        name: name,
        slug: slug,
        password: pw,
        totalTables: tables,
      );
      if (restaurant != null) widget.onLogin(restaurant);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        setState(() => _error = 'This slug is already taken. Try another.');
      } else {
        setState(() => _error = 'Failed to register: $msg');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentSlug = _slugCtrl.text.isNotEmpty ? _slugCtrl.text : _autoSlug;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                      text: 'Go',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                    TextSpan(
                      text: 'Dine',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.lime),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin ? 'Owner Dashboard · Sign In' : 'Register your restaurant',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Register: Name
                if (!_isLogin) ...[
                  _label('Restaurant Name *'),
                  _input(_nameCtrl, 'e.g. The Rustic Fork', capitalization: TextCapitalization.words),
                ],

                // Slug
                _label(_isLogin ? 'Restaurant Slug' : 'URL Slug *'),
                _input(
                  _slugCtrl,
                  'e.g. rustic-fork',
                  capitalization: TextCapitalization.none,
                ),
                if (!_isLogin && currentSlug.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Menu URL: ', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        TextSpan(
                          text: 'menu.html?r=$currentSlug',
                          style: const TextStyle(fontSize: 11, color: AppColors.lime, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),

                // Password
                _label('Password${!_isLogin ? ' *' : ''}'),
                _input(
                  _passwordCtrl,
                  _isLogin ? 'Enter owner password' : 'Create a password',
                  obscure: true,
                  onSubmit: _isLogin ? _handleLogin : _handleRegister,
                ),

                // Register: Tables
                if (!_isLogin) ...[
                  _label('Number of Tables'),
                  _input(_tablesCtrl, '10', keyboardType: TextInputType.number),
                ],

                // Error
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _error,
                      style: const TextStyle(fontSize: 12, color: AppColors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Button
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : (_isLogin ? _handleLogin : _handleRegister),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      disabledBackgroundColor: AppColors.lime.withOpacity(0.6),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                          )
                        : Text(
                            _isLogin ? 'Sign In →' : 'Create Restaurant →',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                // Toggle
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'New restaurant? ' : 'Already registered? ',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    GestureDetector(
                      onTap: () => setState(() { _isLogin = !_isLogin; _error = ''; }),
                      child: Text(
                        _isLogin ? 'Register here' : 'Sign in',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.lime,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String placeholder, {
    bool obscure = false,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onSubmit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        onSubmitted: (_) => onSubmit?.call(),
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: AppColors.white),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: AppColors.muted),
          filled: true,
          fillColor: AppColors.surface2,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.limeAlpha30),
          ),
        ),
      ),
    );
  }
}
