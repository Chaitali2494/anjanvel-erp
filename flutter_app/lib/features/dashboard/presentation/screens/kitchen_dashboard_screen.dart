import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../core/providers/supabase_provider.dart';

final kitchenOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return await client
      .from('food_orders')
      .select('*, food_order_items(*, food_menu_items(name))')
      .inFilter('status', ['PENDING', 'PREPARING'])
      .gte('ordered_at', '${today}T00:00:00')
      .order('ordered_at', ascending: true);
});

class KitchenDashboardScreen extends ConsumerWidget {
  const KitchenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
        title: const Text('Kitchen Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu_outlined, color: Colors.white),
            onPressed: () => context.push('/food'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF57C00),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ordersAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (orders) => Row(
                children: [
                  _KitchenStat('Pending', orders.where((o) => o['status'] == 'PENDING').length.toString()),
                  _KitchenStat('Preparing', orders.where((o) => o['status'] == 'PREPARING').length.toString()),
                  _KitchenStat('Total Today', orders.length.toString()),
                ],
              ),
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const EmptyState(
                    title: 'No Active Orders',
                    subtitle: 'All orders are served. Kitchen is clear!',
                    icon: Icons.restaurant_outlined,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _KitchenOrderCard(
                    order: orders[i],
                    onRefresh: () => ref.refresh(kitchenOrdersProvider),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenStat extends StatelessWidget {
  final String label;
  final String value;
  const _KitchenStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _KitchenOrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRefresh;
  const _KitchenOrderCard({required this.order, required this.onRefresh});

  Color get _statusColor => order['status'] == 'PENDING' ? AppTheme.warning : AppTheme.info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = (order['food_order_items'] as List?) ?? [];
    final orderedAt = DateTime.tryParse(order['ordered_at'] ?? '');
    final waitTime = orderedAt != null ? DateTime.now().difference(orderedAt).inMinutes : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: _statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
            ),
            child: Row(
              children: [
                Text(order['order_number'] ?? '', style: TextStyle(color: _statusColor, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: waitTime > 15 ? AppTheme.error.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$waitTime min',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: waitTime > 15 ? AppTheme.error : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Text('${item['quantity']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item['item_name'] ?? '', style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (order['status'] == 'PENDING')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(supabaseClientProvider).from('food_orders').update({'status': 'PREPARING'}).eq('id', order['id']);
                            onRefresh();
                          },
                          icon: const Icon(Icons.restaurant, size: 16),
                          label: const Text('Start Preparing'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info, minimumSize: const Size(0, 40)),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(supabaseClientProvider).from('food_orders').update({'status': 'READY', 'served_at': DateTime.now().toIso8601String()}).eq('id', order['id']);
                            onRefresh();
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Mark Ready'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size(0, 40)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
