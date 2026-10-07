import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../housekeeping/data/housekeeping_provider.dart';

// Uses shared housekeepingTasksProvider from housekeeping_provider.dart

// ── Screen ────────────────────────────────────────────────────────────────────

class HousekeepingDashboardScreen extends ConsumerWidget {
  const HousekeepingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(housekeepingTasksProvider);
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFFAB47BC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Good Morning!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const Text('Housekeeping Team', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => context.go('/dashboard/owner'),
                        icon: const Icon(Icons.home_rounded, color: Colors.white),
                        tooltip: 'Home',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(today, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Today\'s Cleaning Schedule', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // ── Stats bar ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: tasksAsync.when(
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
              error: (_, __) => const SizedBox.shrink(),
              data: (tasks) {
                final total     = tasks.length;
                final pending   = tasks.where((t) => t['status'] == 'PENDING').length;
                final inProg    = tasks.where((t) => t['status'] == 'IN_PROGRESS').length;
                final done      = tasks.where((t) => t['status'] == 'COMPLETED').length;
                final highPri   = tasks.where((t) => t['priority'] == 'HIGH').length;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  transform: Matrix4.translationValues(0, -12, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    _StatTile('Total',      '$total',  const Color(0xFF6A1B9A)),
                    _StatTile('Pending',    '$pending', const Color(0xFFFFB300)),
                    _StatTile('In Progress','$inProg',  const Color(0xFF1565C0)),
                    _StatTile('Done',       '$done',    const Color(0xFF2E7D32)),
                    _StatTile('Urgent',     '$highPri', const Color(0xFFE53935)),
                  ]),
                );
              },
            ),
          ),

          // ── Quick Actions ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _QuickAction(Icons.list_alt_rounded,        'Task List',   const Color(0xFF6A1B9A), () => context.push('/housekeeping')),
                    _QuickAction(Icons.checklist_rounded,        'Checklist',   const Color(0xFF1565C0), () => context.push('/housekeeping/checklist')),
                    _QuickAction(Icons.inventory_2_outlined,     'Inventory',   const Color(0xFF2E7D32), () => context.push('/inventory')),
                    _QuickAction(Icons.build_outlined,           'Maintenance', const Color(0xFF37474F), () => context.push('/maintenance')),
                  ]),
                ],
              ),
            ),
          ),

          // ── Room Status Overview ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today\'s Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton(
                    onPressed: () => context.push('/housekeeping'),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),

          // ── Task list ────────────────────────────────────────────────────
          tasksAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            data: (tasks) {
              final pending = tasks.where((t) => t['status'] != 'COMPLETED').take(5).toList();
              if (pending.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 48),
                        SizedBox(height: 8),
                        Text('All rooms are clean! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Great work today!', style: TextStyle(color: AppTheme.textPrimary)),
                      ]),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TaskTile(task: pending[i], onTap: () => context.push('/housekeeping')),
                  childCount: pending.length,
                ),
              );
            },
          ),

          // ── Checklist reminder ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: GestureDetector(
                onTap: () => context.push('/housekeeping/checklist'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(children: [
                    const Icon(Icons.checklist_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Room Cleaning Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Tap to open the room-by-room checklist', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textPrimary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  const _TaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'PENDING';
    final type     = task['task_type'] as String? ?? 'REGULAR_CLEAN';
    final priority = task['priority'] as String? ?? 'NORMAL';
    final room     = task['room_number'] as String? ?? '';
    final assigned = task['assigned_to'] as String? ?? '';

    final statusColor = status == 'IN_PROGRESS' ? const Color(0xFF1565C0)
        : status == 'COMPLETED' ? const Color(0xFF2E7D32) : const Color(0xFFFFB300);
    final priorityColor = priority == 'HIGH' ? const Color(0xFFE53935)
        : priority == 'LOW' ? const Color(0xFF9E9E9E) : const Color(0xFF1565C0);
    final typeLabel = type.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
    final statusLabel = status.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: statusColor.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF6A1B9A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Room $room — $typeLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(assigned, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
            ),
          ]),
        ]),
      ),
    );
  }
}
