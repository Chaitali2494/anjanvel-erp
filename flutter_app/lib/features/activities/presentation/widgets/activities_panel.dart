import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/activity_bookings_provider.dart';

// ── Activities Panel (shared by Owner & Manager dashboards) ───────────────────

const _kTeal1 = Color(0xFF00695C);
const _kTeal2 = Color(0xFF00838F);

class ActivitiesPanel extends ConsumerWidget {
  const ActivitiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(activityBookingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            Row(children: [
              TextButton(
                onPressed: () => context.push('/activities/tracker'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showAssignTask(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Assign Task', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal1,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        bookingsAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: _kTeal1),
          )),
          error: (_, __) => const SizedBox.shrink(),
          data: (allBookings) {
            final notifier = ref.read(activityBookingsProvider.notifier);
            final today = notifier.todayBookings();

            final pending = today.where((b) => b['tracker_status'] == 'PENDING' || b['tracker_status'] == null).length;
            final assigned = today.where((b) => b['tracker_status'] == 'ASSIGNED').length;
            final inProg  = today.where((b) => b['tracker_status'] == 'IN_PROGRESS').length;
            final done    = today.where((b) => b['tracker_status'] == 'DONE').length;

            final activeItems = today
                .where((b) => b['tracker_status'] != 'DONE')
                .take(3)
                .toList();

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: _kTeal1.withOpacity(0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Stats row
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_kTeal1, _kTeal2]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      _ActStat('Pending',     '$pending',  const Color(0xFFFFE082)),
                      _ActDiv(),
                      _ActStat('Assigned',    '$assigned', const Color(0xFF90CAF9)),
                      _ActDiv(),
                      _ActStat('In Progress', '$inProg',   const Color(0xFFCE93D8)),
                      _ActDiv(),
                      _ActStat('Done Today',  '$done',     const Color(0xFFA5D6A7)),
                    ]),
                  ),

                  // Activity rows
                  if (activeItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text('All activities done for today!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ]),
                    )
                  else
                    ...activeItems.map((b) => _ActRow(booking: b)),

                  // Footer → Activity Dashboard
                  InkWell(
                    onTap: () => context.go('/dashboard/activity-coordinator'),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Open Activity Dashboard', style: TextStyle(color: _kTeal1, fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: _kTeal1),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAssignTask(BuildContext context, WidgetRef ref) {
    final coordCtrl = TextEditingController();
    String? selectedId;

    final bookingsAsync = ref.read(activityBookingsProvider);
    final notifier      = ref.read(activityBookingsProvider.notifier);
    final today         = bookingsAsync.valueOrNull != null ? notifier.todayBookings() : <Map<String, dynamic>>[];
    final pendingToday  = today.where((b) =>
        b['tracker_status'] == 'PENDING' || b['tracker_status'] == null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _kTeal1.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.hiking_rounded, color: _kTeal1, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Assign Activity Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary)),
                ]),
                const SizedBox(height: 20),

                // Select Activity
                const Text('Select Activity *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                if (pendingToday.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.textHint),
                      SizedBox(width: 8),
                      Text('No pending activities today', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                    ]),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    hint: const Text('Choose activity booking'),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.event_note_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      labelStyle: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    dropdownColor: AppTheme.surface,
                    items: pendingToday.map((b) {
                      final name = b['activity_name'] as String? ?? 'Activity';
                      final emoji = b['activity_emoji'] as String? ?? '🎯';
                      final time = b['time'] as String? ?? '';
                      return DropdownMenuItem<String>(
                        value: b['id'] as String,
                        child: Text('$emoji $name  $time', style: const TextStyle(color: AppTheme.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (v) => setModal(() => selectedId = v),
                  ),
                const SizedBox(height: 14),

                // Coordinator Name
                const Text('Assign To *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: coordCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ramesh Patil',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedId == null || coordCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      notifier.assignCoordinator(selectedId!, coordCtrl.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Activity assigned!'),
                            backgroundColor: _kTeal1,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal1,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Assign Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat tile ──────────────────────────────────────────────────────────────────

class _ActStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ActStat(this.label, this.value, this.color);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9), textAlign: TextAlign.center),
  ]));
}

class _ActDiv extends StatelessWidget {
  const _ActDiv();
  @override Widget build(_) => Container(width: 1, height: 28, color: Colors.white24);
}

// ── Activity row ───────────────────────────────────────────────────────────────

class _ActRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _ActRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status      = booking['tracker_status'] as String? ?? 'PENDING';
    final actName     = booking['activity_name'] as String? ?? 'Activity';
    final actEmoji    = booking['activity_emoji'] as String? ?? '🎯';
    final coordinator = booking['coordinator'] as String? ?? 'Unassigned';
    final time        = booking['time'] as String? ?? '';

    final Color statusColor;
    switch (status) {
      case 'IN_PROGRESS': statusColor = const Color(0xFF1565C0); break;
      case 'ASSIGNED':    statusColor = _kTeal1; break;
      case 'DONE':        statusColor = AppTheme.success; break;
      default:            statusColor = const Color(0xFFFFB300);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _kTeal1.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(actEmoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
          Text('$coordinator  •  $time', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
