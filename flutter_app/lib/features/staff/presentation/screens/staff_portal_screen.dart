import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/staff_access_provider.dart';

// ── Logged-in staff state (session) ──────────────────────────────────────────

Map<String, dynamic>? _loggedInStaff;

class StaffPortalScreen extends ConsumerStatefulWidget {
  const StaffPortalScreen({super.key});

  @override
  ConsumerState<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends ConsumerState<StaffPortalScreen> {
  final _mobileCtrl = TextEditingController();
  final _pinCtrl    = TextEditingController();
  bool _loading     = false;
  String? _error;
  Map<String, dynamic>? _staff;

  @override
  void initState() {
    super.initState();
    // Restore logged-in staff if session exists
    if (_loggedInStaff != null) {
      _staff = _loggedInStaff;
    }
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _login() {
    setState(() { _loading = true; _error = null; });
    final result = ref.read(staffAccessProvider.notifier)
        .login(_mobileCtrl.text.trim(), _pinCtrl.text.trim());
    if (result != null) {
      setState(() { _staff = result; _loading = false; });
      _loggedInStaff = result;
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid mobile number or PIN. Please try again.';
      });
    }
  }

  void _logout() {
    setState(() { _staff = null; });
    _loggedInStaff = null;
    _mobileCtrl.clear();
    _pinCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Refresh staff data
    final staffList = ref.watch(staffAccessProvider);
    if (_staff != null) {
      final updated = staffList.firstWhere(
        (s) => s['id'] == _staff!['id'],
        orElse: () => _staff!,
      );
      if (updated != _staff) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _staff = updated);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Staff Portal'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: _staff != null
            ? [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout',
                  onPressed: _logout,
                )
              ]
            : null,
      ),
      body: _staff == null
          ? _buildLoginForm()
          : _buildPortal(context, _staff!),
    );
  }

  // ── LOGIN FORM ─────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo / Icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_rounded,
                color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Staff Sign In',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 6),
          const Text('Enter your mobile number and PIN',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          const SizedBox(height: 28),

          // Mobile
          TextField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10)],
            decoration: InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            ),
          ),
          const SizedBox(height: 14),

          // PIN
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(
              labelText: '4-digit PIN',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            ),
            onSubmitted: (_) => _login(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Sign In',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ]),
      ),
    );
  }

  // ── STAFF PORTAL (after login) ─────────────────────────────────────────────
  Widget _buildPortal(BuildContext context, Map<String, dynamic> staff) {
    final isSignedIn  = staff['is_signed_in'] as bool;
    final signInTime  = staff['sign_in_time']  as String?;
    final signOutTime = staff['sign_out_time'] as String?;
    final dept        = staff['department'] as String;
    final today       = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    final leaves      = ref.watch(leaveProvider)
        .where((l) => l['staff_id'] == staff['id'])
        .toList();
    final pendingLeave = leaves.where((l) => l['status'] == 'PENDING').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                (staff['name'] as String).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(staff['name'] as String,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text(dept,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(today,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            if (isSignedIn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('● ACTIVE',
                    style: TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        const SizedBox(height: 20),

        // Sign In / Sign Out card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.access_time_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Attendance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const Divider(height: 20),

            // Times
            Row(children: [
              _TimeBox('Sign In',  signInTime  ?? '--:-- --', AppTheme.success),
              const SizedBox(width: 12),
              _TimeBox('Sign Out', signOutTime ?? '--:-- --', AppTheme.error),
            ]),
            const SizedBox(height: 16),

            // Action button
            ElevatedButton.icon(
              onPressed: () {
                if (isSignedIn) {
                  ref.read(staffAccessProvider.notifier).signOut(staff['id'] as String);
                  setState(() {
                    final updated = ref.read(staffAccessProvider)
                        .firstWhere((s) => s['id'] == staff['id'],
                            orElse: () => staff);
                    _staff = updated;
                    _loggedInStaff = updated;
                  });
                } else {
                  ref.read(staffAccessProvider.notifier).signIn(staff['id'] as String);
                  setState(() {
                    final updated = ref.read(staffAccessProvider)
                        .firstWhere((s) => s['id'] == staff['id'],
                            orElse: () => staff);
                    _staff = updated;
                    _loggedInStaff = updated;
                  });
                }
              },
              icon: Icon(isSignedIn
                  ? Icons.logout_rounded : Icons.login_rounded),
              label: Text(isSignedIn ? 'Sign Out' : 'Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSignedIn ? AppTheme.error : AppTheme.success,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Leave card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.beach_access_outlined, color: Color(0xFF6A1B9A), size: 20),
              const SizedBox(width: 8),
              const Text('Leave Requests',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (pendingLeave > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$pendingLeave Pending',
                      style: const TextStyle(
                          color: AppTheme.warning, fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            const Divider(height: 16),

            // Recent leaves
            if (leaves.isEmpty)
              const Text('No leave applications yet.',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))
            else
              ...leaves.take(3).map((l) => _LeaveRow(leave: l)),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showApplyLeaveSheet(context, ref, staff),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Apply for Leave'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A1B9A),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showApplyLeaveSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic> staff) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Apply for Leave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),

            // Date picker tile
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (d != null) setSheet(() => selectedDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(DateFormat('d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primary),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for leave',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                ref.read(leaveProvider.notifier).apply(
                  staffId:    staff['id'] as String,
                  staffName:  staff['name'] as String,
                  department: staff['department'] as String,
                  date: selectedDate.toIso8601String().substring(0, 10),
                  reason: reasonCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Leave application submitted for approval'),
                    backgroundColor: AppTheme.primary));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit Application',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label, time;
  final Color color;
  const _TimeBox(this.label, this.time, this.color);
  @override
  Widget build(_) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

class _LeaveRow extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveRow({required this.leave});

  static const _colors = {
    'PENDING':  Colors.orange,
    'APPROVED': AppTheme.success,
    'REJECTED': AppTheme.error,
  };

  @override
  Widget build(_) {
    final status = leave['status'] as String;
    final color  = _colors[status] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.textPrimary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(leave['date'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(leave['reason'] as String,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
