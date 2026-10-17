import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class GuestListScreen extends StatelessWidget {
  const GuestListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Guests'),
      body: const Center(child: Text('Guests - Coming Soon')),
    );
  }
}
