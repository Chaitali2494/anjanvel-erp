import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class CheckOutScreen extends StatelessWidget {
  final String bookingId;
  const CheckOutScreen({super.key, required this.bookingId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Check Out'),
      body: const Center(child: Text('Check Out')),
    );
  }
}
