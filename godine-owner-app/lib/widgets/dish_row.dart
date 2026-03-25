import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/dish.dart';

class DishRow extends StatelessWidget {
  final Dish dish;
  final void Function(String id, bool available) onToggle;
  final void Function(String id, String name) onDelete;

  const DishRow({
    super.key,
    required this.dish,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Emoji
          SizedBox(
            width: 36,
            child: Text(
              dish.emoji.isNotEmpty ? dish.emoji : '🍽️',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dish.category} · ₹${dish.price.toStringAsFixed(0)}${dish.description.isNotEmpty ? ' · ${dish.description}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: dish.available,
                onChanged: (val) => onToggle(dish.id, val),
                activeColor: AppColors.lime,
                activeTrackColor: AppColors.limeAlpha30,
                inactiveThumbColor: AppColors.muted,
                inactiveTrackColor: AppColors.surface3,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onDelete(dish.id, dish.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.redAlpha,
                    border: Border.all(color: AppColors.redBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
