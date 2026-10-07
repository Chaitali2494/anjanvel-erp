import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../shop/data/shop_room_charges_provider.dart';
import '../../../shop/data/shop_cart_provider.dart';

// ── Session-level sales state ──────────────────────────────────────────────────

class _Sale {
  final String product, category;
  final double price;
  final int qty;
  final DateTime time;
  _Sale({required this.product, required this.category, required this.price, required this.qty})
      : time = DateTime.now();
  double get total => price * qty;
}

List<_Sale> _sessionSales = [];

// ── Product catalogue ──────────────────────────────────────────────────────────

const _kCategories = [
  _Cat('Fruits',     '🍋', Color(0xFFFF8F00), 'Fresh seasonal fruits from the farm'),
  _Cat('Vegetables', '🥬', Color(0xFF2E7D32), 'Organic farm-fresh vegetables'),
  _Cat('Rice & Grains','🌾', Color(0xFF795548), 'Indrayani rice & local grains'),
  _Cat('Snacks',     '🥨', Color(0xFFE64A19), 'Kurdai papadi & traditional snacks'),
  _Cat('Artifacts',  '🏺', Color(0xFF6A1B9A), 'Handcrafted souvenirs & Warli art'),
];

const _kProducts = [
  // Fruits
  _Product('Alphonso Mango',  '🥭', 'Fruits',      80.0,  'per kg',  28),
  _Product('Guava',           '🍐', 'Fruits',      40.0,  'per kg',  45),
  _Product('Banana (dozen)',  '🍌', 'Fruits',      35.0,  'per doz', 60),
  _Product('Papaya',          '🍈', 'Fruits',      50.0,  'per kg',  18),
  // Vegetables
  _Product('Drumstick',       '🥦', 'Vegetables',  30.0,  'per bunch',20),
  _Product('Brinjal',         '🍆', 'Vegetables',  25.0,  'per kg',  35),
  _Product('Tomatoes',        '🍅', 'Vegetables',  30.0,  'per kg',  50),
  _Product('Bitter Gourd',    '🥒', 'Vegetables',  35.0,  'per kg',  22),
  // Rice & Grains
  _Product('Indrayani Rice',  '🌾', 'Rice & Grains',85.0, 'per kg',  40),
  _Product('Jowar Flour',     '🌾', 'Rice & Grains',45.0, 'per kg',  30),
  _Product('Nachni Flour',    '🌾', 'Rice & Grains',55.0, 'per kg',  25),
  // Snacks
  _Product('Kurdai Papadi',   '🥨', 'Snacks',      120.0, 'per 250g',15),
  _Product('Sabudana Papad',  '🫓', 'Snacks',       80.0, 'per 200g',20),
  _Product('Chivda',          '🍿', 'Snacks',       60.0, 'per 200g',30),
  _Product('Shengdana Ladoo', '🟤', 'Snacks',       90.0, 'per 200g',12),
  // Artifacts
  _Product('Warli Art Frame', '🖼️', 'Artifacts',  350.0, 'each',     8),
  _Product('Bamboo Basket',   '🧺', 'Artifacts',  180.0, 'each',    10),
  _Product('Clay Pot',        '🏺', 'Artifacts',  150.0, 'each',     6),
  _Product('Jute Bag',        '👜', 'Artifacts',  120.0, 'each',    14),
];

// ── Provider ───────────────────────────────────────────────────────────────────

class ShopNotifier extends StateNotifier<List<_Sale>> {
  ShopNotifier() : super(_sessionSales);

  void addSale(_Sale sale) {
    _sessionSales = [sale, ..._sessionSales];
    state = List.from(_sessionSales);
  }

  double get todaySales => state.fold(0.0, (s, e) => s + e.total);
  int get todayOrders => state.length;
}

final shopNotifierProvider = StateNotifierProvider<ShopNotifier, List<_Sale>>((ref) => ShopNotifier());

// ── Screen ─────────────────────────────────────────────────────────────────────

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales       = ref.watch(shopNotifierProvider);
    final notifier    = ref.read(shopNotifierProvider.notifier);
    final todaySales  = notifier.todaySales;
    final todayOrders = notifier.todayOrders;
    final cartItems   = ref.watch(shopCartProvider);
    final cartCount   = ref.read(shopCartProvider.notifier).itemCount;

    // Low stock products (qty < 15)
    final lowStock = _kProducts.where((p) => p.stock < 15).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [

          // ── Hero header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4E342E), Color(0xFF795548), Color(0xFFBCAAA4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: Text('🏪', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Anjanvel Agro Tourism',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('SHG Shop',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.go('/role-selection'),
                      icon: const Icon(Icons.home_rounded, color: Colors.white),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Self Help Group — Maharashtra Products',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text("Today's Shop Overview",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // ── Sales stats strip ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              transform: Matrix4.translationValues(0, -14, 0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                _StatTile('Today Sales', '₹${todaySales.toStringAsFixed(0)}', const Color(0xFF558B2F)),
                _Divider(),
                _StatTile('Orders',      '$todayOrders',                        const Color(0xFF1565C0)),
                _Divider(),
                _StatTile('Products',    '${_kProducts.length}',               const Color(0xFF795548)),
                _Divider(),
                _StatTile('Low Stock',   '${lowStock.length}',                 lowStock.isNotEmpty ? AppTheme.error : AppTheme.success),
              ]),
            ),
          ),

          // ── Low stock alert ─────────────────────────────────────────────────
          if (lowStock.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.error.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Low stock: ${lowStock.map((p) => p.name).join(' · ')}',
                      style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),
              ),
            ),

          // ── Quick actions ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(children: [
                _QABtn('New Sale',    Icons.point_of_sale_rounded,   const Color(0xFF558B2F), () => _showSaleSheet(context, ref)),
                const SizedBox(width: 10),
                _QABtn('Products',   Icons.storefront_rounded,       const Color(0xFF795548), () => context.push('/shop')),
                const SizedBox(width: 10),
                _QABtn('Cart',       Icons.shopping_cart_outlined,   const Color(0xFF1565C0), () => context.push('/shop/cart')),
                const SizedBox(width: 10),
                _QABtn('Checkout',   Icons.payment_rounded,          const Color(0xFFE64A19), () => context.push('/shop/checkout')),
              ]),
            ),
          ),

          // ── Categories ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final cat = _kCategories[i];
                        final count = _kProducts.where((p) => p.category == cat.name).length;
                        return _CategoryCard(cat: cat, count: count);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Featured products ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('All Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                  TextButton(
                    onPressed: () => context.push('/shop'),
                    child: const Text('Browse', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Product list grouped by category
          ..._kCategories.map((cat) {
            final catProducts = _kProducts.where((p) => p.category == cat.name).toList();
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(color: cat.color.withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      // Category header
                      Container(
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cat.color)),
                          const Spacer(),
                          Text('${catProducts.length} items', style: TextStyle(fontSize: 11, color: cat.color.withOpacity(0.7))),
                        ]),
                      ),
                      // Product rows
                      ...catProducts.map((p) => _ProductRow(product: p, catColor: cat.color, onSell: () {})),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Today's sales log ───────────────────────────────────────────────
          if (sales.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's Sales Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: Column(
                        children: sales.take(10).map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(_kProducts.firstWhere((p) => p.name == s.product, orElse: () => const _Product('', '🛍️', '', 0, '', 0)).emoji, style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.product, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                              Text('${s.qty} × ₹${s.price.toStringAsFixed(0)}  •  ${_timeLabel(s.time)}', style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                            ])),
                            Text('₹${s.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF558B2F))),
                          ]),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton.extended(
            onPressed: () => context.push('/shop/cart'),
            backgroundColor: const Color(0xFF1565C0),
            icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
            label: Text(
              cartCount > 0 ? 'Cart  •  ₹${ref.read(shopCartProvider.notifier).subtotal.toStringAsFixed(0)}' : 'Cart',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (cartCount > 0)
            Positioned(
              top: -6, right: -6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showSaleSheet(BuildContext context, WidgetRef ref, {_Product? product}) {
    _Product? selected = product;
    int qty = 1;
    bool chargeToRoom = false;
    final roomCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF558B2F), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Record Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary)),
                ]),
                const SizedBox(height: 20),

                // Product picker
                const Text('Product *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<_Product>(
                  value: selected,
                  hint: const Text('Select product'),
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront_rounded, size: 18)),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  dropdownColor: AppTheme.surface,
                  items: _kProducts.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.emoji} ${p.name}  ₹${p.price.toStringAsFixed(0)}/${p.unit}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setModal(() => selected = v),
                ),
                const SizedBox(height: 14),

                // Quantity
                const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton(
                    onPressed: qty > 1 ? () => setModal(() => qty--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: const Color(0xFF558B2F),
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text('$qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    onPressed: () => setModal(() => qty++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: const Color(0xFF558B2F),
                  ),
                  if (selected != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF558B2F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Total: ₹${(selected!.price * qty).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF558B2F)),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Charge to Room toggle ──────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: chargeToRoom ? const Color(0xFF1565C0).withOpacity(0.06) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chargeToRoom ? const Color(0xFF1565C0).withOpacity(0.4) : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: chargeToRoom,
                        onChanged: (v) => setModal(() => chargeToRoom = v),
                        activeColor: const Color(0xFF1565C0),
                        title: const Text('Charge to Guest Room', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                        subtitle: const Text('Add this to the room bill', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                        secondary: Icon(Icons.hotel_rounded, color: chargeToRoom ? const Color(0xFF1565C0) : Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      if (chargeToRoom) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: TextField(
                            controller: roomCtrl,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Room Number *',
                              labelStyle: const TextStyle(color: AppTheme.textPrimary),
                              hintText: 'e.g. 101, 205',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.bed_outlined, size: 18, color: Color(0xFF1565C0)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selected == null) return;
                      if (chargeToRoom && roomCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a room number'), backgroundColor: AppTheme.error),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      // Record the shop sale
                      ref.read(shopNotifierProvider.notifier).addSale(
                        _Sale(product: selected!.name, category: selected!.category, price: selected!.price, qty: qty),
                      );
                      // If charging to room, also add to room charges
                      if (chargeToRoom) {
                        ref.read(shopRoomChargesProvider.notifier).addCharge(
                          ShopRoomCharge(
                            product: selected!.name,
                            roomNumber: roomCtrl.text.trim(),
                            price: selected!.price,
                            qty: qty,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('₹${(selected!.price * qty).toStringAsFixed(0)} charged to Room ${roomCtrl.text.trim()}'),
                            backgroundColor: const Color(0xFF1565C0),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sale recorded: ${selected!.name} × $qty'),
                            backgroundColor: const Color(0xFF558B2F),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF558B2F), minimumSize: const Size(double.infinity, 50)),
                    child: Text(
                      chargeToRoom ? 'Charge to Room & Record Sale' : 'Record Sale',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);
  @override Widget build(_) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textPrimary), textAlign: TextAlign.center),
    ]),
  ));
}

class _Divider extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 36, color: Colors.grey.shade200);
}

class _QABtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _QABtn(this.label, this.icon, this.color, this.onTap);
  @override Widget build(_) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 6)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      ]),
    ),
  ));
}

class _CategoryCard extends StatelessWidget {
  final _Cat cat;
  final int count;
  const _CategoryCard({required this.cat, required this.count});
  @override
  Widget build(BuildContext context) => Container(
    width: 100,
    decoration: BoxDecoration(
      color: cat.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      border: Border.all(color: cat.color.withOpacity(0.3)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(cat.emoji, style: const TextStyle(fontSize: 26)),
      const SizedBox(height: 4),
      Text(cat.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cat.color), textAlign: TextAlign.center),
      Text('$count items', style: TextStyle(fontSize: 9, color: cat.color.withOpacity(0.7))),
    ]),
  );
}

class _ProductRow extends ConsumerWidget {
  final _Product product;
  final Color catColor;
  final VoidCallback onSell;
  const _ProductRow({required this.product, required this.catColor, required this.onSell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.stock < 15;
    final cartItems = ref.watch(shopCartProvider);
    final inCart = cartItems.firstWhere((c) => c.name == product.name, orElse: () => CartItem(name: '', emoji: '', category: '', unit: '', price: 0));
    final qtyInCart = inCart.name.isNotEmpty ? inCart.qty : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Text(product.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
          Row(children: [
            Text('₹${product.price.toStringAsFixed(0)}/${product.unit}', style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLow ? AppTheme.error.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isLow ? 'Low: ${product.stock}' : 'Stock: ${product.stock}',
                style: TextStyle(fontSize: 9, color: isLow ? AppTheme.error : AppTheme.success, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ])),
        // Add to Cart controls
        if (qtyInCart == 0)
          GestureDetector(
            onTap: () {
              ref.read(shopCartProvider.notifier).addItem(
                name: product.name,
                emoji: product.emoji,
                category: product.category,
                unit: product.unit,
                price: product.price,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} added to cart'),
                  backgroundColor: const Color(0xFF558B2F),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF558B2F), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          )
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => ref.read(shopCartProvider.notifier).decrement(product.name),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.remove_rounded, size: 14, color: AppTheme.error),
              ),
            ),
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text('$qtyInCart', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
            ),
            GestureDetector(
              onTap: () => ref.read(shopCartProvider.notifier).increment(product.name),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF558B2F)),
              ),
            ),
          ]),
      ]),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class _Cat {
  final String name, emoji, description;
  final Color color;
  const _Cat(this.name, this.emoji, this.color, this.description);
}

class _Product {
  final String name, emoji, category, unit;
  final double price;
  final int stock;
  const _Product(this.name, this.emoji, this.category, this.price, this.unit, this.stock);
}
