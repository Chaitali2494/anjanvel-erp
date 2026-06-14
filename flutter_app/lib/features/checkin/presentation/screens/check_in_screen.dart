import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class CheckInScreen extends StatelessWidget {
  final String bookingId;
  const CheckInScreen({super.key, required this.bookingId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Check In'),
      body: const Center(child: Text('Check In')),
    );
  }
}
