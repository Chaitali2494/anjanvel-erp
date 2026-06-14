import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class GuideDashboardScreen extends StatelessWidget {
  const GuideDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Guide Dashboard'),
      body: const Center(child: Text('Guide Dashboard - Coming Soon')),
    );
  }
}
