import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class InventoryListScreen extends StatelessWidget {
  const InventoryListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Inventory'),
      body: const Center(child: Text('Inventory - Coming Soon')),
    );
  }
}
