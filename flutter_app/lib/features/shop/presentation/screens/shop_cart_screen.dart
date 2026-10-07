import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/shop_cart_provider.dart';
import '../../data/shop_room_charges_provider.dart';

class ShopCartScreen extends ConsumerWidget {
  const ShopCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart     = ref.watch(shopCartProvider);
    final notifier = ref.read(shopCartProvider.notifier);

    final subtotal = notifier.subtotal;
    final gst      = subtotal * 0.05; // 5% GST on food/goods
    final total    = subtotal + gst;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Cart  (${notifier.itemCount} items)',
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(shopCartProvider.notifier).clear();
              },
              child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🛒', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 14),
                  const Text('Cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Add items from the shop', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Browse Products'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF558B2F)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Cart items ─────────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                        ),
                        child: Row(children: [
                          // Emoji
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          // Name + price
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            Text('₹${item.price.toStringAsFixed(0)} / ${item.unit}', style: const TextStyle(fontSize: 11, color: Color(0xFF558B2F))),
                          ])),
                          // Qty controls
                          Row(children: [
                            GestureDetector(
                              onTap: () => ref.read(shopCartProvider.notifier).decrement(item.name),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.remove_rounded, size: 16, color: AppTheme.error),
                              ),
                            ),
                            Container(
                              width: 36,
                              alignment: Alignment.center,
                              child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                            ),
                            GestureDetector(
                              onTap: () => ref.read(shopCartProvider.notifier).increment(item.name),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF558B2F)),
                              ),
                            ),
                          ]),
                          const SizedBox(width: 10),
                          // Item total
                          SizedBox(
                            width: 60,
                            child: Text('₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                              textAlign: TextAlign.right),
                          ),
                        ]),
                      );
                    },
                  ),
                ),

                // ── Bill summary + Send to Room ────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: Column(children: [
                    // Totals
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Subtotal', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                      Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('GST (5%)', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                      Text('₹${gst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    ]),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF558B2F))),
                    ]),
                    const SizedBox(height: 16),

                    // Send to Room button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSendToRoomSheet(context, ref, cart, total),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.hotel_rounded, color: Colors.white),
                        label: const Text('Send Bill to Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  void _showSendToRoomSheet(BuildContext context, WidgetRef ref, List<CartItem> cart, double total) {
    final roomCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.hotel_rounded, color: Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Send Bill to Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 8),

            // Cart summary
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF558B2F).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF558B2F).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  ...cart.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.emoji} ${item.name} × ${item.qty}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                        Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      ],
                    ),
                  )),
                  const Divider(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total (incl. GST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF558B2F))),
                  ]),
                ],
              ),
            ),

            // Room number input
            const Text('Room Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: roomCtrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 101, 205, 301',
                prefixIcon: const Icon(Icons.bed_outlined, color: Color(0xFF1565C0)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final roomNo = roomCtrl.text.trim();
                  if (roomNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a room number'), backgroundColor: AppTheme.error),
                    );
                    return;
                  }

                  // Add every cart item as a room charge
                  for (final item in cart) {
                    ref.read(shopRoomChargesProvider.notifier).addCharge(
                      ShopRoomCharge(
                        product: item.name,
                        roomNumber: roomNo,
                        price: item.price,
                        qty: item.qty,
                      ),
                    );
                  }

                  // Clear cart
                  ref.read(shopCartProvider.notifier).clear();

                  Navigator.pop(context); // close sheet
                  Navigator.pop(context); // close cart screen

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('₹${total.toStringAsFixed(0)} charged to Room $roomNo'),
                      ]),
                      backgroundColor: const Color(0xFF1565C0),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text('Confirm — Add to Room Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
