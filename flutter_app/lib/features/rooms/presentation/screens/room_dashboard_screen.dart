import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/room_service.dart';

class RoomDashboardScreen extends ConsumerWidget {
  const RoomDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Room Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.push('/rooms/allocation'),
          ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          final available = rooms.where((r) => r['status'] == 'AVAILABLE').toList();
          final occupied = rooms.where((r) => r['status'] == 'OCCUPIED').toList();
          final cleaning = rooms.where((r) => r['status'] == 'CLEANING').toList();
          final maintenance = rooms.where((r) => r['status'] == 'MAINTENANCE').toList();
          final reserved = rooms.where((r) => r['status'] == 'RESERVED').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status Overview
                Row(
                  children: [
                    Expanded(child: _StatusSummaryCard('Available', available.length, AppTheme.statusAvailable, Icons.check_circle_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatusSummaryCard('Occupied', occupied.length, AppTheme.statusOccupied, Icons.person_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _StatusSummaryCard('Reserved', reserved.length, AppTheme.statusReserved, Icons.bookmark_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatusSummaryCard('Cleaning', cleaning.length, AppTheme.statusCleaning, Icons.cleaning_services_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatusSummaryCard('Maint.', maintenance.length, AppTheme.statusMaintenance, Icons.build_outlined)),
                  ],
                ),
                const SizedBox(height: 24),

                // All Rooms Grid
                const SectionHeader(title: 'All Rooms'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) => _RoomTile(room: rooms[i]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusSummaryCard(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomTile({required this.room});

  Color get _statusColor {
    switch (room['status']) {
      case 'AVAILABLE': return AppTheme.statusAvailable;
      case 'OCCUPIED': return AppTheme.statusOccupied;
      case 'RESERVED': return AppTheme.statusReserved;
      case 'CLEANING': return AppTheme.statusCleaning;
      case 'MAINTENANCE': return AppTheme.statusMaintenance;
      default: return AppTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/rooms/${room['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: _statusColor.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bed_rounded, size: 20, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              room['room_number'] ?? '',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(height: 2),
            Text(
              (room['status'] ?? '').toString().replaceAll('_', '\n'),
              style: TextStyle(fontSize: 9, color: _statusColor, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
