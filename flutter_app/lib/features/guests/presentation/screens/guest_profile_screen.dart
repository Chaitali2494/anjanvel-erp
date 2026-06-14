import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class GuestProfileScreen extends StatelessWidget {
  final String guestId;
  const GuestProfileScreen({super.key, required this.guestId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Guest Profile'),
      body: const Center(child: Text('Guest Profile')),
    );
  }
}
