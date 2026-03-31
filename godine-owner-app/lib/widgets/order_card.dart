import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/order.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final void Function(String id, String newStatus) onAdvanceStatus;
  final void Function(String id) onComplete;
  final void Function(String id) onCancel;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAdvanceStatus,
    required this.onComplete,
    required this.onCancel,
  });

  static const _nextStatus = {
    'pending': _NextAction('preparing', '🔥 Start Preparing'),
    'preparing': _NextAction('ready', '✅ Mark Ready'),
    'ready': _NextAction('completed', '🎉 Complete'),
  };

  String _timeAgo(String iso) {
    final diff = DateTime.now().difference(DateTime.parse(iso)).inSeconds;
    if (diff < 60) return 'just now';
    if (diff < 3600) return '${diff ~/ 60} min ago';
    return '${diff ~/ 3600} hr ago';
  }

  Color get _borderColor {
    switch (order.status) {
      case 'pending':
        return const Color(0x33FBbF24);
      case 'preparing':
        return const Color(0x33B6FF2A);
      case 'ready':
        return const Color(0x404ADE80);
      case 'cancelled':
        return const Color(0x33FF4444);
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus[order.status];
    final isCompleted = order.status == 'completed';
    final isCancelled = order.status == 'cancelled';

    return Opacity(
      opacity: (isCompleted || isCancelled) ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Table ${order.tableNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        if (order.tokenNumber != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TOKEN: ${order.tokenNumber}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF050505),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(order.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                StatusBadge(status: order.status),
              ],
            ),

            // Customer info
            if (order.customerName != null || order.customerPhone != null) ...[
              const SizedBox(height: 10),
              Text(
                '👤 ${order.customerName ?? 'Anonymous'} (${order.customerPhone ?? 'No phone'})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
            ],

            // ETA badge
            if (order.status == 'preparing' && order.estimatedTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.limeAlpha08,
                  border: Border.all(color: AppColors.limeAlpha18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⏱️ ETA: ${order.estimatedTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lime,
                  ),
                ),
              ),
            ],

            // Items
            const SizedBox(height: 14),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${item.emoji} '),
                    TextSpan(
                      text: '${item.qty}×',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.white),
                    ),
                    TextSpan(text: ' ${item.name} — ₹${(item.price * item.qty).toStringAsFixed(0)}'),
                  ]),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                ),
              ),
            ),

            // Note
            if (order.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📝 ${order.note}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                Text(
                  'Total: ₹${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lime,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isCompleted && !isCancelled)
                      _RedButton(
                        label: 'Cancel',
                        onTap: () => onCancel(order.id),
                      ),
                    if (next != null)
                      _LimeButton(
                        label: next.label,
                        onTap: () => onAdvanceStatus(order.id, next.status),
                      ),
                    if (!isCompleted && !isCancelled && order.status != 'ready')
                      _GhostButton(
                        label: 'Complete',
                        onTap: () => onComplete(order.id),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAction {
  final String status;
  final String label;
  const _NextAction(this.status, this.label);
}

class _LimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LimeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF050505),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0x20FF4444),
          border: Border.all(color: const Color(0x40FF4444)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF4444),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
