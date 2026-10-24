import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/cloud_store.dart';

// ── Demo seed data ─────────────────────────────────────────────────────────────

final _demoTasks = <Map<String, dynamic>>[
  {'id': 'd1', 'room_number': '101', 'task_type': 'CHECKOUT_CLEAN', 'status': 'PENDING',    'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest checked out at 11 AM'},
  {'id': 'd2', 'room_number': '102', 'task_type': 'REGULAR_CLEAN',  'status': 'IN_PROGRESS','priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': ''},
  {'id': 'd3', 'room_number': '205', 'task_type': 'DEEP_CLEAN',     'status': 'PENDING',    'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest requested deep clean'},
  {'id': 'd4', 'room_number': '103', 'task_type': 'LINEN_CHANGE',   'status': 'COMPLETED',  'priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': ''},
  {'id': 'd5', 'room_number': '201', 'task_type': 'REGULAR_CLEAN',  'status': 'PENDING',    'priority': 'LOW',    'assigned_to': 'Priya T.',   'notes': 'Do after 3 PM'},
  {'id': 'd6', 'room_number': '301', 'task_type': 'TURNDOWN',       'status': 'PENDING',    'priority': 'NORMAL', 'assigned_to': 'Priya T.',   'notes': ''},
];

// ── Module-level shared state ──────────────────────────────────────────────────
// Lives outside the provider so it survives provider recreation during navigation.
// Resets only when the browser tab is closed / page fully reloaded.

List<Map<String, dynamic>> _sessionTasks = List<Map<String, dynamic>>.from(
  _demoTasks.map((e) => Map<String, dynamic>.from(e)),
);

// ── StateNotifier ──────────────────────────────────────────────────────────────

class HousekeepingTasksNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  // Tasks are stored in Supabase `app_records` (collection 'housekeeping_tasks')
  // via CloudStore — the structured housekeeping_tasks table needs room/user
  // UUIDs the app doesn't have, which caused 400 errors.
  static const _cloud = 'housekeeping_tasks';
  void Function()? _cancelCloud;

  HousekeepingTasksNotifier(SupabaseClient _) : super(const AsyncValue.loading()) {
    _load();
    _cancelCloud = CloudStore.watch(_cloud, (id, data, deleted) {
      if (deleted) {
        _sessionTasks = _sessionTasks.where((t) => t['id']?.toString() != id).toList();
        _emit();
      } else {
        _applyRemote([data]);
      }
    });
  }

  @override
  void dispose() {
    _cancelCloud?.call();
    super.dispose();
  }

  void _emit() {
    if (mounted) {
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));
    }
  }

  void _applyRemote(List<Map<String, dynamic>> remote) {
    for (final r in remote) {
      final idx = _sessionTasks.indexWhere((t) => t['id']?.toString() == r['id']?.toString());
      if (idx >= 0) {
        _sessionTasks[idx] = r;
      } else {
        _sessionTasks.insert(0, r);
      }
    }
    _emit();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    _applyRemote(await CloudStore.load(_cloud));
  }

  Future<void> refresh() => _load();

  // ── Add task (called from Assign Task form) ────────────────────────────────

  Future<void> addTask(Map<String, dynamic> task) async {
    final now = DateTime.now().toIso8601String();
    final newTask = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'created_at': now,
      'updated_at': now,
      ...task,
    };
    _sessionTasks = <Map<String, dynamic>>[newTask, ..._sessionTasks];
    _emit();
    await CloudStore.put(_cloud, newTask['id'].toString(), newTask);
  }

  // ── Update status (called from HK task list & cleaning checklist) ────────────

  Future<void> updateStatus(String id, String status) async {
    Map<String, dynamic>? changed;
    _sessionTasks = _sessionTasks.map((t) {
      if (t['id']?.toString() == id) {
        changed = <String, dynamic>{
          ...t,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        };
        return changed!;
      }
      return t;
    }).toList();
    _emit();
    if (changed != null) {
      await CloudStore.put(_cloud, id, changed!);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final housekeepingTasksProvider = StateNotifierProvider<
    HousekeepingTasksNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return HousekeepingTasksNotifier(client);
});
