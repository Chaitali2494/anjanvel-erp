import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class LeadDetailScreen extends StatelessWidget {
  final String leadId;
  const LeadDetailScreen({super.key, required this.leadId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Lead Detail'),
      body: const Center(child: Text('Lead Detail')),
    );
  }
}
