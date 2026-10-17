import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../bookings/data/booking_service.dart';
import '../../data/billing_state_provider.dart';

class BillingListScreen extends ConsumerWidget {
  const BillingListScreen({super.key});

  static const _statusColors = {
    'CHECKED_IN':    Color(0xFF1565C0),
    'ADVANCE_PAID':  Color(0xFF6A1B9A),
    'BOOKED':        Color(0xFF00838F),
    'INQUIRY':       Color(0xFF558B2F),
  };
  static const _statusLabels = {
    'CHECKED_IN':   'Checked In',
    'ADVANCE_PAID': 'Advance Paid',
    'BOOKED':       'Booked',
    'INQUIRY':      'Inquiry',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState  = ref.watch(billingStateProvider);
    final allActivities = ref.watch(activityBookingsProvider).valueOrNull
        ?? <Map<String, dynamic>>[];

    // Build a merged room list: kBillableRooms overridden by session data
    final rooms = kBillableRooms.map((demo) {
      final rno  = demo['room_number'] as String;
      final info = getRoomInfo(rno);
      return {
        'room_number': rno,
        'guest_name':  info['guest_name']  as String? ?? demo['guest_name']  as String? ?? 'Guest',
        'room_type':   info['room_type']   as String? ?? demo['room_type']   as String? ?? 'Room',
        'check_in':    info['check_in']    as String? ?? demo['check_in']    as String? ?? '',
        'check_out':   info['check_out']   as String? ?? demo['check_out']   as String? ?? '',
        'nights':      (info['nights']     as num?)?.toInt()    ?? (demo['nights'] as num?)?.toInt()    ?? 1,
        'persons':     (info['persons']    as num?)?.toInt()    ?? 1,
        'rate':        (info['rate']       as num?)?.toDouble() ?? (demo['rate'] as num?)?.toDouble()   ?? 3500.0,
        'status':      info['status']      as String? ?? demo['status'] as String? ?? 'CHECKED_IN',
        'is_paid':     billingState[rno]?['is_paid'] == true,
        'total':       calcRoomTotal(rno, allActivities),
      };
    }).toList();

    // Also add any session rooms not in kBillableRooms
    for (final entry in sessionRoomBookings.entries) {
      final rno = entry.key;
      if (rooms.any((r) => r['room_number'] == rno)) continue;
      final info = getRoomInfo(rno);
      final nights  = getActualNights(rno);
      final persons = (info['persons'] as num?)?.toInt() ?? 1;
      final rate    = (info['rate']    as num?)?.toDouble() ?? 3500.0;
      final total   = calcRoomTotal(rno, allActivities);
      rooms.add({
        'room_number': rno,
        'guest_name':  info['guest_name'] as String? ?? 'Guest',
        'room_type':   info['room_type']  as String? ?? 'Room',
        'check_in':    info['check_in']   as String? ?? '',
        'check_out':   info['check_out']  as String? ?? '',
        'nights':      nights,
        'persons':     persons,
        'rate':        rate,
        'status':      'CHECKED_IN',
        'is_paid':     billingState[rno]?['is_paid'] == true,
        'total':       total,
      });
    }

    final paidCount = rooms.where((r) => r['is_paid'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Billing'),
      body: Column(
        children: [
          // ── Summary bar ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: Row(children: [
              _StatChip(
                label: 'Total Rooms',
                value: '${rooms.length}',
                color: AppTheme.primary,
                icon: Icons.hotel_outlined,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Paid',
                value: '$paidCount',
                color: AppTheme.success,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Pending',
                value: '${rooms.length - paidCount}',
                color: AppTheme.warning,
                icon: Icons.pending_outlined,
              ),
            ]),
          ),
          const Divider(height: 1),

          // ── Guest list ───────────────────────────────────────────────────
          Expanded(
            child: rooms.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textHint),
                      SizedBox(height: 12),
                      Text('No active rooms', style: TextStyle(color: AppTheme.textHint, fontSize: 15)),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final r        = rooms[i];
                      final rno      = r['room_number'] as String;
                      final isPaid   = r['is_paid'] as bool;
                      final status   = r['status']  as String;
                      final stColor  = _statusColors[status] ?? AppTheme.textPrimary;
                      final stLabel  = _statusLabels[status] ?? status;
                      final nights   = r['nights']  as int;
                      final persons  = r['persons'] as int;
                      final rate     = r['rate']    as double;
                      final total    = r['total']   as double;
                      final checkIn  = r['check_in']  as String;
                      final checkOut = r['check_out'] as String;

                      return InkWell(
                        onTap: () => context.push('/billing/room', extra: {
                          'room_number':   rno,
                          'check_in_date':  checkIn,
                          'check_out_date': checkOut,
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            // Room badge
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? AppTheme.success.withOpacity(0.1)
                                    : stColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  rno,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isPaid ? AppTheme.success : stColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Guest + room info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                        r['guest_name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isPaid)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('PAID ✓',
                                            style: TextStyle(
                                              color: AppTheme.success, fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: stColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(stLabel,
                                            style: TextStyle(
                                              color: stColor, fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                      ),
                                  ]),
                                  const SizedBox(height: 3),
                                  Text(
                                    r['room_type'] as String,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.people_outline, size: 12, color: AppTheme.textHint),
                                    const SizedBox(width: 4),
                                    Text('$persons pax',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.nights_stay_outlined, size: 12, color: AppTheme.textHint),
                                    const SizedBox(width: 4),
                                    Text('$nights night${nights != 1 ? "s" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.currency_rupee, size: 11, color: AppTheme.textHint),
                                    Text('${rate.toInt()}/pax/night',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                                  ]),
                                  if (checkIn.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(children: [
                                      const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.textHint),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_fmtDate(checkIn)} → ${checkOut.isNotEmpty ? _fmtDate(checkOut) : "—"}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                                      ),
                                    ]),
                                  ],
                                ],
                              ),
                            ),

                            // Total + arrow
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isPaid ? AppTheme.success : AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text('incl. GST',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppTheme.textHint, size: 20),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatChip({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ]),
        ]),
      ),
    );
  }
}
