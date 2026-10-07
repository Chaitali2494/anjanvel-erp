import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';

class ActivityCoordinatorDashboardScreen extends ConsumerWidget {
  const ActivityCoordinatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(activityBookingsProvider);
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [

          // ── Hero header ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00695C), Color(0xFF00838F), Color(0xFF26C6DA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.hiking_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome!',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('Activity Coordinator',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(today,
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("Today's Activity Schedule",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // ── Stats strip ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const SizedBox(
                  height: 80,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00838F)))),
              error: (_, __) => const SizedBox.shrink(),
              data: (all) {
                final today = all
                    .where((b) =>
                        b['date'] == todayStr && b['status'] != 'CANCELLED')
                    .toList();
                final pending =
                    today.where((b) => (b['tracker_status'] ?? 'PENDING') == 'PENDING').length;
                final assigned =
                    today.where((b) => b['tracker_status'] == 'ASSIGNED').length;
                final active =
                    today.where((b) => b['tracker_status'] == 'IN_PROGRESS').length;
                final done =
                    today.where((b) => b['tracker_status'] == 'DONE').length;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  transform: Matrix4.translationValues(0, -12, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(children: [
                    _StatTile('Total', '${today.length}', const Color(0xFF00838F)),
                    _StatTile('Pending', '$pending', const Color(0xFFFFB300)),
                    _StatTile('Assigned', '$assigned', const Color(0xFF1565C0)),
                    _StatTile('Active', '$active', const Color(0xFF6A1B9A)),
                    _StatTile('Done', '$done', const Color(0xFF2E7D32)),
                  ]),
                );
              },
            ),
          ),

          // ── Quick Actions ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Actions',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _QuickAction(
                      Icons.add_circle_outline_rounded,
                      'Book Activity',
                      const Color(0xFF00838F),
                      () => context.push('/activities/register'),
                    ),
                    _QuickAction(
                      Icons.track_changes_rounded,
                      'Assigned Activities',
                      const Color(0xFF1565C0),
                      () => context.push('/activities/tracker'),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── Section header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Today's Assignments",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton(
                    onPressed: () => context.push('/activities/tracker'),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),

          // ── Activity list ──────────────────────────────────────────────────
          bookingsAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00838F)))),
            error: (e, _) =>
                SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            data: (all) {
              final todayBookings = all
                  .where((b) =>
                      b['date'] == todayStr && b['status'] != 'CANCELLED')
                  .toList()
                ..sort((a, b) => (a['time'] as String? ?? '')
                    .compareTo(b['time'] as String? ?? ''));

              if (todayBookings.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(children: [
                        const Text('🎯', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('No activities today',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        const Text('Book an activity to get started',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/activities/register'),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text('Book Activity',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00838F)),
                        ),
                      ]),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ActivityTile(
                    booking: todayBookings[i],
                    onTap: () => context.push('/activities/tracker'),
                  ),
                  childCount: todayBookings.length,
                ),
              );
            },
          ),

          // ── Bottom banner: open tracker ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: GestureDetector(
                onTap: () => context.push('/activities/tracker'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: const Row(children: [
                    Icon(Icons.track_changes_rounded,
                        color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activity Tracker',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            SizedBox(height: 2),
                            Text('Assign coordinators · Mark status · View all dates',
                                style:
                                    TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white70, size: 16),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.textPrimary),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

const _statusColors = {
  'PENDING':     Color(0xFFF57C00),
  'ASSIGNED':    Color(0xFF1565C0),
  'IN_PROGRESS': Color(0xFF6A1B9A),
  'DONE':        AppTheme.success,
};
const _statusLabels = {
  'PENDING':     'Pending',
  'ASSIGNED':    'Assigned',
  'IN_PROGRESS': 'In Progress',
  'DONE':        'Done ✓',
};

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;
  const _ActivityTile({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status      = booking['tracker_status'] as String? ?? 'PENDING';
    final stColor     = _statusColors[status] ?? const Color(0xFFF57C00);
    final stLabel     = _statusLabels[status] ?? status;
    final coordinator = booking['coordinator'] as String?;
    final persons     = booking['persons'] as int? ?? 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: stColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Row(children: [
          // Emoji icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00838F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                booking['activity_emoji'] as String? ?? '🎯',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + details
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                booking['activity_name'] as String? ?? 'Activity',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '${booking['time'] ?? ''} · $persons person${persons > 1 ? 's' : ''}'
                '${coordinator != null ? ' · $coordinator' : ' · Unassigned'}',
                style: TextStyle(
                    fontSize: 12,
                    color: coordinator != null
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade500),
              ),
            ]),
          ),
          // Status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: stColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(stLabel,
                style: TextStyle(
                    color: stColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
