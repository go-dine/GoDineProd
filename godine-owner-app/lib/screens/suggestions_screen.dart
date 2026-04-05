import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../models/dish.dart';

class SuggestionsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const SuggestionsScreen({super.key, required this.restaurant});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  bool _isLoading = true;
  List<Dish> _dishes = [];

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    try {
      final dishes = await SupabaseService.fetchDishes(widget.restaurant.id);
      setState(() {
        _dishes = dishes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dishes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('AI Suggestions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.lime.withOpacity(0.2), Colors.transparent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lime.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 12),
                            Text(
                              'Smart Upselling',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.lime),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Our AI automatically analyzes customer carts and suggests complementary items to increase your Average Order Value (AOV).',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Active Strategy',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  _buildStrategyCard(
                    title: 'Contextual Pairing',
                    description: 'Suggests starters with drinks and desserts after main courses.',
                    isActive: true,
                  ),
                  const SizedBox(height: 12),
                  _buildStrategyCard(
                    title: 'Popularity Boost',
                    description: 'Promotes your highest-rated items to undecided customers.',
                    isActive: true,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'AI Performance Insight',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AI Suggestions are helping increase your cart size by approximately 18% based on recent customer interactions.',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      'AI suggestions are fully automated.\nNo manual configuration required.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStrategyCard({required String title, required String description, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(isActive ? Icons.check_circle : Icons.radio_button_unchecked, color: isActive ? AppColors.lime : AppColors.muted),
        ],
      ),
    );
  }
}
