import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ShopProductListScreen extends StatelessWidget {
  const ShopProductListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Shop'),
      body: const Center(child: Text('Shop - Coming Soon')),
    );
  }
}
