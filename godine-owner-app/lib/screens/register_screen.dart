import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  int _selectedPlan = 2; // 1: Basic, 2: Pro, 3: Advanced, 4: Annual
  int _qrCount = 0;
  bool _isLoading = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _slugCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.red));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.lime, action: SnackBarAction(label: 'OK', textColor: Colors.black, onPressed: () {})));
  }

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final slug = _slugCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text.trim();

    if (name.isEmpty || slug.isEmpty || email.isEmpty || pw.length < 6) {
      _showError('Please fill all required fields correctly (Password min 6 chars).');
      return;
    }

    if (_qrCount > 0) {
      if (_addressCtrl.text.isEmpty || _pincodeCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
        _showError('Please provide delivery details for the physical QR stands.');
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final plans = {1: 'basic', 2: 'pro', 3: 'advanced', 4: 'annual'};
      
      // Phase 1: Insert row
      final response = await SupabaseService.client.from('restaurants').insert({
        'name': name,
        'slug': slug,
        'owner_email': email,
        'owner_password': pw,
        'total_tables': 10,
        'plan': plans[_selectedPlan],
        'is_verified': false,
        'is_trial': true,
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'physical_qr_requested': _qrCount > 0,
        'physical_qr_count': _qrCount,
        'delivery_address': _addressCtrl.text,
        'delivery_pincode': _pincodeCtrl.text,
        'delivery_phone': _phoneCtrl.text,
      }).select().single();

      final restId = response['id'];

      // Phase 2: Create Razorpay Order
      int baseAmount = 20000;
      if (_selectedPlan == 2) baseAmount = 30000;
      else if (_selectedPlan == 3) baseAmount = 40000;
      else if (_selectedPlan == 4) baseAmount = 350000;

      final amount = baseAmount + (_qrCount * 10000);

      // In a real app, this should fetch from your Supabase config or env
      const supabaseUrl = 'https://qqnrucnsvupfywyzlofa.supabase.co'; 
      const razorpayKeyId = 'rzp_test_Sftzc4oWuOEUPH'; // Placeholder from config.js

      final orderRes = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/create-razorpay-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount, 'plan': _selectedPlan, 'restaurant_id': restId}),
      );

      final orderData = jsonDecode(orderRes.body);
      if (orderRes.statusCode != 200) throw Exception(orderData['error'] ?? 'Failed to create order');

      // Store current restId in memory for verification
      _currentRestId = restId;

      var options = {
        'key': razorpayKeyId,
        'amount': orderData['amount'],
        'name': 'Go Dine',
        'description': 'Registration & Subscription',
        'order_id': orderData['id'],
        'prefill': {'contact': _phoneCtrl.text, 'email': email},
        'theme': {'color': '#b6ff2a'}
      };

      _razorpay.open(options);

    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  String _currentRestId = '';

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      const supabaseUrl = 'https://qqnrucnsvupfywyzlofa.supabase.co'; 
      final verifyRes = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/verify-razorpay-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
          'restaurant_id': _currentRestId,
          'plan_id': _selectedPlan
        }),
      );
      
      final verifyData = jsonDecode(verifyRes.body);
      if (verifyRes.statusCode != 200) throw Exception(verifyData['error'] ?? 'Verification failed');

      _showSuccess('Payment successful! You can now log in.');
      Navigator.pop(context);
    } catch (e) {
      _showError('Payment verification failed: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showError('Payment failed: ${response.message}');
    setState(() => _isLoading = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallets not supported');
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    int planPrice = 200;
    if (_selectedPlan == 2) planPrice = 300;
    else if (_selectedPlan == 3) planPrice = 400;
    else if (_selectedPlan == 4) planPrice = 3500;
    
    int total = planPrice + (_qrCount * 100);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Register Restaurant', style: TextStyle(fontSize: 16)),
        backgroundColor: AppColors.surface1,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section A: Profile
            const Text('Section A: Profile & Security', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _input(_nameCtrl, 'Restaurant Name', (v) {
              _slugCtrl.text = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
            }),
            _input(_locationCtrl, 'City / Location'),
            _input(_slugCtrl, 'URL Slug (e.g. grand-bistro)'),
            _input(_emailCtrl, 'Owner Email', keyboardType: TextInputType.emailAddress),
            _input(_passwordCtrl, 'Password (Min 6 chars)', obscure: true),
            
            const SizedBox(height: 24),
            
            // Section B: Plan
            const Text('Section B: Plan Selection', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _planCard('Basic', '₹200/mo', 1),
                _planCard('Pro', '₹300/mo', 2),
                _planCard('Advanced', '₹400/mo', 3),
                _planCard('Annual', '₹3500/yr', 4),
              ],
            ),
            
            const SizedBox(height: 24),

            // Section C: Physical QR
            const Text('Section C: Physical QR Stands', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _qrCount,
              dropdownColor: AppColors.surface2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text("No stands (Free)")),
                DropdownMenuItem(value: 5, child: Text("5 Stands (₹500)")),
                DropdownMenuItem(value: 10, child: Text("10 Stands (₹1000)")),
                DropdownMenuItem(value: 20, child: Text("20 Stands (₹2000)")),
              ],
              onChanged: (val) => setState(() => _qrCount = val ?? 0),
            ),
            if (_qrCount > 0) ...[
              const SizedBox(height: 12),
              _input(_addressCtrl, 'Delivery Address'),
              _input(_pincodeCtrl, 'Pincode', keyboardType: TextInputType.number),
              _input(_phoneCtrl, 'Phone Number', keyboardType: TextInputType.phone),
            ],

            const SizedBox(height: 24),

            // Section D: Payment Summary
            const Text('Section D: Payment Summary', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Plan (includes 7-Day Trial)', style: TextStyle(color: AppColors.muted)), Text('₹$planPrice', style: const TextStyle(color: Colors.white))]),
                  if (_qrCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$_qrCount× Physical QR Stands', style: const TextStyle(color: AppColors.muted)), Text('₹${_qrCount * 100}', style: const TextStyle(color: Colors.white))]),
                    ),
                  const Divider(color: AppColors.border, height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Due Today', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)), Text('₹$total', style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold))]),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('Pay & Register', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _planCard(String name, String price, int id) {
    final isSelected = _selectedPlan == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime.withOpacity(0.1) : AppColors.surface2,
          border: Border.all(color: isSelected ? AppColors.lime : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(name, style: TextStyle(color: isSelected ? AppColors.lime : Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, [Function(String)? onChanged, TextInputType? keyboardType, bool obscure = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.muted),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
