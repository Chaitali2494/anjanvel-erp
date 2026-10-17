import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/staff_access_provider.dart';

class LeaveManagementScreen extends ConsumerWidget {
  const LeaveManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = ref.watch(leaveProvider);
    final pending  = leaves.where((l) => l['status'] == 'PENDING').toList();
    final approved = leaves.where((l) => l['status'] == 'APPROVED').toList();
    final rejected = leaves.where((l) => l['status'] == 'REJECTED').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Leave Management'),
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Approved (${approved.length})'),
              Tab(text: 'Rejected (${rejected.length})'),
            ],
          ),
        ),
        body: TabBarView(children: [
          // ── Pending ──────────────────────────────────────────────────────
          pending.isEmpty
              ? const _EmptyState('No pending leave requests')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LeaveCard(
                    leave: pending[i],
                    showActions: true,
                    onApprove: () => ref.read(leaveProvider.notifier)
                        .approve(pending[i]['id'] as String, 'Manager'),
                    onReject: () => ref.read(leaveProvider.notifier)
                        .reject(pending[i]['id'] as String),
                  ),
                ),

          // ── Approved ─────────────────────────────────────────────────────
          approved.isEmpty
              ? const _EmptyState('No approved leaves')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: approved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LeaveCard(leave: approved[i]),
                ),

          // ── Rejected ─────────────────────────────────────────────────────
          rejected.isEmpty
              ? const _EmptyState('No rejected leaves')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rejected.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LeaveCard(leave: rejected[i]),
                ),
        ]),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _LeaveCard({
    required this.leave,
    this.showActions = false,
    this.onApprove,
    this.onReject,
  });

  static const _statusColors = {
    'PENDING':  Colors.orange,
    'APPROVED': AppTheme.success,
    'REJECTED': AppTheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final status     = leave['status'] as String;
    final statusColor = _statusColors[status] ?? Colors.grey;
    final dept       = leave['department'] as String;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        border: showActions
            ? Border.all(color: Colors.orange.withOpacity(0.3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.12),
              child: Text(
                (leave['staff_name'] as String).substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF6A1B9A),
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(leave['staff_name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(dept,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(status,
                  style: TextStyle(
                      color: statusColor, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),

          // Details
          _DetailRow(Icons.calendar_today_rounded, 'Leave Date', leave['date'] as String),
          const SizedBox(height: 6),
          _DetailRow(Icons.notes_rounded, 'Reason', leave['reason'] as String),
          if (leave['approved_by'] != null) ...[
            const SizedBox(height: 6),
            _DetailRow(Icons.person_rounded, 'Approved By',
                leave['approved_by'] as String),
          ],

          // Action buttons
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Approve',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);
  @override
  Widget build(_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 14, color: AppTheme.textPrimary),
    const SizedBox(width: 6),
    Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
    Expanded(
      child: Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  ]);
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);
  @override
  Widget build(_) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.beach_access_outlined, size: 48, color: AppTheme.textPrimary),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
    ]),
  );
}
