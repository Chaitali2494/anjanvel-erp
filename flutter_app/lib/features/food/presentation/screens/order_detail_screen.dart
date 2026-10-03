import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialData;
  const OrderDetailScreen({super.key, required this.orderId, this.initialData});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;

  static const _statusCfg = {
    'PENDING':    {'label': 'Pending',    'color': Color(0xFFFFB300), 'next': 'PREPARING',  'nextLabel': 'Start Preparing'},
    'PREPARING':  {'label': 'Preparing',  'color': Color(0xFF1565C0), 'next': 'READY',       'nextLabel': 'Mark Ready'},
    'READY':      {'label': 'Ready',      'color': Color(0xFF00838F), 'next': 'SERVED',      'nextLabel': 'Mark Served'},
    'SERVED':     {'label': 'Served',     'color': Color(0xFF2E7D32), 'next': null,           'nextLabel': null},
    'CANCELLED':  {'label': 'Cancelled',  'color': Color(0xFFE53935), 'next': null,           'nextLabel': null},
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _order = widget.initialData;
      _isLoading = false;
    } else {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final data = await client.from('food_orders').select('*, menu_items(name, price)').eq('id', widget.orderId).single();
      if (mounted) setState(() { _order = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.warning)));
    if (_order == null) return Scaffold(appBar: AppBar(title: const Text('Order')), body: const Center(child: Text('Order not found')));

    final status  = _order!['status'] as String? ?? 'PENDING';
    final token   = _order!['token_number']?.toString() ?? _order!['id']?.toString().substring(0, 6) ?? '';
    final room    = _order!['room_number']?.toString() ?? '';
    final notes   = _order!['special_notes'] as String? ?? '';
    final mealType= _order!['meal_type'] as String? ?? '';
    final items   = _order!['items'] as List? ?? [];
    final createdAt = _order!['created_at'] as String?;

    final statusColor = (_statusCfg[status]?['color'] as Color?) ?? Colors.grey;
    final statusLabel = (_statusCfg[status]?['label'] as String?) ?? status;
    final nextStatus  = _statusCfg[status]?['next'] as String?;
    final nextLabel   = _statusCfg[status]?['nextLabel'] as String?;

    String? formattedTime;
    if (createdAt != null) {
      try { formattedTime = DateFormat('h:mm a').format(DateTime.parse(createdAt)); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Order #$token', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE64A19),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.circle, color: statusColor, size: 10),
                const SizedBox(width: 8),
                Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (formattedTime != null)
                  Text(formattedTime, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),

            // Room / meal info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Column(children: [
                _Row(Icons.hotel_rounded, 'Room', 'Room $room'),
                if (mealType.isNotEmpty) _Row(Icons.restaurant_menu_rounded, 'Meal', mealType),
                _Row(Icons.tag_rounded, 'Token', '#$token'),
              ]),
            ),
            const SizedBox(height: 16),

            // Items
            const Text('Items Ordered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No items listed', style: TextStyle(color: AppTheme.textHint)),
                    )
                  : Column(
                      children: List.generate(items.length, (i) {
                        final item = items[i];
                        final name = item is Map ? (item['name'] ?? item.toString()) : item.toString();
                        final qty  = item is Map ? (item['quantity'] ?? 1) : 1;
                        final price= item is Map ? (item['price'] ?? '') : '';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(border: i < items.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: const Color(0xFFE64A19).withOpacity(0.1), shape: BoxShape.circle),
                              child: Center(child: Text('$qty', style: const TextStyle(color: Color(0xFFE64A19), fontWeight: FontWeight.bold, fontSize: 12))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                            if (price.toString().isNotEmpty)
                              Text('₹$price', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
                          ]),
                        );
                      }),
                    ),
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Special Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.sticky_note_2_outlined, color: Color(0xFFFFB300), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(notes, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            if (nextStatus != null && nextLabel != null)
              ElevatedButton(
                onPressed: () => _updateStatus(nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE64A19),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),

            if (status == 'PENDING') ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _updateStatus('CANCELLED'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Cancel Order'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('food_orders').update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()}).eq('id', widget.orderId);
      setState(() => _order = {...?_order, 'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _Row extends StatelessWidget {
  final IconData icon; final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.textHint),
      const SizedBox(width: 10),
      Text('$label:', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
      const SizedBox(width: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}
