import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final inventoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('inventory_items').select().order('category').order('name');
  } catch (_) {
    return _demoInventory;
  }
});

// ── Demo Data ─────────────────────────────────────────────────────────────────

final _demoInventory = [
  {'id': '1', 'name': 'Rice', 'category': 'Kitchen', 'unit': 'kg', 'quantity': 45.0, 'min_quantity': 20.0, 'unit_price': 60.0, 'supplier': 'Local Mandi'},
  {'id': '2', 'name': 'Cooking Oil', 'category': 'Kitchen', 'unit': 'L', 'quantity': 8.0, 'min_quantity': 10.0, 'unit_price': 140.0, 'supplier': 'Wholesale Store'},
  {'id': '3', 'name': 'Chicken', 'category': 'Kitchen', 'unit': 'kg', 'quantity': 5.0, 'min_quantity': 10.0, 'unit_price': 280.0, 'supplier': 'Meat Supplier'},
  {'id': '4', 'name': 'Vegetables (Assorted)', 'category': 'Kitchen', 'unit': 'kg', 'quantity': 30.0, 'min_quantity': 15.0, 'unit_price': 50.0, 'supplier': 'Farm Fresh'},
  {'id': '5', 'name': 'Bed Sheets', 'category': 'Housekeeping', 'unit': 'pcs', 'quantity': 25.0, 'min_quantity': 20.0, 'unit_price': 400.0, 'supplier': 'Textile Mart'},
  {'id': '6', 'name': 'Towels', 'category': 'Housekeeping', 'unit': 'pcs', 'quantity': 12.0, 'min_quantity': 20.0, 'unit_price': 200.0, 'supplier': 'Textile Mart'},
  {'id': '7', 'name': 'Soap (Bar)', 'category': 'Housekeeping', 'unit': 'pcs', 'quantity': 50.0, 'min_quantity': 30.0, 'unit_price': 25.0, 'supplier': 'FMCG Distributor'},
  {'id': '8', 'name': 'Shampoo (Sachet)', 'category': 'Housekeeping', 'unit': 'pcs', 'quantity': 80.0, 'min_quantity': 50.0, 'unit_price': 5.0, 'supplier': 'FMCG Distributor'},
  {'id': '9', 'name': 'Firewood', 'category': 'Activities', 'unit': 'bundle', 'quantity': 4.0, 'min_quantity': 10.0, 'unit_price': 150.0, 'supplier': 'Local Supplier'},
  {'id': '10', 'name': 'Safety Harness', 'category': 'Activities', 'unit': 'pcs', 'quantity': 8.0, 'min_quantity': 5.0, 'unit_price': 2500.0, 'supplier': 'Sports Equipment'},
  {'id': '11', 'name': 'Mineral Water (Bottle)', 'category': 'F&B', 'unit': 'pcs', 'quantity': 120.0, 'min_quantity': 50.0, 'unit_price': 20.0, 'supplier': 'Beverage Distributor'},
  {'id': '12', 'name': 'Soft Drinks (Can)', 'category': 'F&B', 'unit': 'pcs', 'quantity': 15.0, 'min_quantity': 24.0, 'unit_price': 45.0, 'supplier': 'Beverage Distributor'},
];

const _categoryConfig = {
  'Kitchen':      {'color': Color(0xFFE64A19), 'icon': Icons.restaurant_outlined},
  'Housekeeping': {'color': Color(0xFF2E7D32), 'icon': Icons.cleaning_services_outlined},
  'Activities':   {'color': Color(0xFF00838F), 'icon': Icons.hiking_outlined},
  'F&B':          {'color': Color(0xFF6A1B9A), 'icon': Icons.local_bar_outlined},
  'Maintenance':  {'color': Color(0xFF37474F), 'icon': Icons.build_outlined},
};

// ── Screen ────────────────────────────────────────────────────────────────────

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});
  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String? _categoryFilter;
  bool _lowStockOnly = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_lowStockOnly ? Icons.warning_rounded : Icons.warning_outlined,
                color: _lowStockOnly ? Colors.orangeAccent : Colors.white),
            tooltip: 'Low stock only',
            onPressed: () => setState(() => _lowStockOnly = !_lowStockOnly),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(inventoryProvider),
          ),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00796B))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final lowStock = items.where((i) {
            final qty = (i['quantity'] as num?)?.toDouble() ?? 0;
            final min = (i['min_quantity'] as num?)?.toDouble() ?? 0;
            return qty <= min;
          }).length;

          // Apply filters
          var filtered = items.where((i) {
            final matchCat = _categoryFilter == null || i['category'] == _categoryFilter;
            final matchSearch = _search.isEmpty ||
                (i['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
            final matchLow = !_lowStockOnly || (() {
              final qty = (i['quantity'] as num?)?.toDouble() ?? 0;
              final min = (i['min_quantity'] as num?)?.toDouble() ?? 0;
              return qty <= min;
            })();
            return matchCat && matchSearch && matchLow;
          }).toList();

          final categories = items.map((i) => i['category'] as String? ?? 'Other').toSet().toList()..sort();
          final totalValue = items.fold<double>(0, (s, i) =>
              s + ((i['quantity'] as num?)?.toDouble() ?? 0) * ((i['unit_price'] as num?)?.toDouble() ?? 0));

          return Column(
            children: [
              // Stats
              _InventoryStats(total: items.length, lowStock: lowStock, totalValue: totalValue),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),

              // Category filter
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _CatChip('All', null, _categoryFilter, (v) => setState(() => _categoryFilter = v)),
                    ...categories.map((c) => _CatChip(c, c, _categoryFilter, (v) => setState(() => _categoryFilter = v))),
                  ],
                ),
              ),

              // Low stock warning banner
              if (lowStock > 0 && !_lowStockOnly)
                GestureDetector(
                  onTap: () => setState(() => _lowStockOnly = true),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                        const SizedBox(width: 8),
                        Text('$lowStock items below minimum stock level',
                            style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Text('View', style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // List grouped by category
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(title: 'No Items Found', subtitle: 'No inventory items match your filter', icon: Icons.inventory_2_outlined)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        children: (() {
                          final grouped = <String, List<Map<String, dynamic>>>{};
                          for (final item in filtered) {
                            final cat = item['category'] as String? ?? 'Other';
                            grouped.putIfAbsent(cat, () => []).add(item);
                          }
                          return grouped.entries.map((e) =>
                              _CategorySection(category: e.key, items: e.value,
                                  onEdit: (item) => _showEditSheet(item))).toList();
                        })(),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: const Color(0xFF00796B),
      ),
    );
  }

  void _showAddSheet() => _showItemSheet(null);
  void _showEditSheet(Map<String, dynamic> item) => _showItemSheet(item);

  void _showItemSheet(Map<String, dynamic>? existing) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final qtyCtrl = TextEditingController(text: existing?['quantity']?.toString() ?? '');
    final minCtrl = TextEditingController(text: existing?['min_quantity']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?['unit_price']?.toString() ?? '');
    String unit = existing?['unit'] as String? ?? 'pcs';
    String category = existing?['category'] as String? ?? 'Kitchen';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add Inventory Item' : 'Edit Item',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Kitchen', 'Housekeeping', 'Activities', 'F&B', 'Maintenance']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setModal(() => category = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                  items: ['pcs', 'kg', 'L', 'g', 'ml', 'bundle', 'box', 'dozen']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setModal(() => unit = v!),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min Quantity', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unit Price (₹)', border: OutlineInputBorder(), prefixText: '₹ ')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final data = {
                      'name': nameCtrl.text, 'category': category, 'unit': unit,
                      'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                      'min_quantity': double.tryParse(minCtrl.text) ?? 0,
                      'unit_price': double.tryParse(priceCtrl.text) ?? 0,
                      'updated_at': DateTime.now().toIso8601String(),
                    };
                    final client = ref.read(supabaseClientProvider);
                    if (existing == null) {
                      await client.from('inventory_items').insert(data);
                    } else {
                      await client.from('inventory_items').update(data).eq('id', existing['id']);
                    }
                    ref.invalidate(inventoryProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    minimumSize: const Size(double.infinity, 48)),
                child: Text(existing == null ? 'Add Item' : 'Update Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _InventoryStats extends StatelessWidget {
  final int total, lowStock;
  final double totalValue;
  const _InventoryStats({required this.total, required this.lowStock, required this.totalValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF009688)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(children: [
        _IS('Total Items', '$total', Icons.inventory_2_outlined),
        _ID(), _IS('Low Stock', '$lowStock', Icons.warning_amber_outlined),
        _ID(), _IS('Stock Value', '₹${totalValue.toStringAsFixed(0)}', Icons.currency_rupee),
      ]),
    );
  }
}
class _IS extends StatelessWidget {
  final String l, v; final IconData i;
  const _IS(this.l, this.v, this.i);
  @override Widget build(_) => Expanded(child: Column(children: [
    Icon(i, color: Colors.white70, size: 16), const SizedBox(height: 4),
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]));
}
class _ID extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 36, color: Colors.white24);
}

// ── Category Chip ─────────────────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label;
  final String? value, selected;
  final ValueChanged<String?> onTap;
  const _CatChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final cfg = _categoryConfig[value];
    final color = cfg?['color'] as Color? ?? const Color(0xFF00796B);
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

// ── Category Section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onEdit;
  const _CategorySection({required this.category, required this.items, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cfg = _categoryConfig[category];
    final color = cfg?['color'] as Color? ?? AppTheme.primary;
    final icon = cfg?['icon'] as IconData? ?? Icons.inventory_2_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(width: 8),
          Text('(${items.length} items)', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => _InventoryItem(item: item, onEdit: () => onEdit(item))),
      ],
    );
  }
}

// ── Inventory Item ────────────────────────────────────────────────────────────

class _InventoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  const _InventoryItem({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
    final min = (item['min_quantity'] as num?)?.toDouble() ?? 0;
    final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final unit = item['unit'] as String? ?? 'pcs';
    final isLow = qty <= min;
    final isCritical = qty <= min * 0.5;
    final color = isCritical ? AppTheme.error : isLow ? AppTheme.warning : AppTheme.success;
    final pct = min > 0 ? (qty / min).clamp(0.0, 2.0) : 1.0;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: isLow ? Border.all(color: color.withOpacity(0.3)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(item['name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (isLow) ...[
                          const SizedBox(width: 6),
                          Icon(isCritical ? Icons.error_outline : Icons.warning_amber_outlined,
                              size: 14, color: color),
                        ],
                      ]),
                      Text('₹$price / $unit',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$qty $unit',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                    Text('Min: $min $unit',
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textHint),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 2).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
