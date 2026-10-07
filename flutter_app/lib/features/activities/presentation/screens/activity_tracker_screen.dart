import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/activity_bookings_provider.dart';
import '../../../staff/data/staff_access_provider.dart' as sap;

// ── Tracker status config ─────────────────────────────────────────────────────

const _trackerCfg = {
  'PENDING': {
    'label': 'Pending',
    'color': Color(0xFFF57C00),
    'icon': Icons.schedule_rounded,
  },
  'ASSIGNED': {
    'label': 'Assigned',
    'color': Color(0xFF1565C0),
    'icon': Icons.person_pin_rounded,
  },
  'IN_PROGRESS': {
    'label': 'In Progress',
    'color': Color(0xFF6A1B9A),
    'icon': Icons.directions_run_rounded,
  },
  'DONE': {
    'label': 'Done ✓',
    'color': AppTheme.success,
    'icon': Icons.check_circle_rounded,
  },
};

// ── Selected date provider ────────────────────────────────────────────────────

final _trackerDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class ActivityTrackerScreen extends ConsumerWidget {
  const ActivityTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(activityBookingsProvider);
    final selectedDate  = ref.watch(_trackerDateProvider);
    final dateStr       = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isToday       = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Activity Tracker'),
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/dashboard/owner'),
          ),
        ],
      ),
      body: Column(children: [
        // ── Date picker bar ──────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => ref.read(_trackerDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 1)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) ref.read(_trackerDateProvider.notifier).state = d;
                },
                child: Column(children: [
                  Text(isToday ? 'Today' : DateFormat('EEEE').format(selectedDate),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday ? const Color(0xFF00838F) : AppTheme.textPrimary)),
                  Text(DateFormat('d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                ]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => ref.read(_trackerDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1)),
            ),
            if (!isToday)
              TextButton(
                onPressed: () => ref.read(_trackerDateProvider.notifier).state = DateTime.now(),
                child: const Text('Today', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allBookings) {
              final dayBookings = allBookings
                  .where((b) =>
                      b['date'] == dateStr && b['status'] != 'CANCELLED')
                  .toList()
                ..sort((a, b) => (a['time'] as String? ?? '')
                    .compareTo(b['time'] as String? ?? ''));

              // Stats
              final done       = dayBookings.where((b) => b['tracker_status'] == 'DONE').length;
              final inProgress = dayBookings.where((b) => b['tracker_status'] == 'IN_PROGRESS').length;
              final assigned   = dayBookings.where((b) => b['tracker_status'] == 'ASSIGNED').length;
              final pending    = dayBookings.where((b) =>
                  b['tracker_status'] == 'PENDING' || b['tracker_status'] == null).length;

              return Column(children: [
                // Stats strip
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    _Stat('Pending', '$pending', const Color(0xFFF57C00)),
                    _Stat('Assigned', '$assigned', const Color(0xFF1565C0)),
                    _Stat('Active', '$inProgress', const Color(0xFF6A1B9A)),
                    _Stat('Done', '$done', AppTheme.success),
                  ]),
                ),
                const Divider(height: 0),

                // List
                Expanded(
                  child: dayBookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎯', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                isToday
                                    ? 'No activities scheduled today'
                                    : 'No activities on ${DateFormat('d MMM').format(selectedDate)}',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 15),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/activities/register'),
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                label: const Text('Book Activity',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00838F)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: dayBookings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ActivityTrackerCard(booking: dayBookings[i]),
                        ),
                ),
              ]);
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/activities/register'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Book Activity'),
        backgroundColor: const Color(0xFF00838F),
      ),
    );
  }
}

// ── Activity Tracker Card ─────────────────────────────────────────────────────

class _ActivityTrackerCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  const _ActivityTrackerCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status     = booking['tracker_status'] as String? ?? 'PENDING';
    final cfg        = _trackerCfg[status] ?? _trackerCfg['PENDING']!;
    final color      = cfg['color'] as Color;
    final icon       = cfg['icon'] as IconData;
    final label      = cfg['label'] as String;
    final isDone     = status == 'DONE';
    final coordinator = booking['coordinator'] as String?;
    final persons    = booking['persons'] as int? ?? 1;
    final time       = booking['time'] as String? ?? '';
    final total      = (booking['total_amount'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDone ? AppTheme.success.withOpacity(0.05) : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDone ? AppTheme.success.withOpacity(0.3) : Colors.grey.shade200,
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ────────────────────────────────────────────────────
          Row(children: [
            Text(booking['activity_emoji'] as String? ?? '🎯',
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking['activity_name'] as String? ?? 'Activity',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: isDone ? AppTheme.success : AppTheme.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null)),
              Text('${booking['category'] ?? ''} · $persons person${persons > 1 ? 's' : ''} · $time',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),

          // ── Info row ──────────────────────────────────────────────────
          Row(children: [
            _InfoBit(Icons.bed_outlined, 'Room ${booking['room_number'] ?? ''}'),
            const SizedBox(width: 12),
            _InfoBit(Icons.person_outline_rounded, booking['guest_name'] as String? ?? ''),
            const Spacer(),
            Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14,
                    color: Color(0xFF00838F))),
          ]),

          // ── Coordinator row ───────────────────────────────────────────
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.person_pin_rounded,
                size: 16,
                color: coordinator != null ? const Color(0xFF1565C0) : Colors.grey.shade400),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                coordinator ?? 'Unassigned — tap to assign coordinator',
                style: TextStyle(
                  fontSize: 12,
                  color: coordinator != null ? const Color(0xFF1565C0) : Colors.grey.shade500,
                  fontWeight: coordinator != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (!isDone)
              TextButton(
                onPressed: () => _assignCoordinator(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Text(coordinator != null ? 'Change' : 'Assign',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
              ),
          ]),

          // ── Action buttons ────────────────────────────────────────────
          if (!isDone) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (status == 'PENDING' || status == 'ASSIGNED')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(activityBookingsProvider.notifier)
                        .updateTrackerStatus(booking['id'] as String, 'IN_PROGRESS'),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                    label: const Text('Start', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6A1B9A),
                      side: const BorderSide(color: Color(0xFF6A1B9A)),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                ),
              if (status == 'PENDING' || status == 'ASSIGNED')
                const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ref
                      .read(activityBookingsProvider.notifier)
                      .updateTrackerStatus(booking['id'] as String, 'DONE'),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Mark Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(0, 38),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _assignCoordinator(BuildContext context, WidgetRef ref) async {
    final staffList = ref.read(sap.staffAccessProvider)
        .where((s) =>
            s['is_active'] == true &&
            (s['department'] == 'Activities' ||
             s['department'] == 'Tour Guide' ||
             s['department'] == 'Management'))
        .toList();

    // Also add any active staff as fallback
    final allActive = ref.read(sap.staffAccessProvider)
        .where((s) => s['is_active'] == true)
        .toList();

    final candidates = staffList.isNotEmpty ? staffList : allActive;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Assign Coordinator',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Divider(),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No active staff found.\nAdd staff in Staff Access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textPrimary)),
            )
          else
            ...candidates.map((s) => ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF00838F).withOpacity(0.1),
                child: Text(
                  (s['name'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF00838F), fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(s['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s['department'] as String,
                  style: const TextStyle(fontSize: 12)),
              onTap: () {
                ref.read(activityBookingsProvider.notifier)
                    .assignCoordinator(booking['id'] as String, s['name'] as String);
                Navigator.pop(context);
              },
            )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBit(this.icon, this.label);
  @override
  Widget build(_) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AppTheme.textPrimary),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
  ]);
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(_) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
    ]),
  );
}
