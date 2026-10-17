import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class LeadListScreen extends StatelessWidget {
  const LeadListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Leads'),
      body: const Center(child: Text('Leads - Coming Soon')),
    );
  }
}
