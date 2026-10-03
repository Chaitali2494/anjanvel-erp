import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

final shopDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    return {
      'today_sales': 4850, 'total_orders': 23, 'top_products': [
        {'name': 'Organic Honey', 'sold': 8, 'revenue': 1200},
        {'name': 'Masala Mix', 'sold': 6, 'revenue': 900},
        {'name': 'Hand-Made Pottery', 'sold': 3, 'revenue': 1500},
        {'name': 'Jaggery Pack', 'sold': 12, 'revenue': 720},
      ],
      'low_stock': ['Organic Honey', 'Chili Masala'],
      'pending_orders': 3,
    };
  } catch (_) {
    return {};
  }
});

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(shopDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Shop Dashboard',
        actions: [
          IconButton(icon: const Icon(Icons.storefront_rounded), onPressed: () => context.push('/shop')),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF558B2F))),
        error: (_, __) => const Center(child: Text('Error loading data')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF558B2F), Color(0xFF689F38)]),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's Sales", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('₹${data['today_sales']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _KPI('Orders',      '${data['total_orders']}',   Icons.shopping_bag_rounded),
                      _KPI('Pending',     '${data['pending_orders']}', Icons.pending_rounded),
                      _KPI('Low Stock',   '${(data['low_stock'] as List).length}', Icons.warning_amber_rounded),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Low stock alert
              if ((data['low_stock'] as List).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Low stock: ${(data['low_stock'] as List).join(', ')}',
                      style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Top products
              const Text('Top Selling Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...(data['top_products'] as List).map((p) {
                final maxSold = ((data['top_products'] as List).map((x) => x['sold'] as int).reduce((a, b) => a > b ? a : b));
                final progress = (p['sold'] as int) / maxSold;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                        Text('${p['sold']} sold', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text('₹${p['revenue']}', style: const TextStyle(color: Color(0xFF558B2F), fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        color: const Color(0xFF558B2F),
                        backgroundColor: Colors.grey.shade100,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Quick actions
              Row(children: [
                Expanded(child: _ActionBtn('Products',  Icons.inventory_2_outlined,  const Color(0xFF558B2F), () => context.push('/shop'))),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn('Cart',      Icons.shopping_cart_outlined, const Color(0xFF1565C0), () => context.push('/shop/cart'))),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn('Checkout',  Icons.payment_rounded,        const Color(0xFFE64A19), () => context.push('/shop/checkout'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _KPI extends StatelessWidget {
  final String label, value; final IconData icon;
  const _KPI(this.label, this.value, this.icon);
  @override Widget build(_) => Expanded(child: Column(children: [
    Icon(icon, color: Colors.white60, size: 18),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);
  @override Widget build(_) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMD), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
