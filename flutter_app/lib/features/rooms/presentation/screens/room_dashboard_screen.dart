import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/room_service.dart';

class RoomDashboardScreen extends ConsumerStatefulWidget {
  const RoomDashboardScreen({super.key});

  @override
  ConsumerState<RoomDashboardScreen> createState() => _RoomDashboardScreenState();
}

class _RoomDashboardScreenState extends ConsumerState<RoomDashboardScreen> {
  String _filterStatus = 'ALL';

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Rooms',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(allRoomsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 12),
              Text('Error loading rooms', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(e.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(allRoomsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rooms) {
          final available = rooms.where((r) => r['status'] == 'AVAILABLE').toList();
          final occupied = rooms.where((r) => r['status'] == 'OCCUPIED').toList();
          final reserved = rooms.where((r) => r['status'] == 'RESERVED').toList();
          final cleaning = rooms.where((r) => r['status'] == 'CLEANING').toList();
          final maintenance = rooms.where((r) => r['status'] == 'MAINTENANCE').toList();

          final filtered = _filterStatus == 'ALL'
              ? rooms
              : rooms.where((r) => r['status'] == _filterStatus).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allRoomsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Occupancy summary bar
                  _OccupancyBar(
                    total: rooms.length,
                    occupied: occupied.length,
                    reserved: reserved.length,
                    available: available.length,
                  ),
                  const SizedBox(height: 16),

                  // Status summary chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip('ALL', rooms.length, null, _filterStatus, (s) => setState(() => _filterStatus = s)),
                        const SizedBox(width: 8),
                        _FilterChip('AVAILABLE', available.length, AppTheme.statusAvailable, _filterStatus, (s) => setState(() => _filterStatus = s)),
                        const SizedBox(width: 8),
                        _FilterChip('OCCUPIED', occupied.length, AppTheme.statusOccupied, _filterStatus, (s) => setState(() => _filterStatus = s)),
                        const SizedBox(width: 8),
                        _FilterChip('RESERVED', reserved.length, AppTheme.statusReserved, _filterStatus, (s) => setState(() => _filterStatus = s)),
                        const SizedBox(width: 8),
                        _FilterChip('CLEANING', cleaning.length, AppTheme.statusCleaning, _filterStatus, (s) => setState(() => _filterStatus = s)),
                        const SizedBox(width: 8),
                        _FilterChip('MAINTENANCE', maintenance.length, AppTheme.statusMaintenance, _filterStatus, (s) => setState(() => _filterStatus = s)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Room grid
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.bed_outlined, size: 48, color: AppTheme.textHint),
                            const SizedBox(height: 8),
                            Text('No rooms in this status', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textHint)),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _RoomCard(room: filtered[i], onStatusChanged: () => ref.invalidate(allRoomsProvider)),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Occupancy Bar ─────────────────────────────────────────────────────────────

class _OccupancyBar extends StatelessWidget {
  final int total, occupied, reserved, available;
  const _OccupancyBar({required this.total, required this.occupied, required this.reserved, required this.available});

  @override
  Widget build(BuildContext context) {
    final occupancyPct = total == 0 ? 0.0 : (occupied + reserved) / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Occupancy Today', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '${(occupancyPct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: occupancyPct,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BarStat('Occupied', occupied, Colors.white),
              _BarStat('Reserved', reserved, Colors.white70),
              _BarStat('Available', available, const Color(0xFFA5D6A7)),
              _BarStat('Total', total, Colors.white60),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _BarStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ],
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String status, currentFilter;
  final int count;
  final Color? color;
  final Function(String) onTap;

  const _FilterChip(this.status, this.count, this.color, this.currentFilter, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isActive = status == currentFilter;
    final chipColor = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: () => onTap(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? chipColor : chipColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? chipColor : chipColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == 'ALL' ? 'All' : status.replaceAll('_', ' '),
              style: TextStyle(
                color: isActive ? Colors.white : chipColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white24 : chipColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : chipColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Room Card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onStatusChanged;
  const _RoomCard({required this.room, required this.onStatusChanged});

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

  IconData get _statusIcon {
    switch (room['status']) {
      case 'AVAILABLE': return Icons.check_circle_outline;
      case 'OCCUPIED': return Icons.person_rounded;
      case 'RESERVED': return Icons.bookmark_rounded;
      case 'CLEANING': return Icons.cleaning_services_outlined;
      case 'MAINTENANCE': return Icons.build_outlined;
      default: return Icons.bed_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeName = room['room_type_name'] ?? room['type_name'] ?? 'Room';
    final guestName = room['current_guest'] as String?;

    return GestureDetector(
      onTap: () => context.push('/rooms/${room['id']}'),
      onLongPress: () => _showStatusMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: _statusColor.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  room['room_number'] ?? '—',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon, size: 16, color: _statusColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              typeName.toString().length > 20
                  ? '${typeName.toString().substring(0, 18)}…'
                  : typeName.toString(),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (room['status'] ?? '').toString().replaceAll('_', ' '),
                style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w700),
              ),
            ),
            if (guestName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      guestName,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    final roomService = ProviderScope.containerOf(context).read(roomServiceProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Room ${room['room_number']} — Update Status',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            ...[
              ('AVAILABLE', Icons.check_circle_outline, AppTheme.statusAvailable),
              ('CLEANING', Icons.cleaning_services_outlined, AppTheme.statusCleaning),
              ('MAINTENANCE', Icons.build_outlined, AppTheme.statusMaintenance),
              ('OCCUPIED', Icons.person_rounded, AppTheme.statusOccupied),
            ].map((s) => ListTile(
              leading: Icon(s.$2, color: s.$3),
              title: Text(s.$1.replaceAll('_', ' ')),
              onTap: () async {
                Navigator.pop(context);
                await roomService.updateRoomStatus(room['id'] as String, s.$1);
                onStatusChanged();
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
