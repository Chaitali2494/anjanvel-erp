import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/staff_access_provider.dart' as sap;

// ── Models ────────────────────────────────────────────────────────────────────

class AttendanceStatus {
  static const present  = 'PRESENT';
  static const absent   = 'ABSENT';
  static const halfDay  = 'HALF_DAY';
  static const late     = 'LATE';
  static const leave    = 'LEAVE';
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final staffForAttendanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client
        .from('users')
        .select('id, full_name, role, avatar_url, department')
        .neq('role', 'GUEST')
        .neq('role', 'OWNER')
        .eq('is_active', true)
        .order('role')
        .order('full_name');
  } catch (_) {
    return [];
  }
});

final attendanceForDateProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, date) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final records = await client
        .from('staff_attendance')
        .select('staff_id, status, check_in_time, check_out_time, notes')
        .eq('date', date);
    // Return as map: staffId -> record
    final map = <String, dynamic>{};
    for (final r in records) {
      map[r['staff_id'] as String] = r;
    }
    return map;
  } catch (_) {
    return {};
  }
});

final attendanceSummaryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, staffId) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  try {
    final records = await client
        .from('staff_attendance')
        .select('status')
        .eq('staff_id', staffId)
        .gte('date', monthStart);
    final present  = records.where((r) => r['status'] == AttendanceStatus.present).length;
    final absent   = records.where((r) => r['status'] == AttendanceStatus.absent).length;
    final halfDay  = records.where((r) => r['status'] == AttendanceStatus.halfDay).length;
    final late     = records.where((r) => r['status'] == AttendanceStatus.late).length;
    final leave    = records.where((r) => r['status'] == AttendanceStatus.leave).length;
    return {'present': present, 'absent': absent, 'half_day': halfDay, 'late': late, 'leave': leave, 'total': records.length};
  } catch (_) {
    return {'present': 0, 'absent': 0, 'half_day': 0, 'late': 0, 'leave': 0, 'total': 0};
  }
});

// ── Status Config ─────────────────────────────────────────────────────────────

final _statusConfig = <String, Map<String, dynamic>>{
  AttendanceStatus.present:  {'label': 'Present',  'color': const Color(0xFF2E7D32), 'icon': Icons.check_circle_rounded},
  AttendanceStatus.absent:   {'label': 'Absent',   'color': const Color(0xFFE53935), 'icon': Icons.cancel_rounded},
  AttendanceStatus.halfDay:  {'label': 'Half Day', 'color': const Color(0xFFFFB300), 'icon': Icons.timelapse_rounded},
  AttendanceStatus.late:     {'label': 'Late',     'color': const Color(0xFF0277BD), 'icon': Icons.watch_later_outlined},
  AttendanceStatus.leave:    {'label': 'Leave',    'color': const Color(0xFF6A1B9A), 'icon': Icons.beach_access_outlined},
};

final _roleColors = <String, Color>{
  'MANAGER':              const Color(0xFF1565C0),
  'HOUSEKEEPING':         const Color(0xFF2E7D32),
  'KITCHEN':              const Color(0xFFE64A19),
  'ACTIVITY_COORDINATOR': const Color(0xFF00838F),
  'SHOP_OPERATOR':        const Color(0xFF6A1B9A),
  'ACCOUNTANT':           const Color(0xFF00796B),
  'GUIDE':                const Color(0xFF558B2F),
  'CA':                   const Color(0xFF4527A0),
  'CONSULTANT':           const Color(0xFF37474F),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});
  @override
  ConsumerState<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _dateKey {
    final d = ref.read(_selectedDateProvider);
    return DateFormat('yyyy-MM-dd').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(_selectedDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final staffAsync = ref.watch(staffForAttendanceProvider);
    final attendanceAsync = ref.watch(attendanceForDateProvider(dateKey));
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Staff Attendance'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(staffForAttendanceProvider);
              ref.invalidate(attendanceForDateProvider(dateKey));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Mark', icon: Icon(Icons.fact_check_outlined, size: 18)),
            Tab(text: 'Summary', icon: Icon(Icons.bar_chart_rounded, size: 18)),
            Tab(text: 'Live', icon: Icon(Icons.sensors_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Mark Attendance Tab ──
          Column(
            children: [
              // Date picker bar
              _DatePickerBar(
                selectedDate: selectedDate,
                onDateChanged: (d) => ref.read(_selectedDateProvider.notifier).state = d,
              ),

              // Attendance stats for selected date
              attendanceAsync.when(
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF37474F)))),
                error: (_, __) => const SizedBox(),
                data: (attendanceMap) {
                  final present  = attendanceMap.values.where((v) => v['status'] == AttendanceStatus.present).length;
                  final absent   = attendanceMap.values.where((v) => v['status'] == AttendanceStatus.absent).length;
                  final halfDay  = attendanceMap.values.where((v) => v['status'] == AttendanceStatus.halfDay).length;
                  final marked   = attendanceMap.length;
                  return _DayStats(present: present, absent: absent, halfDay: halfDay, marked: marked);
                },
              ),

              // Mark all present button (only for today)
              if (isToday)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : () => _markAllPresent(),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Mark All Present'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Staff list
              Expanded(
                child: staffAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF37474F))),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (staff) => attendanceAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF37474F))),
                    error: (_, __) => _StaffAttendanceList(
                      staff: staff, attendanceMap: const {}, dateKey: dateKey, onSave: _saveAttendance,
                    ),
                    data: (attendanceMap) => _StaffAttendanceList(
                      staff: staff, attendanceMap: attendanceMap, dateKey: dateKey, onSave: _saveAttendance,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Summary Tab ──
          staffAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF37474F))),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (staff) => _SummaryTab(staff: staff),
          ),

          // ── Live Sign-in Tab ──────────────────────────────────────────
          _LiveAttendanceTab(),
        ],
      ),
    );
  }

  Future<void> _markAllPresent() async {
    final staff = ref.read(staffForAttendanceProvider).value ?? [];
    if (staff.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final records = staff.map((s) => {
        'staff_id': s['id'],
        'date': _dateKey,
        'status': AttendanceStatus.present,
        'check_in_time': '09:00',
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      await client.from('staff_attendance').upsert(records, onConflict: 'staff_id,date');
      ref.invalidate(attendanceForDateProvider(_dateKey));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All staff marked as Present'), backgroundColor: Color(0xFF2E7D32)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAttendance(String staffId, String status, String? checkIn, String? checkOut, String? notes) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('staff_attendance').upsert({
        'staff_id': staffId,
        'date': _dateKey,
        'status': status,
        if (checkIn != null) 'check_in_time': checkIn,
        if (checkOut != null) 'check_out_time': checkOut,
        if (notes != null) 'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'staff_id,date');
      ref.invalidate(attendanceForDateProvider(_dateKey));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

// ── Date Picker Bar ───────────────────────────────────────────────────────────

class _DatePickerBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  const _DatePickerBar({required this.selectedDate, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) == DateFormat('yyyy-MM-dd').format(today);

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: today,
                );
                if (picked != null) onDateChanged(picked);
              },
              child: Column(
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('EEEE').format(selectedDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? const Color(0xFF2E7D32) : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('d MMMM yyyy').format(selectedDate),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                ? () => onDateChanged(selectedDate.add(const Duration(days: 1)))
                : null,
          ),
          if (!isToday)
            TextButton(
              onPressed: () => onDateChanged(today),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ── Day Stats ─────────────────────────────────────────────────────────────────

class _DayStats extends StatelessWidget {
  final int present, absent, halfDay, marked;
  const _DayStats({required this.present, required this.absent, required this.halfDay, required this.marked});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        _DS('Marked', '$marked', const Color(0xFF37474F)),
        _DD(), _DS('Present', '$present', const Color(0xFF2E7D32)),
        _DD(), _DS('Absent', '$absent', AppTheme.error),
        _DD(), _DS('Half Day', '$halfDay', AppTheme.warning),
      ]),
    );
  }
}
class _DS extends StatelessWidget {
  final String l, v; final Color c;
  const _DS(this.l, this.v, this.c);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: c)),
    Text(l, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
  ]));
}
class _DD extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 32, color: Colors.grey.shade200);
}

// ── Staff Attendance List ─────────────────────────────────────────────────────

class _StaffAttendanceList extends StatelessWidget {
  final List<Map<String, dynamic>> staff;
  final Map<String, dynamic> attendanceMap;
  final String dateKey;
  final Future<void> Function(String, String, String?, String?, String?) onSave;

  const _StaffAttendanceList({
    required this.staff, required this.attendanceMap,
    required this.dateKey, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const EmptyState(title: 'No Staff Found', subtitle: 'Add staff members to mark attendance', icon: Icons.people_outline);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: staff.length,
      itemBuilder: (_, i) {
        final s = staff[i];
        final id = s['id'] as String;
        final record = attendanceMap[id] as Map<String, dynamic>?;
        final status = record?['status'] as String?;
        return _AttendanceTile(
          staff: s,
          status: status,
          checkIn: record?['check_in_time'] as String?,
          checkOut: record?['check_out_time'] as String?,
          onTap: () => _showMarkSheet(context, s, status, record, onSave),
        );
      },
    );
  }

  void _showMarkSheet(
    BuildContext context,
    Map<String, dynamic> staff,
    String? currentStatus,
    Map<String, dynamic>? record,
    Future<void> Function(String, String, String?, String?, String?) onSave,
  ) {
    String selected = currentStatus ?? AttendanceStatus.present;
    final checkInCtrl  = TextEditingController(text: record?['check_in_time'] as String? ?? '09:00');
    final checkOutCtrl = TextEditingController(text: record?['check_out_time'] as String? ?? '18:00');
    final notesCtrl    = TextEditingController(text: record?['notes'] as String? ?? '');
    final role = staff['role'] as String? ?? '';
    final color = _roleColors[role] ?? AppTheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text((staff['full_name'] as String? ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff['full_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(role.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                  ],
                )),
              ]),
              const SizedBox(height: 20),

              // Status buttons
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusConfig.entries.map((e) {
                  final isSelected = selected == e.key;
                  final color = e.value['color'] as Color;
                  return GestureDetector(
                    onTap: () => setModal(() => selected = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(e.value['icon'] as IconData, size: 14,
                            color: isSelected ? Colors.white : color),
                        const SizedBox(width: 4),
                        Text(e.value['label'] as String,
                            style: TextStyle(color: isSelected ? Colors.white : color,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Time fields (only for non-absent/leave)
              if (selected != AttendanceStatus.absent && selected != AttendanceStatus.leave) ...[
                Row(children: [
                  Expanded(child: TextField(
                    controller: checkInCtrl,
                    decoration: const InputDecoration(labelText: 'Check-in Time', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.login_rounded, size: 18)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: checkOutCtrl,
                    decoration: const InputDecoration(labelText: 'Check-out Time', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.logout_rounded, size: 18)),
                  )),
                ]),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_outlined, size: 18)),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  await onSave(
                    staff['id'] as String,
                    selected,
                    selected != AttendanceStatus.absent && selected != AttendanceStatus.leave ? checkInCtrl.text : null,
                    selected != AttendanceStatus.absent && selected != AttendanceStatus.leave ? checkOutCtrl.text : null,
                    notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF37474F),
                    minimumSize: const Size(double.infinity, 48)),
                child: const Text('Save Attendance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Attendance Tile ───────────────────────────────────────────────────────────

class _AttendanceTile extends StatelessWidget {
  final Map<String, dynamic> staff;
  final String? status, checkIn, checkOut;
  final VoidCallback onTap;
  const _AttendanceTile({required this.staff, this.status, this.checkIn, this.checkOut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = staff['role'] as String? ?? '';
    final color = _roleColors[role] ?? AppTheme.primary;
    final cfg = _statusConfig[status];
    final statusColor = cfg?['color'] as Color? ?? Colors.grey.shade300;
    final statusLabel = cfg?['label'] as String? ?? 'Not Marked';
    final statusIcon = cfg?['icon'] as IconData? ?? Icons.radio_button_unchecked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: status != null
              ? Border.all(color: statusColor.withOpacity(0.3))
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.12),
              child: Text(
                (staff['full_name'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff['full_name'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(role.replaceAll('_', ' '),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                  if (status != null && checkIn != null)
                    Text('In: $checkIn${checkOut != null ? '  Out: $checkOut' : ''}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                ],
              ),
            ),
            // Status badge
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  final List<Map<String, dynamic>> staff;
  const _SummaryTab({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = DateFormat('MMMM yyyy').format(DateTime.now());
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surface,
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: Color(0xFF37474F)),
              const SizedBox(width: 8),
              Text('Monthly Summary — $month',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        Expanded(
          child: staff.isEmpty
              ? const EmptyState(title: 'No Staff', subtitle: 'Staff members will appear here', icon: Icons.people_outline)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staff.length,
                  itemBuilder: (_, i) => _SummaryTile(staffMember: staff[i]),
                ),
        ),
      ],
    );
  }
}

class _SummaryTile extends ConsumerWidget {
  final Map<String, dynamic> staffMember;
  const _SummaryTile({required this.staffMember});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = staffMember['id'] as String;
    final role = staffMember['role'] as String? ?? '';
    final color = _roleColors[role] ?? AppTheme.primary;
    final summaryAsync = ref.watch(attendanceSummaryProvider(id));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Text((staffMember['full_name'] as String? ?? '?')[0].toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(staffMember['full_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(role.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
            ])),
            summaryAsync.when(
              loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox(),
              data: (s) {
                final total = s['total'] as int;
                final present = s['present'] as int;
                final pct = total > 0 ? (present / total * 100).toStringAsFixed(0) : '0';
                final color = int.tryParse(pct) != null
                    ? (int.parse(pct) >= 80 ? AppTheme.success : int.parse(pct) >= 60 ? AppTheme.warning : AppTheme.error)
                    : AppTheme.textHint;
                return Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color));
              },
            ),
          ]),
          const SizedBox(height: 10),
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
            data: (s) {
              final present  = s['present'] as int;
              final absent   = s['absent'] as int;
              final halfDay  = s['half_day'] as int;
              final late     = s['late'] as int;
              final leave    = s['leave'] as int;
              return Row(children: [
                _SumBadge('P', '$present', const Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                _SumBadge('A', '$absent', AppTheme.error),
                const SizedBox(width: 6),
                _SumBadge('H', '$halfDay', AppTheme.warning),
                const SizedBox(width: 6),
                _SumBadge('L', '$late', const Color(0xFF0277BD)),
                const SizedBox(width: 6),
                _SumBadge('Lv', '$leave', const Color(0xFF6A1B9A)),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _SumBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── Live Attendance Tab (session-based sign-in/out) ────────────────────────────

class _LiveAttendanceTab extends ConsumerWidget {
  const _LiveAttendanceTab();

  static const _deptColors = <String, Color>{
    'Housekeeping': Color(0xFF6A1B9A),
    'Kitchen':      Color(0xFFE64A19),
    'Reception':    Color(0xFF1565C0),
    'Activities':   Color(0xFF00838F),
    'Tour Guide':   Color(0xFF2E7D32),
    'Security':     Color(0xFF37474F),
    'Maintenance':  Color(0xFFF57C00),
    'Shop':         Color(0xFF558B2F),
    'Management':   Color(0xFF880E4F),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList  = ref.watch(sap.staffAccessProvider);
    final leaveList  = ref.watch(sap.leaveProvider);
    final today      = DateTime.now().toIso8601String().substring(0, 10);

    final signedIn   = staffList.where((s) => s['is_signed_in'] == true).length;
    final onLeave    = leaveList.where((l) =>
        l['date'] == today && l['status'] == 'APPROVED').length;
    final absent     = staffList.where((s) =>
        s['is_active'] == true && s['is_signed_in'] == false).length - onLeave;

    return Column(children: [
      // Stats bar
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          _LiveStat('Signed In',  '$signedIn',     AppTheme.success),
          _LiveStat('Absent',     '${absent < 0 ? 0 : absent}', AppTheme.error),
          _LiveStat('On Leave',   '$onLeave',      const Color(0xFF6A1B9A)),
          _LiveStat('Total',      '${staffList.where((s) => s['is_active'] == true).length}', AppTheme.primary),
        ]),
      ),
      const Divider(height: 0),

      // Staff list
      Expanded(
        child: staffList.isEmpty
            ? const Center(child: Text('No staff added yet.\nGo to Staff Access to add staff.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textPrimary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: staffList.where((s) => s['is_active'] == true).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final active = staffList.where((s) => s['is_active'] == true).toList();
                  final s = active[i];
                  final isSignedIn   = s['is_signed_in'] as bool;
                  final dept         = s['department'] as String;
                  final dColor       = _deptColors[dept] ?? AppTheme.primary;
                  final signInTime   = s['sign_in_time']  as String?;
                  final signOutTime  = s['sign_out_time'] as String?;
                  final hasLeave     = leaveList.any((l) =>
                      l['staff_id'] == s['id'] &&
                      l['date'] == today &&
                      l['status'] == 'APPROVED');

                  Color statusColor;
                  String statusLabel;
                  IconData statusIcon;

                  if (hasLeave) {
                    statusColor = const Color(0xFF6A1B9A);
                    statusLabel = 'On Leave';
                    statusIcon  = Icons.beach_access_outlined;
                  } else if (isSignedIn) {
                    statusColor = AppTheme.success;
                    statusLabel = 'Present';
                    statusIcon  = Icons.check_circle_rounded;
                  } else if (signOutTime != null) {
                    statusColor = AppTheme.info;
                    statusLabel = 'Signed Out';
                    statusIcon  = Icons.logout_rounded;
                  } else {
                    statusColor = AppTheme.error;
                    statusLabel = 'Absent';
                    statusIcon  = Icons.cancel_outlined;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        // Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: dColor.withOpacity(0.12),
                          child: Text(
                            (s['name'] as String).substring(0, 1).toUpperCase(),
                            style: TextStyle(color: dColor,
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + dept
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(dept,
                              style: TextStyle(fontSize: 11, color: dColor)),
                          if (signInTime != null)
                            Text('In: $signInTime${signOutTime != null ? '  Out: $signOutTime' : ''}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textPrimary)),
                        ])),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _LiveStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LiveStat(this.label, this.value, this.color);
  @override
  Widget build(_) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
    ]),
  );
}
