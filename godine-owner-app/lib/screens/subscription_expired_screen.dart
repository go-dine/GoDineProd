/// GoDine — Subscription Expired Screen
/// Non-dismissable full screen shown when restaurant is deactivated.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';

class SubscriptionExpiredScreen extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onReactivated;

  const SubscriptionExpiredScreen({
    super.key,
    required this.restaurant,
    required this.onReactivated,
  });

  @override
  State<SubscriptionExpiredScreen> createState() => _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends State<SubscriptionExpiredScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    try {
      final updated = await SupabaseService.fetchCurrentRestaurant();
      if (updated != null && updated.isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Your subscription is now active!'),
              backgroundColor: Color(0xFF064E3B),
            ),
          );
          widget.onReactivated();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Subscription is still inactive. Please try again after payment.'),
              backgroundColor: Color(0xFF78350F),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error checking status: ${e.toString()}'),
            backgroundColor: const Color(0xFF7F1D1D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expDate = widget.restaurant.subscriptionEnd;
    final expStr = expDate != null ? DateFormat('dd MMM yyyy').format(expDate) : 'N/A';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF450A0A),
                    border: Border.all(color: const Color(0xFF7F1D1D), width: 2),
                  ),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                const Text(
                  'Subscription Expired',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Your GoDine subscription for ${widget.restaurant.name} expired on $expStr.\n\nRenew now to continue managing orders and your menu.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),

                // Renew button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to overview which has the Razorpay payment flow
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Renew Subscription →'),
                  ),
                ),
                const SizedBox(height: 14),

                // Check status button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _checking ? null : _checkStatus,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime),
                          )
                        : const Text(
                            "I've paid — Check status",
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                  ),
                ),
                const SizedBox(height: 40),

                // Powered by badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(0.05),
                    border: Border.all(color: AppColors.lime.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'POWERED BY GODINE',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
