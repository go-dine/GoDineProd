import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../models/order.dart' as app_order;
import '../services/supabase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final void Function(Restaurant restaurant) onImpersonate;

  const AdminDashboardScreen({
    super.key,
    required this.onLogout,
    required this.onImpersonate,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7F1D1D),
        elevation: 0,
        title: const Text(
          '🔐 Master Admin Mode',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFCA5A5)),
        ),
        actions: [
          TextButton(
            onPressed: widget.onLogout,
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _AdminRestaurantsTab(onImpersonate: widget.onImpersonate),
          const _AdminOrdersTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface1,
        selectedItemColor: const Color(0xFFFCA5A5),
        unselectedItemColor: AppColors.muted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Text('🏢', style: TextStyle(fontSize: 20)), label: 'Restaurants'),
          BottomNavigationBarItem(icon: Text('📋', style: TextStyle(fontSize: 20)), label: 'All Orders'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESTAURANTS TAB (Drag/Drop Sort, Toggle, Impersonate)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminRestaurantsTab extends StatefulWidget {
  final void Function(Restaurant) onImpersonate;
  const _AdminRestaurantsTab({required this.onImpersonate});

  @override
  State<_AdminRestaurantsTab> createState() => _AdminRestaurantsTabState();
}

class _AdminRestaurantsTabState extends State<_AdminRestaurantsTab> {
  bool _loading = true;
  List<Restaurant> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final res = await SupabaseService.client
          .from('restaurants')
          .select()
          .order('sort_order')
          .order('created_at', ascending: false);
      
      setState(() {
        _restaurants = (res as List).map((r) => Restaurant.fromJson(r)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Restaurant r, bool val) async {
    final idx = _restaurants.indexOf(r);
    setState(() {
      _restaurants[idx] = Restaurant(
        id: r.id, name: r.name, slug: r.slug, ownerPassword: r.ownerPassword,
        totalTables: r.totalTables, isActive: val, sortOrder: r.sortOrder, createdAt: r.createdAt,
      );
    });
    try {
      await SupabaseService.client.from('restaurants').update({'is_active': val}).eq('id', r.id);
    } catch (_) {}
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _restaurants.removeAt(oldIndex);
      _restaurants.insert(newIndex, item);
      
      // Update local sort orders
      for (int i = 0; i < _restaurants.length; i++) {
        final r = _restaurants[i];
        _restaurants[i] = Restaurant(
          id: r.id, name: r.name, slug: r.slug, ownerPassword: r.ownerPassword,
          totalTables: r.totalTables, isActive: r.isActive, sortOrder: i, createdAt: r.createdAt,
        );
      }
    });

    // Batch update supabase
    try {
      for (final r in _restaurants) {
        await SupabaseService.client.from('restaurants').update({'sort_order': r.sortOrder}).eq('id', r.id);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sort order updated'), backgroundColor: AppColors.lime, behavior: SnackBarBehavior.floating));
    } catch (_) {}
  }

  Future<void> _updateSubscription(BuildContext context, Restaurant r) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: r.subscriptionEnd ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.lime,
              onPrimary: Color(0xFF050505),
              surface: AppColors.surface2,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    
    bool isTrial = r.isTrial;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: AppColors.surface1,
          title: const Text('Subscription Type', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: CheckboxListTile(
            title: const Text('Is this a Trial?', style: TextStyle(color: Colors.white, fontSize: 14)),
            value: isTrial,
            onChanged: (val) => setStateSB(() => isTrial = val ?? true),
            activeColor: AppColors.lime,
            checkColor: const Color(0xFF050505),
            contentPadding: EdgeInsets.zero,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Save', style: TextStyle(color: AppColors.lime)),
            ),
          ],
        ),
      ),
    );

    try {
      await SupabaseService.client.from('restaurants').update({
        'subscription_end': picked.toUtc().toIso8601String(),
        'is_trial': isTrial,
      }).eq('id', r.id);
      _loadAll(); // reload
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update subscription')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_restaurants.isEmpty) return const Center(child: Text('No Restaurants', style: TextStyle(color: AppColors.muted)));

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _restaurants.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final r = _restaurants[index];
        return Card(
          key: ValueKey(r.id),
          color: AppColors.surface1,
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('/${r.slug} • ${r.totalTables} tables', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Exp: ${r.subscriptionEnd != null ? r.subscriptionEnd!.toLocal().toString().split(' ')[0] : 'None'}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _updateSubscription(context, r),
                      child: const Text('Edit', style: TextStyle(color: AppColors.lime, fontSize: 11, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(width: 8),
                    Text(r.isTrial ? '(Trial)' : '(Sub)', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: r.isActive,
                  onChanged: (val) => _toggleActive(r, val),
                  activeColor: AppColors.lime,
                  activeTrackColor: AppColors.lime.withOpacity(0.3),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_red_eye, color: AppColors.lime),
                  tooltip: 'Impersonate',
                  onPressed: () => widget.onImpersonate(r),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.drag_handle, color: Colors.white24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL ORDERS TAB (Global view, Multi-select, Bulk Actions)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminOrdersTab extends StatefulWidget {
  const _AdminOrdersTab();
  @override
  State<_AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<_AdminOrdersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = []; // Keep as Map to easily read restaurants(name)
  Set<String> _selectedIds = {};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadAllOrders();
    _channel = SupabaseService.subscribeToAllOrders(
      'admin-all-orders-screen',
      (payload) {
        if (!mounted) return;
        _loadAllOrders();
      },
    );
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _loadAllOrders() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      
      final res = await SupabaseService.client
          .from('orders')
          .select('*, restaurants(name)')
          .gte('created_at', startOfDay)
          .order('created_at', ascending: false);
          
      setState(() {
        _orders = List<Map<String, dynamic>>.from(res as List);
        _selectedIds.clear();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkUpdate(String status) async {
    if (_selectedIds.isEmpty) return;
    try {
      for (final id in _selectedIds) {
        await SupabaseService.client.from('orders').update({'status': status}).eq('id', id);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${_selectedIds.length} orders'), backgroundColor: AppColors.lime, behavior: SnackBarBehavior.floating));
      _loadAllOrders();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.lime))
        else if (_orders.isEmpty)
          const Center(child: Text('No platform orders today', style: TextStyle(color: AppColors.muted)))
        else
          RefreshIndicator(
            onRefresh: _loadAllOrders,
            color: AppColors.lime,
            backgroundColor: AppColors.surface1,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // padding for FAB
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final o = _orders[index];
                final id = o['id'] as String;
                final status = o['status'] as String;
                final total = o['total'].toString();
                final restName = o['restaurants']?['name'] ?? 'Unknown';
                final table = o['table_number'];
                final isSelected = _selectedIds.contains(id);
                
                return Card(
                  color: isSelected ? AppColors.lime.withOpacity(0.1) : AppColors.surface1,
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), 
                    side: BorderSide(color: isSelected ? AppColors.lime : AppColors.border, width: isSelected ? 1 : 1)
                  ),
                  child: ListTile(
                    onTap: () => _toggleSelection(id),
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (v) => _toggleSelection(id),
                      activeColor: AppColors.lime,
                      checkColor: const Color(0xFF050505),
                    ),
                    title: Text('$restName • Table $table', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    subtitle: Text('Status: ${status.toUpperCase()} • ₹$total', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                );
              },
            ),
          ),

        // Bulk Actions Overlay
        if (_selectedIds.isNotEmpty)
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Text('${_selectedIds.length} Selected', style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold)),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: _bulkUpdate,
                    color: AppColors.surface2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFCA5A5), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Update Status', style: TextStyle(color: Color(0xFF7F1D1D), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'preparing', child: Text('Mark Preparing', style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'ready', child: Text('Mark Ready', style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'completed', child: Text('Mark Completed', style: TextStyle(color: Colors.white))),
                    ],
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
