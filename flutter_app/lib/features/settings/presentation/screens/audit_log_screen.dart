import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

const _demoLogs = [
  {'id': '1', 'action': 'BOOKING_CREATED',    'user': 'Manager Rahul',  'details': 'Booking #ANJ-001 created for Priya Sharma',  'ts': '2026-10-03T09:15:00', 'severity': 'info'},
  {'id': '2', 'action': 'CHECK_IN',           'user': 'Manager Rahul',  'details': 'Guest Priya Sharma checked in to Room 205',  'ts': '2026-10-03T11:00:00', 'severity': 'info'},
  {'id': '3', 'action': 'PAYMENT_RECEIVED',   'user': 'Accountant Dev', 'details': 'Payment ₹12,500 received via UPI',           'ts': '2026-10-03T11:05:00', 'severity': 'success'},
  {'id': '4', 'action': 'FOOD_ORDER_PLACED',  'user': 'System',         'details': 'Room 205 placed food order #FO-034',         'ts': '2026-10-03T13:30:00', 'severity': 'info'},
  {'id': '5', 'action': 'MAINTENANCE_TICKET', 'user': 'Meena HK',       'details': 'Maintenance ticket raised for AC in Room 205','ts': '2026-10-03T14:00:00', 'severity': 'warning'},
  {'id': '6', 'action': 'STAFF_LOGIN',        'user': 'Chef Arun',      'details': 'Staff login from IP 192.168.1.10',           'ts': '2026-10-03T08:00:00', 'severity': 'info'},
  {'id': '7', 'action': 'INVENTORY_UPDATED',  'user': 'Manager Rahul',  'details': 'Stock updated: Organic Honey qty 12 → 8',    'ts': '2026-10-02T17:00:00', 'severity': 'info'},
  {'id': '8', 'action': 'USER_DEACTIVATED',   'user': 'Owner',          'details': 'User activity@anjanvel.com deactivated',     'ts': '2026-10-01T10:00:00', 'severity': 'warning'},
  {'id': '9', 'action': 'BOOKING_CANCELLED',  'user': 'Manager Rahul',  'details': 'Booking #ANJ-002 cancelled — guest request', 'ts': '2026-09-30T15:00:00', 'severity': 'error'},
];

final auditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('audit_logs').select().order('created_at', ascending: false).limit(100);
  } catch (_) {
    return List.from(_demoLogs);
  }
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});
  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _filterSeverity = 'ALL';

  static const _severityCfg = {
    'info':    {'color': Color(0xFF1565C0), 'icon': Icons.info_outline_rounded},
    'success': {'color': Color(0xFF2E7D32), 'icon': Icons.check_circle_outline_rounded},
    'warning': {'color': Color(0xFFFFB300), 'icon': Icons.warning_amber_rounded},
    'error':   {'color': Color(0xFFE53935), 'icon': Icons.error_outline_rounded},
  };

  static const _actionLabels = {
    'BOOKING_CREATED':    'Booking Created',
    'BOOKING_CANCELLED':  'Booking Cancelled',
    'CHECK_IN':           'Check-In',
    'CHECK_OUT':          'Check-Out',
    'PAYMENT_RECEIVED':   'Payment Received',
    'FOOD_ORDER_PLACED':  'Food Order',
    'MAINTENANCE_TICKET': 'Maintenance',
    'STAFF_LOGIN':        'Staff Login',
    'INVENTORY_UPDATED':  'Inventory Update',
    'USER_DEACTIVATED':   'User Deactivated',
  };

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Audit Log',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(auditLogsProvider)),
          IconButton(icon: const Icon(Icons.download_rounded), onPressed: () {}),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logs) {
          final filtered = _filterSeverity == 'ALL' ? logs : logs.where((l) => l['severity'] == _filterSeverity).toList();

          return Column(children: [
            // Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: ['ALL', 'info', 'success', 'warning', 'error'].map((s) {
                final selected = _filterSeverity == s;
                final color = s == 'ALL' ? const Color(0xFF37474F) : (_severityCfg[s]?['color'] as Color? ?? Colors.grey);
                final label = s == 'ALL' ? 'All' : s[0].toUpperCase() + s.substring(1);
                return GestureDetector(
                  onTap: () => setState(() => _filterSeverity = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? color : color.withOpacity(0.3)),
                    ),
                    child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList()),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(title: 'No Logs', subtitle: 'No audit logs found', icon: Icons.history_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final log      = filtered[i];
                        final action   = log['action'] as String? ?? '';
                        final user     = log['user'] as String? ?? '';
                        final details  = log['details'] as String? ?? '';
                        final severity = log['severity'] as String? ?? 'info';
                        final ts       = log['ts'] as String? ?? log['created_at'] as String? ?? '';
                        final color    = (_severityCfg[severity]?['color'] as Color?) ?? const Color(0xFF1565C0);
                        final icon     = (_severityCfg[severity]?['icon'] as IconData?) ?? Icons.info_outline_rounded;
                        final label    = _actionLabels[action] ?? action.replaceAll('_', ' ');

                        String? formattedTs;
                        if (ts.isNotEmpty) {
                          try { formattedTs = DateFormat('d MMM, h:mm a').format(DateTime.parse(ts)); } catch (_) {}
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(color: color.withOpacity(0.15)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                          ),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                                const Spacer(),
                                Text(formattedTs ?? '', style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
                              ]),
                              const SizedBox(height: 2),
                              Text(details, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.person_outline_rounded, size: 11, color: AppTheme.textHint),
                                const SizedBox(width: 3),
                                Text(user, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                              ]),
                            ])),
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
