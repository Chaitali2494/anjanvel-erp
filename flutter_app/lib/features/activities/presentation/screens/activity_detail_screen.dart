import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ActivityDetailScreen extends StatelessWidget {
  final String activityId;
  const ActivityDetailScreen({super.key, required this.activityId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Activity Detail'),
      body: const Center(child: Text('Activity Detail')),
    );
  }
}
