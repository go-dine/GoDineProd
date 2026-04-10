import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';

class WaiterCallsScreen extends StatefulWidget {
  final Restaurant restaurant;
  final void Function(int count)? onActiveCount;
  const WaiterCallsScreen({super.key, required this.restaurant, this.onActiveCount});

  @override
  State<WaiterCallsScreen> createState() => _WaiterCallsScreenState();
}

class _WaiterCallsScreenState extends State<WaiterCallsScreen> {
  List<Map<String, dynamic>> _activeCalls = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.subscribeToWaiterCalls(
      'owner-waiter-calls-${widget.restaurant.id}',
      widget.restaurant.id,
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final calls = await SupabaseService.fetchActiveWaiterCalls(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _activeCalls = calls;
        _loading = false;
      });
      widget.onActiveCount?.call(calls.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(String callId) async {
    HapticFeedback.mediumImpact();
    try {
      await SupabaseService.dismissWaiterCall(callId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Call dismissed'),
            backgroundColor: AppColors.lime,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to dismiss call'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final time = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(time).inSeconds;
      if (diff < 60) return '${diff}s ago';
      if (diff < 3600) return '${diff ~/ 60}m ago';
      return '${diff ~/ 3600}h ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        title: Row(
          children: [
            const Text('Waiter Calls', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            if (_activeCalls.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                ),
                child: Text(
                  '${_activeCalls.length} active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B35),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _activeCalls.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.lime,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔕', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 16),
                          Text(
                            'No active waiter calls',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'When a customer calls for a waiter,\nit will appear here in real-time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.lime,
                  backgroundColor: AppColors.surface1,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: _activeCalls.length,
                    itemBuilder: (context, index) {
                      final call = _activeCalls[index];
                      return _WaiterCallCard(
                        tableNumber: call['table_number']?.toString() ?? '?',
                        timeAgo: _timeAgo(call['called_at']?.toString() ?? call['created_at']?.toString()),
                        onDismiss: () => _dismiss(call['id']),
                      );
                    },
                  ),
                ),
    );
  }
}

class _WaiterCallCard extends StatefulWidget {
  final String tableNumber;
  final String timeAgo;
  final VoidCallback onDismiss;

  const _WaiterCallCard({
    required this.tableNumber,
    required this.timeAgo,
    required this.onDismiss,
  });

  @override
  State<_WaiterCallCard> createState() => _WaiterCallCardState();
}

class _WaiterCallCardState extends State<_WaiterCallCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = 0.08 + (_pulseAnimation.value * 0.12);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFFF6B35).withOpacity(0.2),
                const Color(0xFFFF6B35).withOpacity(0.5),
                _pulseAnimation.value,
              )!,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(glowOpacity),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              // Bell icon with animated background
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
                ),
                child: const Center(
                  child: Text('🔔', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table ${widget.tableNumber}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Needs assistance • ${widget.timeAgo}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: const Color(0xFF050505),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Mark as Attended',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
