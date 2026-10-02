import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final foodOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    return await client
        .from('food_orders')
        .select('*, guests(full_name), bookings(booking_number, room_number)')
        .gte('ordered_at', today)
        .order('ordered_at', ascending: false);
  } catch (_) {
    return _demoOrders;
  }
});

final menuItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('menu_items').select().eq('is_available', true).order('category');
  } catch (_) {
    return _demoMenu;
  }
});

// ── Demo Data ─────────────────────────────────────────────────────────────────

final _demoOrders = [
  {'id': '1', 'order_number': 'FO-001', 'status': 'PENDING', 'total_amount': 850.0, 'meal_type': 'BREAKFAST', 'ordered_at': DateTime.now().toIso8601String(), 'guests': {'full_name': 'Rahul Sharma'}, 'bookings': {'booking_number': 'BK-001', 'room_number': 'R01'}},
  {'id': '2', 'order_number': 'FO-002', 'status': 'PREPARING', 'total_amount': 1200.0, 'meal_type': 'LUNCH', 'ordered_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'guests': {'full_name': 'Priya Patel'}, 'bookings': {'booking_number': 'BK-002', 'room_number': 'T01'}},
  {'id': '3', 'order_number': 'FO-003', 'status': 'SERVED', 'total_amount': 650.0, 'meal_type': 'DINNER', 'ordered_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'guests': {'full_name': 'Amit Desai'}, 'bookings': {'booking_number': 'BK-003', 'room_number': 'D01'}},
];

final _demoMenu = [
  {'id': '1', 'name': 'Veg Thali', 'category': 'Main Course', 'price': 350.0, 'meal_type': 'LUNCH', 'is_available': true, 'is_veg': true},
  {'id': '2', 'name': 'Non-Veg Thali', 'category': 'Main Course', 'price': 450.0, 'meal_type': 'LUNCH', 'is_available': true, 'is_veg': false},
  {'id': '3', 'name': 'Breakfast Plate', 'category': 'Breakfast', 'price': 250.0, 'meal_type': 'BREAKFAST', 'is_available': true, 'is_veg': true},
  {'id': '4', 'name': 'Poha', 'category': 'Breakfast', 'price': 120.0, 'meal_type': 'BREAKFAST', 'is_available': true, 'is_veg': true},
  {'id': '5', 'name': 'Masala Chai', 'category': 'Beverages', 'price': 40.0, 'meal_type': 'ALL', 'is_available': true, 'is_veg': true},
  {'id': '6', 'name': 'Fresh Juice', 'category': 'Beverages', 'price': 80.0, 'meal_type': 'ALL', 'is_available': true, 'is_veg': true},
  {'id': '7', 'name': 'BBQ Chicken', 'category': 'Snacks', 'price': 380.0, 'meal_type': 'DINNER', 'is_available': true, 'is_veg': false},
  {'id': '8', 'name': 'Veg Starter', 'category': 'Snacks', 'price': 220.0, 'meal_type': 'DINNER', 'is_available': true, 'is_veg': true},
];

const _statusConfig = {
  'PENDING':   {'color': Color(0xFFFFB300), 'label': 'Pending',   'icon': Icons.hourglass_empty_rounded},
  'PREPARING': {'color': Color(0xFF0277BD), 'label': 'Preparing', 'icon': Icons.restaurant_outlined},
  'READY':     {'color': Color(0xFF00838F), 'label': 'Ready',     'icon': Icons.done_all_rounded},
  'SERVED':    {'color': Color(0xFF2E7D32), 'label': 'Served',    'icon': Icons.check_circle_outline},
  'CANCELLED': {'color': Color(0xFFE53935), 'label': 'Cancelled', 'icon': Icons.cancel_outlined},
};

// ── Screen ────────────────────────────────────────────────────────────────────

class FoodOrdersScreen extends ConsumerStatefulWidget {
  const FoodOrdersScreen({super.key});
  @override
  ConsumerState<FoodOrdersScreen> createState() => _FoodOrdersScreenState();
}

class _FoodOrdersScreenState extends ConsumerState<FoodOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(foodOrdersProvider);
    final menuAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Food Orders'),
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(foodOrdersProvider);
              ref.invalidate(menuItemsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Orders', icon: Icon(Icons.receipt_long_outlined, size: 18)),
            Tab(text: 'Menu', icon: Icon(Icons.menu_book_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Orders Tab ──
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19))),
            error: (e, _) => const EmptyState(title: 'No Orders Yet', subtitle: 'Food orders will appear here', icon: Icons.restaurant_menu_outlined),
            data: (orders) {
              // Stats
              final pending = orders.where((o) => o['status'] == 'PENDING').length;
              final preparing = orders.where((o) => o['status'] == 'PREPARING').length;
              final served = orders.where((o) => o['status'] == 'SERVED').length;
              final revenue = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));

              final filtered = _statusFilter == null
                  ? orders
                  : orders.where((o) => o['status'] == _statusFilter).toList();

              return Column(
                children: [
                  // Stats
                  _OrderStats(pending: pending, preparing: preparing, served: served, revenue: revenue),
                  // Status filter
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _StatusChip('All', null, _statusFilter, (v) => setState(() => _statusFilter = v)),
                        ..._statusConfig.entries.map((e) => _StatusChip(
                          e.value['label'] as String, e.key, _statusFilter,
                          (v) => setState(() => _statusFilter = v),
                          color: e.value['color'] as Color,
                        )),
                      ],
                    ),
                  ),
                  // Orders list
                  Expanded(
                    child: filtered.isEmpty
                        ? const EmptyState(title: 'No Orders', subtitle: 'No orders match this filter', icon: Icons.receipt_long_outlined)
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(
                              order: filtered[i],
                              onStatusChange: (id, status) => _updateOrderStatus(id, status),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),

          // ── Menu Tab ──
          menuAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19))),
            error: (e, _) => const EmptyState(title: 'Menu Unavailable', subtitle: 'Menu items will appear here', icon: Icons.menu_book_outlined),
            data: (menu) {
              final categories = menu.map((m) => m['category'] as String? ?? 'Other').toSet().toList()..sort();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: categories.map((cat) {
                  final items = menu.where((m) => m['category'] == cat).toList();
                  return _MenuCategory(category: cat, items: items);
                }).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewOrderSheet(),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
        backgroundColor: const Color(0xFFE64A19),
      ),
    );
  }

  Future<void> _updateOrderStatus(String id, String status) async {
    try {
      await ref.read(supabaseClientProvider).from('food_orders').update({'status': status, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
      ref.invalidate(foodOrdersProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order updated to $status'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _showNewOrderSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Food Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Food orders are placed by guests through their room service. Orders will appear here automatically.',
                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE64A19), minimumSize: const Size(double.infinity, 48)),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Stats ───────────────────────────────────────────────────────────────

class _OrderStats extends StatelessWidget {
  final int pending, preparing, served;
  final double revenue;
  const _OrderStats({required this.pending, required this.preparing, required this.served, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE64A19), Color(0xFFFF7043)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        children: [
          _S('Pending', '$pending', Icons.hourglass_empty_rounded),
          _VD(), _S('Preparing', '$preparing', Icons.restaurant_outlined),
          _VD(), _S('Served', '$served', Icons.check_circle_outline),
          _VD(), _S('Revenue', '₹${revenue.toStringAsFixed(0)}', Icons.currency_rupee),
        ],
      ),
    );
  }
}

class _S extends StatelessWidget {
  final String l, v; final IconData i;
  const _S(this.l, this.v, this.i);
  @override Widget build(_) => Expanded(child: Column(children: [
    Icon(i, color: Colors.white70, size: 16), const SizedBox(height: 4),
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]));
}
class _VD extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 36, color: Colors.white24);
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final String? value, selected;
  final ValueChanged<String?> onTap;
  final Color color;
  const _StatusChip(this.label, this.value, this.selected, this.onTap, {this.color = const Color(0xFFE64A19)});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Order Card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String, String) onStatusChange;
  const _OrderCard({required this.order, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'PENDING';
    final cfg = _statusConfig[status] ?? _statusConfig['PENDING']!;
    final color = cfg['color'] as Color;
    final icon = cfg['icon'] as IconData;
    final guest = order['guests'] as Map<String, dynamic>? ?? {};
    final booking = order['bookings'] as Map<String, dynamic>? ?? {};
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final mealType = order['meal_type'] as String? ?? '';
    final orderedAt = order['ordered_at'] as String?;
    final time = orderedAt != null
        ? DateFormat('hh:mm a').format(DateTime.parse(orderedAt))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(order['order_number'] as String? ?? '', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Text(mealType, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                const SizedBox(width: 8),
                Text(time, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guest['full_name'] as String? ?? 'Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${booking['booking_number'] ?? ''} • Room ${booking['room_number'] ?? ''}',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    StatusBadge(label: status, color: color),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          if (status != 'SERVED' && status != 'CANCELLED')
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  if (status == 'PENDING')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'PREPARING'),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0277BD)),
                        child: const Text('Start Preparing'),
                      ),
                    ),
                  if (status == 'PREPARING') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'READY'),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00838F)),
                        child: const Text('Mark Ready'),
                      ),
                    ),
                  ],
                  if (status == 'READY') ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'SERVED'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        child: const Text('Mark Served'),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => onStatusChange(order['id'] as String, 'CANCELLED'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Menu Category ─────────────────────────────────────────────────────────────

class _MenuCategory extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  const _MenuCategory({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE64A19))),
        ),
        ...items.map((item) => _MenuItem(item: item)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MenuItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isVeg = item['is_veg'] as bool? ?? true;
    final price = (item['price'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: isVeg ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item['name'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          Text('₹${price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE64A19))),
        ],
      ),
    );
  }
}
