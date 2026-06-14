import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class BookingCalendarScreen extends StatelessWidget {
  const BookingCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Booking Calendar'),
      body: const Center(child: Text('Booking Calendar - Coming Soon')),
    );
  }
}
