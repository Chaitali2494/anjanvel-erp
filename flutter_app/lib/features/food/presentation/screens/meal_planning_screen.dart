import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class MealPlanningScreen extends StatelessWidget {
  const MealPlanningScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Meal Planning'),
      body: const Center(child: Text('Meal Planning - Coming Soon')),
    );
  }
}
