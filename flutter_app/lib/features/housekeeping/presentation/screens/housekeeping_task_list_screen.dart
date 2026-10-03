import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final housekeepingTasksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client
        .from('housekeeping_tasks')
        .select('*, rooms(room_number, room_type)')
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
  } catch (_) {
    return _demoTasks;
  }
});

const _demoTasks = [
  {'id': '1', 'room_number': '101', 'task_type': 'CHECKOUT_CLEAN', 'status': 'PENDING',   'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest checked out at 11 AM', 'rooms': {'room_number': '101', 'room_type': 'Deluxe'}},
  {'id': '2', 'room_number': '102', 'task_type': 'REGULAR_CLEAN',  'status': 'IN_PROGRESS','priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': '', 'rooms': {'room_number': '102', 'room_type': 'Standard'}},
  {'id': '3', 'room_number': '205', 'task_type': 'DEEP_CLEAN',     'status': 'PENDING',   'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest requested deep clean', 'rooms': {'room_number': '205', 'room_type': 'Suite'}},
  {'id': '4', 'room_number': '103', 'task_type': 'LINEN_CHANGE',   'status': 'COMPLETED', 'priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': '', 'rooms': {'room_number': '103', 'room_type': 'Standard'}},
  {'id': '5', 'room_number': '201', 'task_type': 'REGULAR_CLEAN',  'status': 'PENDING',   'priority': 'LOW',    'assigned_to': 'Priya T.',   'notes': 'Do after 3 PM', 'rooms': {'room_number': '201', 'room_type': 'Deluxe'}},
  {'id': '6', 'room_number': '301', 'task_type': 'TURNDOWN',       'status': 'PENDING',   'priority': 'NORMAL', 'assigned_to': 'Priya T.',   'notes': '', 'rooms': {'room_number': '301', 'room_type': 'Villa'}},
];

// ── Config ────────────────────────────────────────────────────────────────────

const _statusConfig = {
  'PENDING':     {'label': 'Pending',     'color': Color(0xFFFFB300)},
  'IN_PROGRESS': {'label': 'In Progress', 'color': Color(0xFF1565C0)},
  'COMPLETED':   {'label': 'Done',        'color': Color(0xFF2E7D32)},
  'SKIPPED':     {'label': 'Skipped',     'color': Color(0xFF9E9E9E)},
};

const _typeConfig = {
  'CHECKOUT_CLEAN': {'label': 'Checkout Clean', 'icon': Icons.hotel_rounded},
  'REGULAR_CLEAN':  {'label': 'Regular Clean',  'icon': Icons.cleaning_services_rounded},
  'DEEP_CLEAN':     {'label': 'Deep Clean',     'icon': Icons.auto_fix_high_rounded},
  'LINEN_CHANGE':   {'label': 'Linen Change',   'icon': Icons.bed_rounded},
  'TURNDOWN':       {'label': 'Turndown',       'icon': Icons.nights_stay_rounded},
  'INSPECTION':     {'label': 'Inspection',     'icon': Icons.fact_check_outlined},
};

const _priorityConfig = {
  'HIGH':   {'label': 'High',   'color': Color(0xFFE53935)},
  'NORMAL': {'label': 'Normal', 'color': Color(0xFF1565C0)},
  'LOW':    {'label': 'Low',    'color': Color(0xFF9E9E9E)},
};

// ── Screen ────────────────────────────────────────────────────────────────────

class HousekeepingTaskListScreen extends ConsumerStatefulWidget {
  const HousekeepingTaskListScreen({super.key});
  @override
  ConsumerState<HousekeepingTaskListScreen> createState() => _HousekeepingTaskListScreenState();
}

class _HousekeepingTaskListScreenState extends ConsumerState<HousekeepingTaskListScreen> {
  String _filterStatus = 'ALL';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(housekeepingTasksProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Housekeeping Tasks',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(housekeepingTasksProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTask(context),
        backgroundColor: const Color(0xFF6A1B9A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Task', style: TextStyle(color: Colors.white)),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          final pending   = tasks.where((t) => t['status'] == 'PENDING').length;
          final inProgress= tasks.where((t) => t['status'] == 'IN_PROGRESS').length;
          final completed = tasks.where((t) => t['status'] == 'COMPLETED').length;

          final filtered = _filterStatus == 'ALL'
              ? tasks
              : tasks.where((t) => t['status'] == _filterStatus).toList();

          return Column(
            children: [
              // Stats
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(children: [
                  _Stat('Total',      '${tasks.length}', Colors.white70, Colors.white),
                  _Div(), _Stat('Pending',    '$pending',      Colors.white70, const Color(0xFFFFB300)),
                  _Div(), _Stat('In Progress','$inProgress',   Colors.white70, const Color(0xFF90CAF9)),
                  _Div(), _Stat('Done',       '$completed',    Colors.white70, const Color(0xFFA5D6A7)),
                ]),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED'].map((s) {
                    final selected = _filterStatus == s;
                    final label = s == 'ALL' ? 'All' : (_statusConfig[s]?['label'] as String? ?? s);
                    final color = s == 'ALL' ? const Color(0xFF6A1B9A) : (_statusConfig[s]?['color'] as Color? ?? Colors.grey);
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? color : color.withOpacity(0.3)),
                        ),
                        child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Tasks
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(title: 'No Tasks', subtitle: 'All tasks are complete!', icon: Icons.check_circle_outline_rounded)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _TaskCard(
                          task: filtered[i],
                          onStatusChange: (id, status) => _updateStatus(id, status),
                          onChecklist: (task) => context.push('/housekeeping/checklist', extra: task),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('housekeeping_tasks').update({'status': status, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
      ref.invalidate(housekeepingTasksProvider);
    } catch (_) {}
  }

  void _showAddTask(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Housekeeping Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Room Number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Task Notes', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), minimumSize: const Size(double.infinity, 48)),
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final void Function(String, String) onStatusChange;
  final void Function(Map<String, dynamic>) onChecklist;
  const _TaskCard({required this.task, required this.onStatusChange, required this.onChecklist});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'PENDING';
    final type     = task['task_type'] as String? ?? 'REGULAR_CLEAN';
    final priority = task['priority'] as String? ?? 'NORMAL';
    final room     = (task['rooms'] as Map?)?['room_number'] ?? task['room_number'] ?? '';
    final roomType = (task['rooms'] as Map?)?['room_type'] ?? '';
    final assigned = task['assigned_to'] as String? ?? '';
    final notes    = task['notes'] as String? ?? '';
    final id       = task['id'] as String? ?? '';

    final statusColor = (_statusConfig[status]?['color'] as Color?) ?? Colors.grey;
    final statusLabel = (_statusConfig[status]?['label'] as String?) ?? status;
    final typeLabel   = (_typeConfig[type]?['label'] as String?) ?? type;
    final typeIcon    = (_typeConfig[type]?['icon'] as IconData?) ?? Icons.cleaning_services_rounded;
    final priColor    = (_priorityConfig[priority]?['color'] as Color?) ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: statusColor.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(typeIcon, color: const Color(0xFF6A1B9A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Room $room — $typeLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(roomType.isNotEmpty ? '$roomType · $assigned' : assigned,
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
            ])),
            // Priority dot
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: priColor, shape: BoxShape.circle),
            ),
          ]),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (status != 'COMPLETED') ...[
              if (status == 'PENDING')
                _ActionBtn('Start', const Color(0xFF1565C0), () => onStatusChange(id, 'IN_PROGRESS')),
              if (status == 'IN_PROGRESS') ...[
                _ActionBtn('Checklist', const Color(0xFF6A1B9A), () => onChecklist(task)),
                const SizedBox(width: 6),
                _ActionBtn('Done', const Color(0xFF2E7D32), () => onStatusChange(id, 'COMPLETED')),
              ],
            ],
          ]),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.onTap);
  @override Widget build(_) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String l, v; final Color lc, vc;
  const _Stat(this.l, this.v, this.lc, this.vc);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: vc, fontWeight: FontWeight.bold, fontSize: 20)),
    Text(l, style: TextStyle(color: lc, fontSize: 10)),
  ]));
}

class _Div extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 32, color: Colors.white24);
}
