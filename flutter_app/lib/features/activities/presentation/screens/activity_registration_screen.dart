import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ActivityRegistrationScreen extends StatelessWidget {
  final String activityId;
  const ActivityRegistrationScreen({super.key, required this.activityId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Register for Activity'),
      body: const Center(child: Text('Activity Registration')),
    );
  }
}
