import 'package:flutter/material.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  static const _styles = {
    'pending': _StatusStyle(AppColors.amberAlpha, AppColors.amber, 'PENDING'),
    'preparing': _StatusStyle(AppColors.limeAlpha08, AppColors.lime, 'PREPARING'),
    'ready': _StatusStyle(AppColors.greenAlpha, AppColors.green, 'READY'),
    'completed': _StatusStyle(AppColors.surface3, AppColors.muted, 'COMPLETED'),
  };

  @override
  Widget build(BuildContext context) {
    final s = _styles[status] ?? _styles['pending']!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: s.color,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color bg;
  final Color color;
  final String label;
  const _StatusStyle(this.bg, this.color, this.label);
}
