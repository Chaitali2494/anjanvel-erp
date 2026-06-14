import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class RoomAllocationScreen extends StatelessWidget {
  const RoomAllocationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Room Allocation'),
      body: const Center(child: Text('Room Allocation - Coming Soon')),
    );
  }
}
