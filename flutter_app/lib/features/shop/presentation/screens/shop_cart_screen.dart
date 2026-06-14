import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ShopCartScreen extends StatelessWidget {
  const ShopCartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Cart'),
      body: const Center(child: Text('Cart - Coming Soon')),
    );
  }
}
