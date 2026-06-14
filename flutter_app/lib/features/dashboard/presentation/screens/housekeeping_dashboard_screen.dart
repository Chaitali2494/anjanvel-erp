import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class HousekeepingDashboardScreen extends StatelessWidget {
  const HousekeepingDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Housekeeping Dashboard'),
      body: const Center(child: Text('Housekeeping Dashboard - Coming Soon')),
    );
  }
}
