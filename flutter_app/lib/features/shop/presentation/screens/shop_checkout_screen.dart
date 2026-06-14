import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ShopCheckoutScreen extends StatelessWidget {
  const ShopCheckoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Checkout'),
      body: const Center(child: Text('Checkout - Coming Soon')),
    );
  }
}
