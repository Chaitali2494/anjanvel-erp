import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

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
bool _sessionUseLocal = false;

// ── StateNotifier ──────────────────────────────────────────────────────────────

class HousekeepingTasksNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final SupabaseClient _client;

  HousekeepingTasksNotifier(this._client) : super(const AsyncValue.loading()) {
    _load();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final data = await _client
          .from('housekeeping_tasks')
          .select('*')
          .order('created_at', ascending: false);
      _sessionUseLocal = false;
      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _sessionTasks = list;
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));
    } catch (_) {
      // No table yet → use the shared session list (persists across navigations)
      _sessionUseLocal = true;
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));
    }
  }

  Future<void> refresh() => _load();

  // ── Add task (called from Assign Task form) ────────────────────────────────

  Future<void> addTask(Map<String, dynamic> task) async {
    if (_sessionUseLocal) {
      final newTask = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        ...task,
      };
      _sessionTasks = <Map<String, dynamic>>[newTask, ..._sessionTasks];
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));
    } else {
      try {
        await _client.from('housekeeping_tasks').insert(<String, dynamic>{
          ...task,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        await _load();
      } catch (_) {
        // Live insert failed — fall back to local
        _sessionUseLocal = true;
        final newTask = <String, dynamic>{
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          ...task,
        };
        _sessionTasks = <Map<String, dynamic>>[newTask, ..._sessionTasks];
        state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));
      }
    }
  }

  // ── Update status (called from HK task list & cleaning checklist) ────────────

  Future<void> updateStatus(String id, String status) async {
    // Always update local state immediately (works for both demo and Supabase tasks)
    _sessionTasks = _sessionTasks.map((t) {
      if (t['id'] == id) {
        return <String, dynamic>{
          ...t,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
      return t;
    }).toList();
    state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionTasks));

    // Also persist to Supabase — but only if ID is a real UUID (not a local timestamp)
    if (!_sessionUseLocal && _isUuid(id)) {
      try {
        await _client
            .from('housekeeping_tasks')
            .update(<String, dynamic>{
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      } catch (_) {}
    }
  }

  static bool _isUuid(String id) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(id);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final housekeepingTasksProvider = StateNotifierProvider<
    HousekeepingTasksNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return HousekeepingTasksNotifier(client);
});
