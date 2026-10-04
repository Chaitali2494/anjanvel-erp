import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/housekeeping_provider.dart';

// ── Housekeeping Panel (shared by Owner & Manager dashboards) ──────────────────

class HousekeepingPanel extends ConsumerWidget {
  const HousekeepingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(housekeepingTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Housekeeping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        Text('All rooms clean — no pending tasks!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ]),
                    )
                  else
                    ...pending3.map((task) => HKTaskRow(task: task, ref: ref)),

                  // Footer link
                  InkWell(
                    onTap: () => context.push('/housekeeping'),
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
                const Text('Room Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: roomCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 101', prefixIcon: Icon(Icons.bed_outlined, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Task Type
                const Text('Task Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
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
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
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
                const Text('Assign To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: assignCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Savita K.', prefixIcon: Icon(Icons.person_outline, size: 18), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
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
          Text(assigned, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
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
