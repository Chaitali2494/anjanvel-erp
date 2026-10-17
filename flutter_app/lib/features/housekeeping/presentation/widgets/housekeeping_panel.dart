import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/housekeeping_provider.dart';
import '../../../guest/data/guest_requests_provider.dart';

// ── Housekeeping Panel (shared by Owner & Manager dashboards) ──────────────────

class HousekeepingPanel extends ConsumerWidget {
  const HousekeepingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(housekeepingTasksProvider);

    final guestRequests = ref.watch(guestRequestsProvider);
    final pendingGuestHk = guestRequests
        .where((r) => r['type'] == 'HOUSEKEEPING' && r['status'] == 'PENDING')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Guest HK requests banner ───────────────────────────────────────
        if (pendingGuestHk.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withOpacity(0.07),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: const Color(0xFFE65100).withOpacity(0.4), width: 1.5),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(children: [
                  _HkPulsingDot(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🆕 ${pendingGuestHk.length} New Housekeeping Request${pendingGuestHk.length > 1 ? 's' : ''} via Guest QR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${pendingGuestHk.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ),
              ...pendingGuestHk.take(3).map((r) => _GuestHkRow(request: r, ref: ref)),
              if (pendingGuestHk.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 8),
                  child: Text('+${pendingGuestHk.length - 3} more · Go to Housekeeping',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE65100))),
                ),
              const SizedBox(height: 4),
            ]),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Housekeeping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            Row(children: [
              TextButton(
                onPressed: () => context.push('/housekeeping'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showAssignTask(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Assign Task', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        tasksAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Color(0xFF6A1B9A)),
          )),
          error: (_, __) => const SizedBox.shrink(),
          data: (tasks) {
            final pending  = tasks.where((t) => t['status'] == 'PENDING').length;
            final inProg   = tasks.where((t) => t['status'] == 'IN_PROGRESS').length;
            final done     = tasks.where((t) => t['status'] == 'COMPLETED').length;
            final urgent   = tasks.where((t) => t['priority'] == 'HIGH' && t['status'] != 'COMPLETED').length;
            final pending3 = tasks.where((t) => t['status'] != 'COMPLETED').take(3).toList();

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Stats row
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      HKStat('Pending', '$pending', const Color(0xFFFFE082)),
                      HKDiv(),
                      HKStat('In Progress', '$inProg', const Color(0xFF90CAF9)),
                      HKDiv(),
                      HKStat('Done Today', '$done', const Color(0xFFA5D6A7)),
                      HKDiv(),
                      HKStat('Urgent', '$urgent', const Color(0xFFEF9A9A)),
                    ]),
                  ),

                  // Pending task cards
                  if (pending3.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text('All rooms clean — no pending tasks!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ]),
                    )
                  else
                    ...pending3.map((task) => HKTaskRow(task: task, ref: ref)),

                  // Footer link → HK Dashboard
                  InkWell(
                    onTap: () => context.go('/dashboard/housekeeping'),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Open Housekeeping Dashboard', style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF6A1B9A)),
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
    final roomCtrl     = TextEditingController();
    final assignCtrl   = TextEditingController();
    final notesCtrl    = TextEditingController();
    String taskType    = 'REGULAR_CLEAN';
    String priority    = 'NORMAL';

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
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF6A1B9A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Assign Housekeeping Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ]),
                const SizedBox(height: 20),

                // Room
                const Text('Room Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: roomCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 101', prefixIcon: Icon(Icons.bed_outlined, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Task Type
                const Text('Task Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: taskType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.list_alt_rounded, size: 18)),
                  items: const [
                    DropdownMenuItem(value: 'REGULAR_CLEAN',  child: Text('Regular Clean')),
                    DropdownMenuItem(value: 'CHECKOUT_CLEAN', child: Text('Checkout Clean')),
                    DropdownMenuItem(value: 'DEEP_CLEAN',     child: Text('Deep Clean')),
                    DropdownMenuItem(value: 'LINEN_CHANGE',   child: Text('Linen Change')),
                    DropdownMenuItem(value: 'TURNDOWN',       child: Text('Turndown')),
                    DropdownMenuItem(value: 'INSPECTION',     child: Text('Inspection')),
                  ],
                  onChanged: (v) => setModal(() => taskType = v!),
                ),
                const SizedBox(height: 14),

                // Priority
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final p in ['HIGH', 'NORMAL', 'LOW']) ...[
                    Expanded(child: GestureDetector(
                      onTap: () => setModal(() => priority = p),
                      child: Container(
                        margin: EdgeInsets.only(right: p != 'LOW' ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? (p == 'HIGH' ? const Color(0xFFE53935) : p == 'NORMAL' ? const Color(0xFF1565C0) : Colors.grey)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: priority == p
                              ? (p == 'HIGH' ? const Color(0xFFE53935) : p == 'NORMAL' ? const Color(0xFF1565C0) : Colors.grey)
                              : Colors.grey.shade300),
                        ),
                        child: Text(p, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: priority == p ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold, fontSize: 13,
                            )),
                      ),
                    )),
                  ],
                ]),
                const SizedBox(height: 14),

                // Assigned To
                const Text('Assign To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: assignCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Savita K.', prefixIcon: Icon(Icons.person_outline, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Special instructions...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (roomCtrl.text.trim().isEmpty) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      await ref.read(housekeepingTasksProvider.notifier).addTask({
                        'room_number': roomCtrl.text.trim(),
                        'task_type':   taskType,
                        'priority':    priority,
                        'status':      'PENDING',
                        'assigned_to': assignCtrl.text.trim().isEmpty ? null : assignCtrl.text.trim(),
                        'notes':       notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task assigned to housekeeping!'), backgroundColor: Color(0xFF6A1B9A)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
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

// ── Guest HK Request Row ───────────────────────────────────────────────────────

class _GuestHkRow extends StatelessWidget {
  final Map<String, dynamic> request;
  final WidgetRef ref;
  const _GuestHkRow({required this.request, required this.ref});

  @override
  Widget build(BuildContext context) {
    final room = request['room_number'] as String? ?? '';
    final title = request['title'] as String? ?? '';
    final subType = (request['sub_type'] as String? ?? '').replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.orange.shade100))),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFE65100).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(room, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFE65100)))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimary)),
          Text('Via Guest QR  •  $subType', style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ])),
        Row(children: [
          GestureDetector(
            onTap: () {
              ref.read(guestRequestsProvider.notifier).updateStatus(request['id'] as String, 'IN_PROGRESS');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request acknowledged — in progress'), backgroundColor: Color(0xFF1565C0)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('Accept', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              ref.read(guestRequestsProvider.notifier).updateStatus(request['id'] as String, 'DONE');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('Done', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class HKStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const HKStat(this.label, this.value, this.color, {super.key});
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9), textAlign: TextAlign.center),
  ]));
}

class HKDiv extends StatelessWidget {
  const HKDiv({super.key});
  @override Widget build(_) => Container(width: 1, height: 28, color: Colors.white24);
}

class _HkPulsingDot extends StatefulWidget {
  @override State<_HkPulsingDot> createState() => _HkPulsingDotState();
}
class _HkPulsingDotState extends State<_HkPulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _scale = Tween(begin: 0.6, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFFE65100), shape: BoxShape.circle),
    ),
  );
}

class HKTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final WidgetRef ref;
  const HKTaskRow({required this.task, required this.ref, super.key});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'PENDING';
    final type     = (task['task_type'] as String? ?? 'REGULAR_CLEAN').replaceAll('_', ' ');
    final room     = task['room_number'] as String? ?? '';
    final assigned = task['assigned_to'] as String? ?? 'Unassigned';
    final priority = task['priority'] as String? ?? 'NORMAL';

    final statusColor = status == 'IN_PROGRESS' ? const Color(0xFF1565C0) : const Color(0xFFFFB300);
    final priorityColor = priority == 'HIGH' ? const Color(0xFFE53935) : priority == 'LOW' ? Colors.grey : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(room, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6A1B9A)))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(' '),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(assigned, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
        ]),
      ]),
    );
  }
}
