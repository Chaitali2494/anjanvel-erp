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

// ── StateNotifier — works in both Supabase mode and demo/offline mode ──────────

class HousekeepingTasksNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final SupabaseClient _client;

  /// In-memory list used when Supabase table doesn't exist (demo mode).
  late List<Map<String, dynamic>> _localTasks;
  bool _useLocal = false;

  HousekeepingTasksNotifier(this._client)
      : super(const AsyncValue.loading()) {
    _localTasks = List<Map<String, dynamic>>.from(
      _demoTasks.map((e) => Map<String, dynamic>.from(e)),
    );
    _load();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final data = await _client
          .from('housekeeping_tasks')
          .select('*')
          .order('created_at', ascending: false);
      _useLocal = false;
      state = AsyncValue.data(
        (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (_) {
      _useLocal = true;
      state = AsyncValue.data(
        List<Map<String, dynamic>>.from(_localTasks),
      );
    }
  }

  Future<void> refresh() => _load();

  // ── Add task (called from Assign Task form) ────────────────────────────────

  Future<void> addTask(Map<String, dynamic> task) async {
    if (_useLocal) {
      // Demo / offline — prepend to in-memory list so it shows instantly.
      final newTask = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        ...task,
      };
      _localTasks = <Map<String, dynamic>>[newTask, ..._localTasks];
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_localTasks));
    } else {
      try {
        await _client.from('housekeeping_tasks').insert(<String, dynamic>{
          ...task,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        await _load();
      } catch (_) {
        // If live insert fails, fall back to local
        _useLocal = true;
        final newTask = <String, dynamic>{
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          ...task,
        };
        _localTasks = <Map<String, dynamic>>[newTask, ..._localTasks];
        state = AsyncValue.data(List<Map<String, dynamic>>.from(_localTasks));
      }
    }
  }

  // ── Update task status (called from HK task list) ──────────────────────────

  Future<void> updateStatus(String id, String status) async {
    if (_useLocal) {
      _localTasks = _localTasks.map((t) {
        if (t['id'] == id) {
          return <String, dynamic>{
            ...t,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }
        return t;
      }).toList();
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_localTasks));
    } else {
      try {
        await _client
            .from('housekeeping_tasks')
            .update(<String, dynamic>{
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
        await _load();
      } catch (_) {}
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
