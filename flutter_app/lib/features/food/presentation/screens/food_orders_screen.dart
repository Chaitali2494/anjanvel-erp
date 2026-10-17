import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/food_orders_state_provider.dart';

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
  {'id': '1', 'order_number': 'FO-001', 'status': 'PENDING',   'total_amount': 850.0,  'meal_type': 'BREAKFAST', 'ordered_at': DateTime.now().toIso8601String(),                                           'guests': {'full_name': 'Priya Sharma'},  'bookings': {'booking_number': 'BK-001', 'room_number': '101'}},
  {'id': '2', 'order_number': 'FO-002', 'status': 'PREPARING', 'total_amount': 1200.0, 'meal_type': 'LUNCH',     'ordered_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'guests': {'full_name': 'Rajesh Kumar'}, 'bookings': {'booking_number': 'BK-002', 'room_number': '102'}},
  {'id': '3', 'order_number': 'FO-003', 'status': 'SERVED',    'total_amount': 650.0,  'meal_type': 'DINNER',    'ordered_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'guests': {'full_name': 'Anita Patel'},  'bookings': {'booking_number': 'BK-003', 'room_number': '201'}},
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
    final orders = ref.watch(foodOrdersStateProvider);
    final menuAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Food Orders'),
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
        actions: [
          // Demo: simulate a guest QR order so you can test without a phone
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Simulate Guest Order',
            onPressed: () => _simulateGuestOrder(),
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
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
          Builder(builder: (ctx) {
              // Stats
              final pending = orders.where((o) => o['status'] == 'PENDING').length;
              final preparing = orders.where((o) => o['status'] == 'PREPARING').length;
              final served = orders.where((o) => o['status'] == 'SERVED').length;
              final revenue = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));

              final filtered = _statusFilter == null
                  ? orders
                  : orders.where((o) => o['status'] == _statusFilter).toList();

              // Find NEW guest QR orders (placed within last 30 minutes)
              final now = DateTime.now();
              final newGuestOrders = orders.where((o) {
                if (o['source'] != 'GUEST_QR') return false;
                final at = o['ordered_at'] as String?;
                if (at == null) return false;
                final dt = DateTime.tryParse(at);
                if (dt == null) return false;
                return now.difference(dt).inMinutes < 30 && o['status'] == 'PENDING';
              }).toList();

              return Column(
                children: [
                  // ── NEW guest order alert ──
                  if (newGuestOrders.isNotEmpty)
                    _GuestOrderAlert(orders: newGuestOrders),
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
            }),

          // ── Menu Tab ──
          menuAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19))),
            error: (e, _) {
              // Show demo menu even on error
              final categories = _demoMenu.map((m) => m['category'] as String? ?? 'Other').toSet().toList()..sort();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: categories.map((cat) {
                  final items = _demoMenu.where((m) => m['category'] == cat).toList();
                  return _MenuCategory(category: cat, items: items);
                }).toList(),
              );
            },
            data: (menu) {
              final _menu = menu.isEmpty ? _demoMenu : menu;
              final categories = _menu.map((m) => m['category'] as String? ?? 'Other').toSet().toList()..sort();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: categories.map((cat) {
                  final items = _menu.where((m) => m['category'] == cat).toList();
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
    } catch (_) {}
    // Always update local state so billing + room detail stay in sync
    ref.read(foodOrdersStateProvider.notifier).updateStatus(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated to $status'), backgroundColor: AppTheme.success),
      );
    }
  }

  /// Adds a fake guest QR order — useful for demo when no second device is at hand.
  void _simulateGuestOrder() {
    final rooms = ['101', '102', '201', '202', '301', '302'];
    final room  = rooms[DateTime.now().second % rooms.length];
    final items = [
      {'name': 'Veg Thali',    'qty': 2,  'price': 350.0},
      {'name': 'Masala Chai',  'qty': 2,  'price': 40.0},
    ];
    final total = items.fold<double>(
        0, (s, i) => s + (i['qty'] as int) * (i['price'] as double));
    final order = {
      'id'            : 'GSIM-${DateTime.now().millisecondsSinceEpoch}',
      'order_number'  : 'FO-G${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
      'status'        : 'PENDING',
      'source'        : 'GUEST_QR',
      'total_amount'  : total,
      'meal_type'     : 'LUNCH',
      'ordered_at'    : DateTime.now().toIso8601String(),
      'guests'        : {'full_name': 'Room $room (Guest)'},
      'bookings'      : {'booking_number': 'GUEST', 'room_number': room},
      'items'         : items,
    };
    ref.read(foodOrdersStateProvider.notifier).addOrder(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 Simulated guest order for Room $room'),
        backgroundColor: const Color(0xFFE64A19),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNewOrderSheet() {
    final roomCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();
    String mealType = 'BREAKFAST';
    final Map<String, int> cart = {}; // menuItem name → qty
    int _orderCounter = DateTime.now().millisecondsSinceEpoch;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final total = cart.entries.fold<double>(0, (s, e) {
            final item = _demoMenu.firstWhere((m) => m['name'] == e.key, orElse: () => {});
            return s + ((item['price'] as num?)?.toDouble() ?? 0) * e.value;
          });

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    const Icon(Icons.restaurant_menu_outlined, color: Color(0xFFE64A19)),
                    const SizedBox(width: 10),
                    const Text('Create Food Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 12),

                  // Room number
                  const Text('Room Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roomCtrl,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 101, T01',
                      prefixIcon: Icon(Icons.bed_outlined, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meal type
                  const Text('Meal Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Row(children: ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'].map((m) {
                    final sel = mealType == m;
                    return Expanded(child: GestureDetector(
                      onTap: () => setModal(() => mealType = m),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFE64A19) : const Color(0xFFE64A19).withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE64A19).withOpacity(sel ? 1 : 0.3)),
                        ),
                        child: Text(m[0] + m.substring(1).toLowerCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: sel ? Colors.white : const Color(0xFFE64A19))),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 14),

                  // Menu items
                  const Text('Select Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  ..._demoMenu.map((item) {
                    final name  = item['name'] as String;
                    final price = (item['price'] as num).toDouble();
                    final qty   = cart[name] ?? 0;
                    final isVeg = item['is_veg'] as bool? ?? true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: qty > 0 ? const Color(0xFFE64A19).withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: qty > 0 ? const Color(0xFFE64A19).withOpacity(0.4) : Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Center(child: Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(color: isVeg ? Colors.green : Colors.red, shape: BoxShape.circle),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
                        Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(width: 8),
                        if (qty == 0)
                          GestureDetector(
                            onTap: () => setModal(() => cart[name] = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE64A19),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          )
                        else
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            GestureDetector(
                              onTap: () => setModal(() { if (qty > 1) cart[name] = qty - 1; else cart.remove(name); }),
                              child: const Icon(Icons.remove_circle_outline, color: Color(0xFFE64A19), size: 22),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                            ),
                            GestureDetector(
                              onTap: () => setModal(() => cart[name] = qty + 1),
                              child: const Icon(Icons.add_circle_outline, color: Color(0xFFE64A19), size: 22),
                            ),
                          ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 10),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Special instructions (optional)',
                      prefixIcon: Icon(Icons.note_outlined, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Place Order button
                  ElevatedButton(
                    onPressed: (cart.isEmpty || roomCtrl.text.trim().isEmpty) ? null : () {
                      if (roomCtrl.text.trim().isEmpty) return;
                      // Build order items string
                      final newOrder = {
                        'id': '${++_orderCounter}',
                        'order_number': 'FO-${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}',
                        'status': 'PENDING',
                        'total_amount': total,
                        'meal_type': mealType,
                        'ordered_at': DateTime.now().toIso8601String(),
                        'notes': notesCtrl.text.trim(),
                        'guests': {'full_name': 'Room ${roomCtrl.text.trim()}'},
                        'bookings': {'booking_number': 'WALK-IN', 'room_number': roomCtrl.text.trim()},
                        'items': cart.entries.map((e) {
                          final item = _demoMenu.firstWhere((m) => m['name'] == e.key, orElse: () => {});
                          return {
                            'name': e.key,
                            'qty': e.value,
                            'price': (item['price'] as num?)?.toDouble() ?? 0.0,
                          };
                        }).toList(),
                      };
                      ref.read(foodOrdersStateProvider.notifier).addOrder(newOrder);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order placed for Room ${roomCtrl.text.trim()} — ₹${total.toStringAsFixed(0)}'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE64A19),
                      minimumSize: const Size(double.infinity, 50),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      cart.isEmpty ? 'Select items to place order' : 'Place Order  •  ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    String time = '';
    String date = '';
    if (orderedAt != null) {
      final dt = DateTime.tryParse(orderedAt);
      if (dt != null) {
        time = DateFormat('hh:mm a').format(dt);
        date = DateFormat('dd MMM').format(dt);
      }
    }

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
                Text(mealType, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                const SizedBox(width: 8),
                if (date.isNotEmpty) Text(date, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                if (time.isNotEmpty) ...[
                  const Text(' ', style: TextStyle(fontSize: 12)),
                  Text(time, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                ],
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
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  if (status == 'PENDING') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'PREPARING'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0277BD),
                          minimumSize: const Size(0, 38),
                        ),
                        child: const Text('Start Prep'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (status == 'PREPARING') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'READY'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00838F),
                          minimumSize: const Size(0, 38),
                        ),
                        child: const Text('Mark Ready'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (status == 'READY') ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onStatusChange(order['id'] as String, 'SERVED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(0, 38),
                        ),
                        child: const Text('Mark Served'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onStatusChange(order['id'] as String, 'CANCELLED'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        minimumSize: const Size(0, 38),
                      ),
                      child: const Text('Cancel'),
                    ),
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

// ── Guest QR Order Alert Banner ───────────────────────────────────────────────

class _GuestOrderAlert extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _GuestOrderAlert({required this.orders});

  @override
  Widget build(BuildContext context) {
    final rooms = orders.map((o) =>
        ((o['bookings'] as Map<String, dynamic>?)?['room_number'] as String? ?? '?'))
        .toSet().join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE64A19).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE64A19).withOpacity(0.4)),
      ),
      child: Row(children: [
        // Pulsing dot
        _PulsingDot(color: const Color(0xFFE64A19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${orders.length} NEW order${orders.length > 1 ? 's' : ''} via Guest QR',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE64A19)),
          ),
          Text('Room${rooms.contains(',') ? 's' : ''} $rooms · Waiting for kitchen',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE64A19),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('VIEW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scale = Tween(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
