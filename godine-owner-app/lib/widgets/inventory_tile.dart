/// GoDine — Inventory Tile Widget
/// Reusable tile for displaying an inventory item in a list.

import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../theme.dart';

class InventoryTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<double>? onQuantityChanged;

  const InventoryTile({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.onQuantityChanged,
  });

  Color _statusColor() {
    switch (item.stockStatus) {
      case 'out':
        return const Color(0xFFEF4444);
      case 'low':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.lime;
    }
  }

  String _statusLabel() {
    switch (item.stockStatus) {
      case 'out':
        return 'OUT';
      case 'low':
        return 'LOW';
      default:
        return 'OK';
    }
  }

  IconData _statusIcon() {
    switch (item.stockStatus) {
      case 'out':
        return Icons.error_outline_rounded;
      case 'low':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCol = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isOutOfStock
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : item.isLowStock
                  ? const Color(0xFFF59E0B).withOpacity(0.2)
                  : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusCol.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(), color: statusCol, size: 20),
              ),
              const SizedBox(width: 14),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit} • Threshold: ${item.lowStockThreshold.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusCol.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: statusCol,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
