import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guest_sync.dart';
import '../../../core/services/cloud_store.dart';

const _cloudRequests = 'guest_requests';
const _cloudDnd = 'room_dnd';

// ── Request types ──────────────────────────────────────────────────────────────

enum GuestRequestType {
  housekeeping,
  maintenance,
  activity,
  dnd,
  general,
}

// ── Session-persistent guest requests ─────────────────────────────────────────

final List<Map<String, dynamic>> _sessionRequests = [];
final Map<String, bool> _dndByRoom = {};

class GuestRequestsNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  void Function()? _cancelListener;

  GuestRequestsNotifier() : super(List.from(_sessionRequests)) {
    // Merge any requests from localStorage (placed in another tab / prev session)
    _mergeFromStorage();
    // Listen for new requests broadcast by the guest portal tab
    _cancelListener = GuestSync.listenForRequests((req) {
      if (!_sessionRequests.any((r) => r['id'] == req['id'])) {
        _sessionRequests.insert(0, req);
        state = List.from(_sessionRequests);
      }
    });
    _initCloud();
  }

  void Function()? _cancelCloud;

  Future<void> _initCloud() async {
    _applyRemote(await CloudStore.load(_cloudRequests));
    _cancelCloud = CloudStore.watch(_cloudRequests, (id, data, deleted) {
      if (deleted) {
        _sessionRequests.removeWhere((r) => r['id']?.toString() == id);
        if (mounted) state = List.from(_sessionRequests);
      } else {
        _applyRemote([data]);
      }
    });
  }

  void _applyRemote(List<Map<String, dynamic>> remote) {
    if (remote.isEmpty) return;
    for (final r in remote) {
      final idx = _sessionRequests.indexWhere((s) => s['id']?.toString() == r['id']?.toString());
      if (idx >= 0) {
        _sessionRequests[idx] = r;
      } else {
        _sessionRequests.insert(0, r);
      }
    }
    if (mounted) state = List.from(_sessionRequests);
  }

  void _save(Map<String, dynamic> req) =>
      CloudStore.put(_cloudRequests, req['id'].toString(), req);

  @override
  void dispose() {
    _cancelListener?.call();
    _cancelCloud?.call();
    super.dispose();
  }

  void _mergeFromStorage() {
    try {
      final stored = GuestSync.loadRequests();
      bool changed = false;
      for (final r in stored) {
        if (!_sessionRequests.any((s) => s['id'] == r['id'])) {
          _sessionRequests.insert(0, r);
          changed = true;
        }
      }
      if (changed) state = List.from(_sessionRequests);
    } catch (_) {}
  }

  void addRequest({
    required String roomNumber,
    required String type,        // 'HOUSEKEEPING' | 'MAINTENANCE' | 'ACTIVITY' | 'GENERAL'
    required String subType,     // e.g. 'CLEAN_ROOM', 'AC_ISSUE', 'WIFI_ISSUE'
    required String title,
    String? note,
    String? source,              // 'GUEST_QR' when placed from guest portal
  }) {
    final req = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'room_number': roomNumber,
      'type': type,
      'sub_type': subType,
      'title': title,
      'note': note ?? '',
      'status': 'PENDING',
      'source': source,
      'requested_at': DateTime.now().toIso8601String(),
      'assigned_to': null,
    };
    _sessionRequests.insert(0, req);
    state = List.from(_sessionRequests);
    _save(req);
    // Persist + broadcast so the management app tab picks it up immediately
    if (source == 'GUEST_QR') {
      GuestSync.saveRequest(req);
    }
  }

  void updateStatus(String id, String newStatus, {String? assignedTo}) {
    final idx = _sessionRequests.indexWhere((r) => r['id'] == id);
    if (idx >= 0) {
      _sessionRequests[idx] = {
        ..._sessionRequests[idx],
        'status': newStatus,
        if (assignedTo != null) 'assigned_to': assignedTo,
      };
      state = List.from(_sessionRequests);
      _save(_sessionRequests[idx]);
    }
  }

  void assignTo(String id, String staffName) {
    updateStatus(id, 'IN_PROGRESS', assignedTo: staffName);
  }

  List<Map<String, dynamic>> forRoom(String roomNumber) =>
      _sessionRequests.where((r) => r['room_number'] == roomNumber).toList();

  List<Map<String, dynamic>> ofType(String type) =>
      _sessionRequests.where((r) => r['type'] == type).toList();

  List<Map<String, dynamic>> pending() =>
      _sessionRequests.where((r) => r['status'] == 'PENDING').toList();
}

final guestRequestsProvider =
    StateNotifierProvider<GuestRequestsNotifier, List<Map<String, dynamic>>>(
        (ref) => GuestRequestsNotifier());

// ── DND (Do Not Disturb) per room ─────────────────────────────────────────────

class DndNotifier extends StateNotifier<Map<String, bool>> {
  DndNotifier() : super(Map.from(_dndByRoom)) {
    _initCloud();
  }

  void Function()? _cancelCloud;

  Future<void> _initCloud() async {
    for (final r in await CloudStore.load(_cloudDnd)) {
      _dndByRoom[r['id'].toString()] = r['on'] == true;
    }
    if (mounted) state = Map.from(_dndByRoom);
    _cancelCloud = CloudStore.watch(_cloudDnd, (id, data, deleted) {
      _dndByRoom[id] = !deleted && data['on'] == true;
      if (mounted) state = Map.from(_dndByRoom);
    });
  }

  @override
  void dispose() {
    _cancelCloud?.call();
    super.dispose();
  }

  void toggle(String roomNumber) {
    set(roomNumber, !(_dndByRoom[roomNumber] ?? false));
  }

  void set(String roomNumber, bool value) {
    _dndByRoom[roomNumber] = value;
    state = Map.from(_dndByRoom);
    CloudStore.put(_cloudDnd, roomNumber, {'on': value});
  }

  bool isDnd(String roomNumber) => _dndByRoom[roomNumber] ?? false;
}

final dndProvider =
    StateNotifierProvider<DndNotifier, Map<String, bool>>(
        (ref) => DndNotifier());
