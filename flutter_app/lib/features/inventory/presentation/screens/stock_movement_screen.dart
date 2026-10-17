import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class StockMovementScreen extends StatelessWidget {
  const StockMovementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Stock Movement'),
      body: const Center(child: Text('Stock Movement - Coming Soon')),
    );
  }
}
