import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';
import '../widgets/dish_row.dart';

class MenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  const MenuScreen({super.key, required this.restaurant});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Dish> _dishes = [];
  bool _saving = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'Main Course';

  static const _categories = [
    'Main Course',
    'Starters',
    'Beverages',
    'Desserts',
    'Breads',
    'Specials',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _emojiCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dishes = await SupabaseService.fetchDishes(widget.restaurant.id);
      if (mounted) setState(() => _dishes = dishes);
    } catch (_) {}
  }

  void _clearForm() {
    _nameCtrl.clear();
    _priceCtrl.clear();
    _emojiCtrl.clear();
    _descCtrl.clear();
    _selectedCategory = 'Main Course';
  }

  Future<void> _addDish() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text);
    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and valid price are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.addDish(
        restaurantId: widget.restaurant.id,
        name: name,
        price: price,
        category: _selectedCategory,
        emoji: _emojiCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      _clearForm();
      if (mounted) Navigator.pop(context);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add dish')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _toggleDish(String id, bool available) async {
    try {
      await SupabaseService.toggleDish(id, available);
      setState(() {
        _dishes = _dishes.map((d) => d.id == id ? d.copyWith(available: available) : d).toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update dish')),
        );
      }
    }
  }

  void _deleteDish(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Delete Dish', style: TextStyle(color: AppColors.white)),
        content: Text('Remove "$name" from your menu?', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.deleteDish(id);
                setState(() {
                  _dishes = _dishes.where((d) => d.id != id).toList();
                });
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete dish')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add New Dish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
                  const SizedBox(height: 20),

                  _sheetLabel('Dish Name *'),
                  _sheetInput(_nameCtrl, 'e.g. Butter Chicken'),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel('Price (₹) *'),
                            _sheetInput(_priceCtrl, '280', keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel('Emoji'),
                            _sheetInput(_emojiCtrl, '🍛', maxLength: 4),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _sheetLabel('Category'),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final active = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setSheetState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.limeAlpha08 : AppColors.surface2,
                              border: Border.all(color: active ? AppColors.limeAlpha30 : AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                color: active ? AppColors.lime : AppColors.muted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  _sheetLabel('Description'),
                  _sheetInput(_descCtrl, 'Short description', maxLines: 2),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _clearForm();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _addDish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lime,
                            foregroundColor: AppColors.bg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                            disabledBackgroundColor: AppColors.lime.withOpacity(0.6),
                          ),
                          child: Text(
                            _saving ? 'Adding...' : '+ Add to Menu',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Group dishes by category
  Map<String, List<Dish>> get _grouped {
    final map = <String, List<Dish>>{};
    for (final d in _dishes) {
      map.putIfAbsent(d.category, () => []).add(d);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.surface1,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white)),
                    const SizedBox(height: 4),
                    Text('${_dishes.length} items · Pull to refresh', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_dishes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Text('🍽', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 12),
                      Text('No dishes yet. Tap + to add your first dish!', style: TextStyle(fontSize: 14, color: AppColors.muted), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              ..._grouped.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lime,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map((d) => DishRow(
                            dish: d,
                            onToggle: _toggleDish,
                            onDelete: _deleteDish,
                          )),
                      const SizedBox(height: 20),
                    ],
                  )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.bg,
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }

  Widget _sheetInput(
    TextEditingController controller,
    String placeholder, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 14, color: AppColors.white),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: AppColors.muted),
          filled: true,
          fillColor: AppColors.surface2,
          counterText: '',
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.limeAlpha30),
          ),
        ),
      ),
    );
  }
}
