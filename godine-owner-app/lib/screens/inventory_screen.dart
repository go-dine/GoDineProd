/// GoDine — Inventory Management Screen
/// Full-featured screen for viewing, adding, editing, and deleting inventory items.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../widgets/inventory_tile.dart';

class InventoryScreen extends StatefulWidget {
  final Restaurant restaurant;
  const InventoryScreen({super.key, required this.restaurant});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = InventoryService.subscribeToChanges(
      'inv-screen-${widget.restaurant.id}',
      widget.restaurant.id,
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    if (_channel != null) InventoryService.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await InventoryService.fetchItems(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final thresholdCtrl = TextEditingController(text: '5');
    final costCtrl = TextEditingController();
    String selectedUnit = 'kg';
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Inventory Item',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Name
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Item Name', 'e.g. Tomatoes'),
                autofocus: true,
              ),
              const SizedBox(height: 14),

              // Unit dropdown
              DropdownButtonFormField<String>(
                value: selectedUnit,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDeco('Unit', ''),
                items: ['kg', 'pieces', 'litres', 'grams', 'packs', 'bottles']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedUnit = v ?? 'kg'),
              ),
              const SizedBox(height: 14),

              // Quantity + Threshold row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Quantity', '0'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: thresholdCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Low Threshold', '5'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cost price
              TextField(
                controller: costCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Cost Price (₹)', 'Optional'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),

              // Add button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item name is required'),
                                backgroundColor: Color(0xFF7F1D1D),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => isAdding = true);
                          try {
                            await InventoryService.createItem(
                              restaurantId: widget.restaurant.id,
                              name: name,
                              unit: selectedUnit,
                              quantity: double.tryParse(qtyCtrl.text) ?? 0,
                              lowStockThreshold: double.tryParse(thresholdCtrl.text) ?? 5,
                              costPrice: costCtrl.text.isNotEmpty
                                  ? double.tryParse(costCtrl.text)
                                  : null,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Item added to inventory'),
                                  backgroundColor: Color(0xFF064E3B),
                                ),
                              );
                            }
                          } catch (e) {
                            setSheetState(() => isAdding = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⚠️ ${e.toString()}'),
                                  backgroundColor: const Color(0xFF7F1D1D),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  child: isAdding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                        )
                      : const Text('+ Add to Inventory'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
      hintStyle: TextStyle(color: AppColors.muted.withOpacity(0.5), fontSize: 13),
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lime),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  void _showEditQtyDialog(InventoryItem item) {
    final ctrl = TextEditingController(text: item.quantity.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(
          'Update ${item.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: item.unit,
            suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              final qty = double.tryParse(ctrl.text);
              if (qty == null || qty < 0) return;
              Navigator.pop(ctx);
              try {
                await InventoryService.updateQuantity(item.id, widget.restaurant.id, qty);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Quantity updated'),
                      backgroundColor: Color(0xFF064E3B),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ ${e.toString()}'),
                      backgroundColor: const Color(0xFF7F1D1D),
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Delete Item', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "${item.name}" from inventory?',
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await InventoryService.deleteItem(item.id, widget.restaurant.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Item deleted'),
            backgroundColor: Color(0xFF064E3B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${e.toString()}'),
            backgroundColor: const Color(0xFF7F1D1D),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowCount = _items.where((i) => i.isLowStock || i.isOutOfStock).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${_items.length} items${lowCount > 0 ? ' • $lowCount alerts' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddSheet();
        },
        backgroundColor: AppColors.lime,
        child: const Icon(Icons.add_rounded, color: AppColors.bg),
      ),
      body: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.surface1,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
            : _items.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📦', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text(
                                'No inventory items yet',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap + to add your first item',
                                style: TextStyle(color: AppColors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteItem(item);
                          return false; // We handle deletion ourselves
                        },
                        child: InventoryTile(
                          item: item,
                          onTap: () => _showEditQtyDialog(item),
                          onDelete: () => _deleteItem(item),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                      .slideX(begin: 0.05, end: 0, duration: 300.ms, delay: (50 * index).ms);
                    },
                  ),
      ),
    );
  }
}
