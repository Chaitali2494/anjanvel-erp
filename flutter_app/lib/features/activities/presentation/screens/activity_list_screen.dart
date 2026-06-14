import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Activities'),
      body: const Center(child: Text('Activities - Coming Soon')),
    );
  }
}
