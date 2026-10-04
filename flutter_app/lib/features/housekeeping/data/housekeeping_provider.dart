import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

// ── Shared provider — used by HK dashboard, Owner, Manager ────────────────────

final housekeepingTasksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client
        .from('housekeeping_tasks')
        .select('*')
        .order('created_at', ascending: false);
  } catch (_) {
    return _demoTasks;
  }
});

const _demoTasks = [
  {'id': '1', 'room_number': '101', 'task_type': 'CHECKOUT_CLEAN', 'status': 'PENDING',    'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest checked out at 11 AM'},
  {'id': '2', 'room_number': '102', 'task_type': 'REGULAR_CLEAN',  'status': 'IN_PROGRESS','priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': ''},
  {'id': '3', 'room_number': '205', 'task_type': 'DEEP_CLEAN',     'status': 'PENDING',    'priority': 'HIGH',   'assigned_to': 'Savita K.',  'notes': 'Guest requested deep clean'},
  {'id': '4', 'room_number': '103', 'task_type': 'LINEN_CHANGE',   'status': 'COMPLETED',  'priority': 'NORMAL', 'assigned_to': 'Meena S.',   'notes': ''},
  {'id': '5', 'room_number': '201', 'task_type': 'REGULAR_CLEAN',  'status': 'PENDING',    'priority': 'LOW',    'assigned_to': 'Priya T.',   'notes': 'Do after 3 PM'},
  {'id': '6', 'room_number': '301', 'task_type': 'TURNDOWN',       'status': 'PENDING',    'priority': 'NORMAL', 'assigned_to': 'Priya T.',   'notes': ''},
];
