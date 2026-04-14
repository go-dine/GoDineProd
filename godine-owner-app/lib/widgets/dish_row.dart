import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/dish.dart';

class DishRow extends StatelessWidget {
  final Dish dish;
  final void Function(String id, bool available) onToggle;
  final void Function(String id, bool isFeatured) onToggleFeatured;
  final VoidCallback onEdit;
  final void Function(String id, String name) onDelete;

  const DishRow({
    super.key,
    required this.dish,
    required this.onToggle,
    required this.onToggleFeatured,
    required this.onEdit,
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
          // Visual (Image or Emoji)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                ? Image.network(
                    dish.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        dish.emoji.isNotEmpty ? dish.emoji : '🍽️',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      dish.emoji.isNotEmpty ? dish.emoji : '🍽️',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        dish.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    if (dish.isFeatured) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.lime),
                    ],
                  ],
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
              IconButton(
                icon: Icon(
                  dish.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                  color: dish.isFeatured ? AppColors.lime : AppColors.muted,
                  size: 20,
                ),
                onPressed: () => onToggleFeatured(dish.id, !dish.isFeatured),
                tooltip: "Mark as Chef's Recommendation",
              ),
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
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
