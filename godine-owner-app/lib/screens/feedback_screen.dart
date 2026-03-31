import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/feedback.dart';
import '../services/supabase_service.dart';

class FeedbackScreen extends StatefulWidget {
  final Restaurant? restaurant;
  const FeedbackScreen({super.key, this.restaurant});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = true;
  double _avgFood = 0;
  double _avgService = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<FeedbackModel> data;
      if (widget.restaurant != null) {
        data = await SupabaseService.fetchFeedback(widget.restaurant!.id);
      } else {
        // Global admin mode
        final raw = await SupabaseService.fetchAllFeedback();
        data = raw.map((e) => FeedbackModel.fromJson(e)).toList();
      }

      if (!mounted) return;
      setState(() {
        _feedbacks = data;
        _isLoading = false;
        if (data.isNotEmpty) {
          _avgFood = data.map((e) => e.foodRating).reduce((a, b) => a + b) / data.length;
          _avgService = data.map((e) => e.serviceRating).reduce((a, b) => a + b) / data.length;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: widget.restaurant == null ? const Color(0xFFFCA5A5) : AppColors.lime,
        backgroundColor: AppColors.surface1,
        child: _isLoading && _feedbacks.isEmpty
            ? Center(child: CircularProgressIndicator(color: widget.restaurant == null ? const Color(0xFFFCA5A5) : AppColors.lime))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  Text(widget.restaurant == null ? 'Platform Feedback' : 'Feedback', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
                  const SizedBox(height: 4),
                  Text(widget.restaurant == null ? 'All customer reviews across the platform' : 'Customer ratings & reviews', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 24),

                  if (_feedbacks.isNotEmpty) ...[
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                  ],

                  if (_feedbacks.isEmpty && !_isLoading)
                    _buildEmptyState()
                  else
                    ..._feedbacks.map((f) => _buildFeedbackCard(f)),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: widget.restaurant == null ? const Color(0xFF7F1D1D) : AppColors.limeAlpha18),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStat('Food', _avgFood),
          Container(width: 1, height: 40, color: AppColors.border),
          _buildSummaryStat('Service', _avgService),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, double val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(val.toStringAsFixed(1), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: widget.restaurant == null ? const Color(0xFFFCA5A5) : AppColors.lime)),
            const SizedBox(width: 4),
            const Text('⭐', style: TextStyle(fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(FeedbackModel f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.restaurant == null && f.restaurantName != null) ...[
            Text(
              f.restaurantName!.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFCA5A5), letterSpacing: 1),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                f.customerName?.isNotEmpty == true ? f.customerName! : 'Anonymous Guest',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
              Text(_formatDate(f.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _starBadge('🍽️', f.foodRating),
              const SizedBox(width: 8),
              _starBadge('🤝', f.serviceRating),
            ],
          ),
          if (f.comment?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              f.comment!,
              style: const TextStyle(fontSize: 13, color: AppColors.white, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _starBadge(String emoji, int val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$val', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.restaurant == null ? const Color(0xFFFCA5A5) : AppColors.lime)),
          const Text('⭐', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Text('💬', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('No feedback yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white)),
            SizedBox(height: 4),
            Text('Reviews from customers will appear here', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
