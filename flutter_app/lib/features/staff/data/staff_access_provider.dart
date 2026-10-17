import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Department list ───────────────────────────────────────────────────────────

const kDepartments = [
  'Housekeeping',
  'Kitchen',
  'Reception',
  'Activities',
  'Tour Guide',
  'Security',
  'Maintenance',
  'Shop',
  'Management',
];

// ── Module-level session data ─────────────────────────────────────────────────

List<Map<String, dynamic>> _sessionStaff = [
  {
    'id': 'ST001', 'name': 'Ravi Desai',   'mobile': '9876543210', 'pin': '1234',
    'department': 'Housekeeping', 'role': 'HOUSEKEEPING', 'is_active': true,
    'is_signed_in': false, 'sign_in_time': null, 'sign_out_time': null,
  },
  {
    'id': 'ST002', 'name': 'Sunita Pawar', 'mobile': '9123456780', 'pin': '5678',
    'department': 'Kitchen',      'role': 'KITCHEN',      'is_active': true,
    'is_signed_in': false, 'sign_in_time': null, 'sign_out_time': null,
  },
  {
    'id': 'ST003', 'name': 'Arjun More',   'mobile': '9988776655', 'pin': '0000',
    'department': 'Activities',   'role': 'ACTIVITY_COORDINATOR', 'is_active': true,
    'is_signed_in': false, 'sign_in_time': null, 'sign_out_time': null,
  },
  {
    'id': 'ST004', 'name': 'Kavya Joshi',  'mobile': '9001122334', 'pin': '4321',
    'department': 'Reception',    'role': 'RECEPTION',    'is_active': true,
    'is_signed_in': false, 'sign_in_time': null, 'sign_out_time': null,
  },
];

// attendance: {date: [{staff_id, name, dept, sign_in, sign_out, status}]}
Map<String, List<Map<String, dynamic>>> _sessionAttendance = {};

// leave requests
List<Map<String, dynamic>> _sessionLeaves = [];

String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);
String _nowTime() {
  final n = DateTime.now();
  final h = n.hour > 12 ? n.hour - 12 : (n.hour == 0 ? 12 : n.hour);
  final m = n.minute.toString().padLeft(2, '0');
  final ampm = n.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

// ── Staff notifier ────────────────────────────────────────────────────────────

class StaffAccessNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  StaffAccessNotifier() : super(_sessionStaff);

  // ── Add a new staff member ────────────────────────────────────────────────
  void addStaff({
    required String name,
    required String mobile,
    required String pin,
    required String department,
    required String role,
  }) {
    final id = 'ST${DateTime.now().millisecondsSinceEpoch}';
    _sessionStaff = [
      ..._sessionStaff,
      {
        'id': id, 'name': name, 'mobile': mobile, 'pin': pin,
        'department': department, 'role': role, 'is_active': true,
        'is_signed_in': false, 'sign_in_time': null, 'sign_out_time': null,
      },
    ];
    state = List<Map<String, dynamic>>.from(_sessionStaff);
  }

  // ── Toggle active/inactive ────────────────────────────────────────────────
  void toggleActive(String id) {
    _sessionStaff = _sessionStaff.map((s) {
      if (s['id'] == id) return {...s, 'is_active': !(s['is_active'] as bool)};
      return s;
    }).toList();
    state = List<Map<String, dynamic>>.from(_sessionStaff);
  }

  // ── Sign in ───────────────────────────────────────────────────────────────
  void signIn(String id) {
    final now = _nowTime();
    _sessionStaff = _sessionStaff.map((s) {
      if (s['id'] == id) {
        return {...s, 'is_signed_in': true, 'sign_in_time': now, 'sign_out_time': null};
      }
      return s;
    }).toList();
    state = List<Map<String, dynamic>>.from(_sessionStaff);
    _recordAttendance(id, 'PRESENT', now, null);
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  void signOut(String id) {
    final now = _nowTime();
    _sessionStaff = _sessionStaff.map((s) {
      if (s['id'] == id) {
        return {...s, 'is_signed_in': false, 'sign_out_time': now};
      }
      return s;
    }).toList();
    state = List<Map<String, dynamic>>.from(_sessionStaff);
    _updateAttendanceSignOut(id, now);
  }

  void _recordAttendance(String id, String status, String signIn, String? signOut) {
    final today = _todayStr();
    final staff = _sessionStaff.firstWhere((s) => s['id'] == id, orElse: () => {});
    if (staff.isEmpty) return;
    final existing = List<Map<String, dynamic>>.from(
        _sessionAttendance[today] ?? []);
    existing.removeWhere((r) => r['staff_id'] == id);
    existing.add({
      'staff_id': id,
      'name': staff['name'],
      'department': staff['department'],
      'sign_in': signIn,
      'sign_out': signOut,
      'status': status,
      'date': today,
    });
    _sessionAttendance[today] = existing;
  }

  void _updateAttendanceSignOut(String id, String signOut) {
    final today = _todayStr();
    final list = List<Map<String, dynamic>>.from(
        _sessionAttendance[today] ?? []);
    _sessionAttendance[today] = list.map((r) {
      if (r['staff_id'] == id) return {...r, 'sign_out': signOut};
      return r;
    }).toList();
  }

  // ── Verify login ──────────────────────────────────────────────────────────
  Map<String, dynamic>? login(String mobile, String pin) {
    try {
      return _sessionStaff.firstWhere(
        (s) => s['mobile'] == mobile && s['pin'] == pin && s['is_active'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

final staffAccessProvider =
    StateNotifierProvider<StaffAccessNotifier, List<Map<String, dynamic>>>(
        (_) => StaffAccessNotifier());

// ── Attendance provider ───────────────────────────────────────────────────────

class AttendanceNotifier
    extends StateNotifier<Map<String, List<Map<String, dynamic>>>> {
  AttendanceNotifier() : super(_sessionAttendance);

  void refresh() {
    state = Map<String, List<Map<String, dynamic>>>.from(_sessionAttendance);
  }

  List<Map<String, dynamic>> forDate(String date) =>
      _sessionAttendance[date] ?? [];
}

final staffAttendanceStateProvider = StateNotifierProvider<AttendanceNotifier,
    Map<String, List<Map<String, dynamic>>>>((ref) {
  // re-sync whenever staff changes
  ref.watch(staffAccessProvider);
  return AttendanceNotifier();
});

// ── Leave provider ────────────────────────────────────────────────────────────

class LeaveNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  LeaveNotifier() : super(_sessionLeaves);

  void apply({
    required String staffId,
    required String staffName,
    required String department,
    required String date,
    required String reason,
  }) {
    final id = 'LV${DateTime.now().millisecondsSinceEpoch}';
    _sessionLeaves = [
      {
        'id': id,
        'staff_id': staffId,
        'staff_name': staffName,
        'department': department,
        'date': date,
        'reason': reason,
        'status': 'PENDING',
        'applied_at': DateTime.now().toIso8601String(),
        'approved_by': null,
      },
      ..._sessionLeaves,
    ];
    state = List<Map<String, dynamic>>.from(_sessionLeaves);
  }

  void approve(String id, String approvedBy) {
    _sessionLeaves = _sessionLeaves.map((l) {
      if (l['id'] == id) {
        return {...l, 'status': 'APPROVED', 'approved_by': approvedBy};
      }
      return l;
    }).toList();
    state = List<Map<String, dynamic>>.from(_sessionLeaves);
    // Mark attendance as LEAVE for that date
    final leave = _sessionLeaves.firstWhere((l) => l['id'] == id);
    final date  = leave['date'] as String;
    final staffId = leave['staff_id'] as String;
    final list  = List<Map<String, dynamic>>.from(_sessionAttendance[date] ?? []);
    list.removeWhere((r) => r['staff_id'] == staffId);
    list.add({
      'staff_id': staffId,
      'name': leave['staff_name'],
      'department': leave['department'],
      'sign_in': null,
      'sign_out': null,
      'status': 'LEAVE',
      'date': date,
    });
    _sessionAttendance[date] = list;
  }

  void reject(String id) {
    _sessionLeaves = _sessionLeaves.map((l) {
      if (l['id'] == id) return {...l, 'status': 'REJECTED'};
      return l;
    }).toList();
    state = List<Map<String, dynamic>>.from(_sessionLeaves);
  }

  List<Map<String, dynamic>> forStaff(String staffId) =>
      _sessionLeaves.where((l) => l['staff_id'] == staffId).toList();
}

final leaveProvider =
    StateNotifierProvider<LeaveNotifier, List<Map<String, dynamic>>>(
        (_) => LeaveNotifier());
