import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(Restaurant restaurant) onLogin;
  final VoidCallback onAdminLogin;
  final bool isInitializing;
  
  const LoginScreen({
    super.key, 
    required this.onLogin,
    required this.onAdminLogin,
    this.isInitializing = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final bool _isLogin = true;
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
      setState(() => _error = 'Please enter username and password');
      return;
    }

    if (slug == 'bhagwan' && pw == 'godmode') {
      await SupabaseService.saveAdminAuth();
      widget.onAdminLogin();
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      final restaurant = await SupabaseService.login(slug, pw);
      if (restaurant == null) {
        setState(() => _error = 'Invalid username or password');
      } else {
        if (!restaurant.isVerified) {
          setState(() => _error = 'Registration incomplete. Please register your restaurant.');
          // Future enhancement: Redirect directly to RegisterScreen with pre-filled details or payment UI.
          return;
        }
        widget.onLogin(restaurant);
      }
    } catch (e) {
      if (e.toString().contains('suspended')) {
        setState(() => _error = 'Account suspended by platform admin');
      } else {
        setState(() => _error = 'Connection error: ${e.toString().split('\n').first}');
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
                Center(
                  child: Image.asset('assets/splash-icon.png', height: 42, fit: BoxFit.contain),
                ),
                const SizedBox(height: 6),
                Text(
                  'Owner Dashboard · Sign In',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),



                _label('Restaurant Username'),
                _input(
                  _slugCtrl,
                  'e.g. rustic-fork',
                  capitalization: TextCapitalization.none,
                ),

                // Password
                _label('Password'),
                _input(
                  _passwordCtrl,
                  'Enter owner password',
                  obscure: true,
                  onSubmit: _handleLogin,
                ),



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
                    onPressed: (_loading || widget.isInitializing) ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      disabledBackgroundColor: AppColors.lime.withOpacity(0.6),
                    ),
                    child: (_loading || widget.isInitializing)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                          )
                        : const Text(
                            'Sign In →',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'New here? Register your restaurant →',
                    style: TextStyle(fontSize: 14, color: AppColors.lime, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Contact platform admin to join',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
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
