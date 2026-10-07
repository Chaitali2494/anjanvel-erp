import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  final Map<String, dynamic>? initialData;
  const ProductDetailScreen({super.key, required this.productId, this.initialData});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  Map<String, dynamic> get _product => widget.initialData ?? {
    'name': 'Organic Forest Honey',
    'category': 'Food & Beverages',
    'price': 350,
    'stock': 12,
    'description': 'Pure, raw honey sourced from the forest near Anjanvel village. No additives or preservatives. Rich in antioxidants and natural sweetness.',
    'sku': 'FBH-001',
    'unit': '500g',
  };

  @override
  Widget build(BuildContext context) {
    final name     = _product['name'] as String? ?? '';
    final category = _product['category'] as String? ?? '';
    final price    = _product['price'] ?? 0;
    final stock    = _product['stock'] ?? 0;
    final desc     = _product['description'] as String? ?? '';
    final sku      = _product['sku'] as String? ?? '';
    final unit     = _product['unit'] as String? ?? '';
    final inStock  = (stock is int ? stock : int.tryParse(stock.toString()) ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Product Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF558B2F),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Container(
              width: double.infinity, height: 220,
              color: const Color(0xFF558B2F).withOpacity(0.08),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.storefront_rounded, size: 80, color: const Color(0xFF558B2F).withOpacity(0.3)),
                const SizedBox(height: 8),
                Text(name, style: TextStyle(color: const Color(0xFF558B2F).withOpacity(0.5), fontSize: 14)),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF558B2F).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(category, style: const TextStyle(color: Color(0xFF558B2F), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),

                  // Name & price
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF558B2F))),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('per $unit', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // Stock badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: inStock ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: inStock ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3)),
                      ),
                      child: Text(inStock ? 'In Stock ($stock units)' : 'Out of Stock',
                          style: TextStyle(color: inStock ? AppTheme.success : AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    if (sku.isNotEmpty) ...[
                      const Spacer(),
                      Text('SKU: $sku', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ]),
                  const SizedBox(height: 20),

                  // Description
                  if (desc.isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(desc, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Quantity selector
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(children: [
                    IconButton(
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFF558B2F),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                      child: Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: const Color(0xFF558B2F),
                    ),
                    const Spacer(),
                    Text('Total: ₹${price * _quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF558B2F))),
                  ]),
                  const SizedBox(height: 24),

                  // Add to cart
                  ElevatedButton.icon(
                    onPressed: inStock ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$_quantity × $name added to cart'), backgroundColor: AppTheme.success),
                      );
                      context.push('/shop/cart');
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF558B2F),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                    label: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
