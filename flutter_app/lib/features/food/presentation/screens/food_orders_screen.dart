import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class FoodOrdersScreen extends StatelessWidget {
  const FoodOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Food Orders'),
      body: const Center(child: Text('Food Orders - Coming Soon')),
    );
  }
}
