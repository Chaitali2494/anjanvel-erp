import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Saves app data that used to live only in browser memory into the Supabase
/// table `app_records`, so it survives a page refresh and is shared live
/// between devices (e.g. an order entered at reception shows up instantly on
/// the kitchen's phone).
///
/// Each record belongs to a `collection` ('food_orders', 'guest_requests', …)
/// and has a string `id`. The record itself is stored as JSON in `data`.
///
/// Every call is best-effort: if Supabase is unreachable the app keeps
/// working from memory exactly as before.
class CloudStore {
  CloudStore._();

  static const _table = 'app_records';
  static int _channelSeq = 0;

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// All live (non-deleted) records in a collection, oldest first.
  static Future<List<Map<String, dynamic>>> load(String collection) async {
    final c = _client;
    if (c == null) return const [];
    try {
      final rows = await c
          .from(_table)
          .select('id, data, deleted')
          .eq('collection', collection)
          .order('updated_at', ascending: true);
      final out = <Map<String, dynamic>>[];
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        if (m['deleted'] == true) continue;
        out.add(_withId(m['id'].toString(), m['data']));
      }
      return out;
    } catch (e) {
      debugPrint('CloudStore.load($collection) failed: $e');
      return const [];
    }
  }

  /// Insert or update one record.
  static Future<void> put(String collection, String id, Map<String, dynamic> data) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.from(_table).upsert({
        'collection': collection,
        'id': id,
        'data': _jsonSafe(data),
        'deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'collection,id');
    } catch (e) {
      debugPrint('CloudStore.put($collection/$id) failed: $e');
    }
  }

  /// Mark a record as deleted.
  static Future<void> remove(String collection, String id) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.from(_table).upsert({
        'collection': collection,
        'id': id,
        'data': <String, dynamic>{},
        'deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'collection,id');
    } catch (e) {
      debugPrint('CloudStore.remove($collection/$id) failed: $e');
    }
  }

  /// Listen for records added/changed on any device. Returns a cancel function.
  static void Function() watch(
    String collection,
    void Function(String id, Map<String, dynamic> data, bool deleted) onChange,
  ) {
    final c = _client;
    if (c == null) return () {};
    try {
      final channel = c
          .channel('app_records_${collection}_${_channelSeq++}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'collection',
              value: collection,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isEmpty || rec['id'] == null) return;
              final id = rec['id'].toString();
              onChange(id, _withId(id, rec['data']), rec['deleted'] == true);
            },
          )
          .subscribe();
      return () {
        try {
          c.removeChannel(channel);
        } catch (_) {}
      };
    } catch (e) {
      debugPrint('CloudStore.watch($collection) failed: $e');
      return () {};
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _withId(String id, dynamic data) {
    Map<String, dynamic> m = {};
    if (data is Map) {
      m = Map<String, dynamic>.from(data);
    } else if (data is String && data.isNotEmpty) {
      try {
        m = Map<String, dynamic>.from(jsonDecode(data) as Map);
      } catch (_) {}
    }
    return {...m, 'id': m['id'] ?? id};
  }

  /// Make sure the value can be stored as JSON (DateTime → ISO string, etc.).
  static dynamic _jsonSafe(dynamic v) {
    if (v == null || v is String || v is num || v is bool) return v;
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is Iterable) return v.map(_jsonSafe).toList();
    return v.toString();
  }
}
