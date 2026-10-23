import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';
import '../../data/session_bookings_provider.dart';
import '../../models/booking_model.dart';
import '../../../billing/data/billing_state_provider.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../food/data/food_orders_state_provider.dart';

// ─── Stage config ─────────────────────────────────────────────────────────────
const _stageLabels = ['Created', 'Confirmed', 'Checked In', 'Checked Out'];
const _stageIcons  = [
  Icons.person_add_outlined,
  Icons.check_circle_outline_rounded,
  Icons.login_rounded,
  Icons.logout_rounded,
];
const _stageColors = [
  Color(0xFF7B61FF),
  Color(0xFF0288D1),
  Color(0xFF2E7D32),
  Color(0xFFE65100),
];

int _stageIndex(String status) {
  switch (status.toUpperCase()) {
    case 'CONFIRMED':
    case 'ADVANCE_PAID':
      return 1;
    case 'CHECKED_IN':
      return 2;
    case 'CHECKED_OUT':
    case 'COMPLETED':
      return 3;
    default:
      return 0;
  }
}

Map<String, dynamic> _modelToMap(BookingModel b) => {
  'id': b.id,
  'booking_number': b.bookingNumber,
  'status': b.status,
  'check_in_date': b.checkInDate,
  'check_out_date': b.checkOutDate,
  'pax_count': b.numAdults + b.numChildren,
  'adults': b.numAdults,
  'total_amount': b.totalAmount,
  'guest_name': b.guestName,
  'guest_phone': b.guestPhone,
  'room_number':
      b.roomNumbers?.isNotEmpty == true ? b.roomNumbers!.first : null,
  'guests': b.guest,
};

String _fmtDate(String? d) {
  if (d == null || d.isEmpty) return '—';
  try { return DateFormat('d MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
}

String _fmtTime(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    return DateFormat('h:mm a').format(dt);
  } catch (_) { return '—'; }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class BookingRoadmapScreen extends ConsumerWidget {
  const BookingRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionBookings   = ref.watch(sessionBookingsProvider);
    final allBookingsAsync  = ref.watch(bookingsProvider(const BookingFilter()));
    final billingState      = ref.watch(billingStateProvider);
    final allActivities     = ref.watch(activityBookingsProvider).valueOrNull ?? [];
    final allFood           = ref.watch(foodOrdersStateProvider);

    final supaModels = allBookingsAsync.valueOrNull ?? <BookingModel>[];
    final sessionIds = sessionBookings.map((b) => b['id'] as String).toSet();
    final merged = [
      ...sessionBookings,
      ...supaModels.where((b) => !sessionIds.contains(b.id)).map(_modelToMap),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Guest Roadmap',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Booking',
            onPressed: () => context.push('/bookings/create'),
          ),
        ],
      ),
      body: allBookingsAsync.isLoading && merged.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : merged.isEmpty
              ? EmptyState(
                  title: 'No Bookings Yet',
                  subtitle: 'Create a booking to track the guest journey here',
                  icon: Icons.route_rounded,
                  buttonLabel: 'New Booking',
                  onButtonTap: () => context.push('/bookings/create'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: merged.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) => _JourneyCard(
                    booking: merged[i],
                    billingState: billingState,
                    allActivities: allActivities,
                    allFood: allFood,
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Booking', style: TextStyle(color: Colors.white)),
        onPressed: () => context.push('/bookings/create'),
      ),
    );
  }
}

// ─── Journey card ─────────────────────────────────────────────────────────────
class _JourneyCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, Map<String, dynamic>> billingState;
  final List<Map<String, dynamic>> allActivities;
  final List<Map<String, dynamic>> allFood;

  const _JourneyCard({
    required this.booking,
    required this.billingState,
    required this.allActivities,
    required this.allFood,
  });

  @override
  ConsumerState<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends ConsumerState<_JourneyCard> {
  // Local overrides for immediate UI feedback (no waiting for provider rebuild)
  String? _localStatus;
  String? _localCheckedInAt;

  void _doConfirm(String bookingId, Map<String, dynamic> booking) {
    setState(() => _localStatus = 'CONFIRMED');
    ref.read(sessionBookingsProvider.notifier).addBooking({
      ...booking, 'status': 'CONFIRMED',
    });
    if (bookingId.startsWith('local_')) {
      ref.read(bookingServiceProvider).updateLocalBookingStatus(bookingId, 'CONFIRMED');
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Booking confirmed! ✓'),
      backgroundColor: Color(0xFF0288D1),
    ));
  }

  void _doCheckOut(String bookingId, Map<String, dynamic> booking, String roomNo) {
    setState(() => _localStatus = 'CHECKED_OUT');
    ref.read(sessionBookingsProvider.notifier).addBooking({
      ...booking,
      'status': 'CHECKED_OUT',
      'checked_out_at': DateTime.now().toIso8601String(),
    });
    if (bookingId.startsWith('local_')) {
      ref.read(bookingServiceProvider).updateLocalBookingStatus(bookingId, 'CHECKED_OUT');
    }
    // Free the room
    if (roomNo != '—' && roomNo.isNotEmpty) {
      sessionRoomBookings.remove(roomNo);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Guest checked out. Room released.'),
      backgroundColor: Color(0xFFE65100),
    ));
  }

  void _doCheckIn(String bookingId, Map<String, dynamic> booking,
      String roomNo, String roomType, String guestName) {
    final now = DateTime.now().toIso8601String();
    setState(() {
      _localStatus     = 'CHECKED_IN';
      _localCheckedInAt = now;
    });

    // Resolve room from assignments if not in booking map
    String resolvedRoom = roomNo;
    String resolvedType = roomType;
    if (resolvedRoom == '—' || resolvedRoom.isEmpty) {
      final assignments = sessionBookingRoomAssignments[bookingId];
      if (assignments != null && assignments.isNotEmpty) {
        resolvedRoom = assignments.first['room_number'] as String? ?? '—';
        resolvedType = assignments.first['type_name'] as String? ?? roomType;
      }
    }

    // Update global provider (cross-screen sync)
    ref.read(sessionBookingsProvider.notifier).addBooking({
      ...booking,
      'status': 'CHECKED_IN',
      'checked_in_at': now,
      if (resolvedRoom != '—') 'room_number': resolvedRoom,
    });

    // Update booking service cache for Front Desk screen
    if (bookingId.startsWith('local_')) {
      ref.read(bookingServiceProvider).updateLocalBookingStatus(bookingId, 'CHECKED_IN');
    }

    // Sync sessionRoomBookings so room detail shows the guest
    if (resolvedRoom != '—' && resolvedRoom.isNotEmpty) {
      final guest = booking['guests'] as Map<String, dynamic>? ?? {};
      sessionRoomBookings[resolvedRoom] = {
        'id': bookingId,
        'booking_number': booking['booking_number'] ?? '',
        'status': 'CHECKED_IN',
        'check_in_date':  booking['check_in_date']  ?? '',
        'check_out_date': booking['check_out_date'] ?? '',
        'num_adults':   (booking['num_adults']   as num?)?.toInt()    ?? 1,
        'num_children': (booking['num_children'] as num?)?.toInt()    ?? 0,
        'total_amount': (booking['total_amount'] as num?)?.toDouble() ?? 0,
        'paid_amount':  (booking['paid_amount']  as num?)?.toDouble() ?? 0,
        'room_type_name': resolvedType,
        'rate': 3500.0,
        'guests': guest.isNotEmpty ? guest
            : {'full_name': guestName, 'phone': booking['guest_phone'] ?? ''},
      };
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Guest checked in successfully! 🏠'),
      backgroundColor: Color(0xFF2E7D32),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final id = booking['id']?.toString() ?? '';
    final guestsMap  = booking['guests'] as Map<String, dynamic>?;
    final guestName  = guestsMap?['full_name'] as String? ??
        booking['guest_name'] as String? ?? 'Guest';
    final guestPhone = guestsMap?['phone'] as String? ??
        booking['guest_phone'] as String? ?? '—';
    final bookingNo  = booking['booking_number']?.toString() ??
        (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase());
    // Check session room assignments as fallback (assigned via booking detail screen)
    String roomNo = booking['room_number']?.toString() ?? '—';
    if (roomNo == '—' || roomNo.isEmpty) {
      final assignments = sessionBookingRoomAssignments[id];
      if (assignments != null && assignments.isNotEmpty) {
        roomNo = assignments.first['room_number'] as String? ?? '—';
      }
    }
    final checkIn    = booking['check_in_date']  as String? ?? booking['check_in']  as String?;
    final checkOut   = booking['check_out_date'] as String? ?? booking['check_out'] as String?;
    // Use local status override for immediate UI feedback
    final status     = (_localStatus ?? (booking['status'] as String? ?? '')).toUpperCase();
    final stage      = _stageIndex(status);
    final color      = _stageColors[stage];
    final createdAt    = booking['created_at']    as String?;
    final checkedInAt  = _localCheckedInAt ?? booking['checked_in_at'] as String?;

    // Bill data
    final roomInfo       = getRoomInfo(roomNo == '—' ? '' : roomNo);
    final nights         = getActualNights(roomNo == '—' ? '' : roomNo);
    final rate           = (roomInfo['rate']    as num?)?.toDouble() ?? 0;
    final persons        = (roomInfo['persons'] as num?)?.toInt()    ?? 1;
    final roomCharge     = rate * persons * nights;
    final foodCharge     = kDemoFoodCharges[roomNo] ?? 0.0;
        final activityCharge = widget.allActivities
        .where((a) => a['room_number'] == roomNo && a['status'] != 'CANCELLED')
        .fold(0.0, (s, a) => s + ((a['total_amount'] as num?)?.toDouble() ?? 0.0));
    final shopCharge = 0.0; // placeholder — wire to shop provider when ready
    final subtotal   = roomCharge + foodCharge + activityCharge + shopCharge;
    final total      = subtotal * 1.12;
    final isPaid     = widget.billingState[roomNo]?['is_paid'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: () { if (id.isNotEmpty) context.push('/bookings/$id'); },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(
                      guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guestName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                        Text('#$bookingNo  •  ${_stageLabels[stage]}',
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
                ],
              ),
            ),
          ),

          // ── Horizontal stepper ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _HorizontalStepper(currentStage: stage),
          ),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── Stage detail ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _StageDetail(
              stage: stage,
              guestName: guestName,
              guestPhone: guestPhone,
              roomNo: roomNo,
              roomType: roomInfo['room_type']?.toString() ?? '—',
              checkIn: checkIn,
              checkOut: checkOut,
              nights: nights,
              createdAt: createdAt,
              checkedInAt: checkedInAt,
              bookingId: id,
              roomCharge: roomCharge,
              foodCharge: foodCharge,
              activityCharge: activityCharge,
              shopCharge: shopCharge,
              total: total,
              isPaid: isPaid,
              onConfirm:  () => _doConfirm(id, booking),
              onCheckIn:  () => _doCheckIn(id, booking, roomNo,
                  roomInfo['room_type']?.toString() ?? '—', guestName),
              onCheckOut: () => _doCheckOut(id, booking, roomNo),
              onViewBill: () => context.push('/billing'),
              onCancel: () {
                setState(() => _localStatus = 'CANCELLED');
                ref.read(sessionBookingsProvider.notifier).updateStatus(id, 'CANCELLED');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Booking cancelled'),
                  backgroundColor: Colors.red,
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Horizontal stepper ───────────────────────────────────────────────────────
class _HorizontalStepper extends StatelessWidget {
  final int currentStage;
  const _HorizontalStepper({required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_stageLabels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final segIdx = i ~/ 2;
          final filled = currentStage > segIdx;
          return Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: filled ? _stageColors[segIdx] : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final idx    = i ~/ 2;
        final done   = currentStage > idx;
        final active = currentStage == idx;
        final color  = _stageColors[idx];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 36 : 28,
              height: active ? 36 : 28,
              decoration: BoxDecoration(
                color: done || active ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done || active ? color : const Color(0xFFBDBDBD),
                  width: active ? 3 : 2,
                ),
                boxShadow: active
                    ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: Icon(
                done ? Icons.check_rounded : _stageIcons[idx],
                size: active ? 18 : 14,
                color: done || active ? Colors.white : const Color(0xFFBDBDBD),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _stageLabels[idx],
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? color : done ? AppTheme.textSecondary : const Color(0xFFBDBDBD),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }
}

// ─── Stage detail section ─────────────────────────────────────────────────────
class _StageDetail extends StatelessWidget {
  final int stage;
  final String guestName, guestPhone, roomNo, roomType, bookingId;
  final String? checkIn, checkOut, createdAt, checkedInAt;
  final int nights;
  final double roomCharge, foodCharge, activityCharge, shopCharge, total;
  final bool isPaid;
  final VoidCallback onConfirm;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onViewBill;
  final VoidCallback onCancel;

  const _StageDetail({
    required this.stage,
    required this.guestName,
    required this.guestPhone,
    required this.roomNo,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.createdAt,
    required this.checkedInAt,
    required this.bookingId,
    required this.roomCharge,
    required this.foodCharge,
    required this.activityCharge,
    required this.shopCharge,
    required this.total,
    required this.isPaid,
    required this.onConfirm,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onViewBill,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (stage) {
      case 0: return _CreatedDetail(
          guestName: guestName, guestPhone: guestPhone,
          roomNo: roomNo, roomType: roomType,
          checkIn: checkIn, checkOut: checkOut, createdAt: createdAt,
          onConfirm: onConfirm);
      case 1: return _ConfirmedDetail(
          bookingId: bookingId, guestName: guestName,
          roomNo: roomNo, roomType: roomType,
          checkIn: checkIn, checkOut: checkOut,
          onCheckIn: onCheckIn, onCancel: onCancel);
      case 2: return _CheckedInDetail(
          checkIn: checkIn, checkedInAt: checkedInAt,
          roomNo: roomNo, roomType: roomType,
          nights: nights, guestName: guestName,
          onCheckOut: onCheckOut, onViewBill: onViewBill);
      case 3: return _CheckedOutDetail(
          checkOut: checkOut, roomNo: roomNo, roomType: roomType,
          roomCharge: roomCharge, foodCharge: foodCharge,
          activityCharge: activityCharge, shopCharge: shopCharge,
          total: total, isPaid: isPaid);
      default: return const SizedBox.shrink();
    }
  }
}

// ── Stage 0: Created ──────────────────────────────────────────────────────────
class _CreatedDetail extends StatelessWidget {
  final String guestName, guestPhone, roomNo, roomType;
  final String? checkIn, checkOut, createdAt;
  final VoidCallback onConfirm;
  const _CreatedDetail({
    required this.guestName, required this.guestPhone,
    required this.roomNo, required this.roomType,
    required this.checkIn, required this.checkOut, required this.createdAt,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF7B61FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Booking Created', color: c),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.person_outline_rounded, label: 'Guest', value: guestName, color: c),
        _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: guestPhone, color: c),
        _InfoRow(icon: Icons.bed_rounded, label: 'Room', value: roomNo == '—' ? '—' : 'Room $roomNo  •  $roomType', color: c),
        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Check-in', value: _fmtDate(checkIn), color: c),
        _InfoRow(icon: Icons.calendar_month_rounded, label: 'Check-out', value: _fmtDate(checkOut), color: c),
        if (createdAt != null)
          _InfoRow(icon: Icons.access_time_rounded, label: 'Booked on', value: _fmtDate(createdAt), color: c),
        const SizedBox(height: 12),
        _StatusChip('Awaiting Confirmation', Colors.orange),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
            label: const Text('Confirm Booking', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stage 1: Confirmed ───────────────────────────────────────────────────────
class _ConfirmedDetail extends StatelessWidget {
  final String bookingId, guestName, roomNo, roomType;
  final String? checkIn, checkOut;
  final VoidCallback onCheckIn;
  final VoidCallback onCancel;
  const _ConfirmedDetail({
    required this.bookingId, required this.guestName,
    required this.roomNo, required this.roomType,
    required this.checkIn, required this.checkOut,
    required this.onCheckIn, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF0288D1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Booking Confirmed', color: c),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.person_outline_rounded, label: 'Guest', value: guestName, color: c),
        _InfoRow(icon: Icons.bed_rounded, label: 'Room', value: roomNo == '—' ? '—' : 'Room $roomNo  •  $roomType', color: c),
        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Check-in', value: _fmtDate(checkIn), color: c),
        _InfoRow(icon: Icons.calendar_month_rounded, label: 'Check-out', value: _fmtDate(checkOut), color: c),
        const SizedBox(height: 12),
        const _StatusChip('Confirmed ✓', Color(0xFF0288D1)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: const Text('Check In Now', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stage 2: Checked In ───────────────────────────────────────────────────────
class _CheckedInDetail extends StatelessWidget {
  final String? checkIn, checkedInAt;
  final String roomNo, roomType, guestName;
  final int nights;
  final VoidCallback onCheckOut;
  final VoidCallback onViewBill;
  const _CheckedInDetail({
    required this.checkIn, required this.checkedInAt,
    required this.roomNo, required this.roomType,
    required this.nights, required this.guestName,
    required this.onCheckOut, required this.onViewBill,
  });

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF2E7D32);
    final timeSource = checkedInAt ?? checkIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Currently Checked In', color: c),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.person_outline_rounded, label: 'Guest', value: guestName, color: c),
        _InfoRow(icon: Icons.bed_rounded, label: 'Room', value: roomNo == '—' ? '—' : 'Room $roomNo  •  $roomType', color: c),
        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Check-in Date', value: _fmtDate(checkIn), color: c),
        _InfoRow(icon: Icons.access_time_rounded, label: 'Check-in Time', value: _fmtTime(timeSource), color: c),
        _InfoRow(icon: Icons.nights_stay_rounded, label: 'Duration', value: '$nights night${nights == 1 ? '' : 's'}', color: c),
        const SizedBox(height: 8),
        const _StatusChip('In-House 🏠', Color(0xFF2E7D32)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onViewBill,
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('View Bill'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0288D1),
                  side: const BorderSide(color: Color(0xFF0288D1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCheckOut,
                icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                label: const Text('Check Out', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stage 3: Checked Out ──────────────────────────────────────────────────────
class _CheckedOutDetail extends StatelessWidget {
  final String? checkOut;
  final String roomNo, roomType;
  final double roomCharge, foodCharge, activityCharge, shopCharge, total;
  final bool isPaid;
  const _CheckedOutDetail({
    required this.checkOut, required this.roomNo, required this.roomType,
    required this.roomCharge, required this.foodCharge,
    required this.activityCharge, required this.shopCharge,
    required this.total, required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFE65100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Bills Summary  •  Before Check-out', color: c),
        const SizedBox(height: 10),

        // Bill rows
        _BillRow('Room Charges',    roomCharge,     icon: Icons.bed_rounded),
        _BillRow('Food & Dining',   foodCharge,     icon: Icons.restaurant_rounded),
        _BillRow('Activities',      activityCharge, icon: Icons.hiking_rounded),
        _BillRow('Shop / Misc',     shopCharge,     icon: Icons.shopping_bag_outlined),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(thickness: 1, color: Color(0xFFEEEEEE)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total (incl. 12% GST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE65100))),
          ],
        ),
        const SizedBox(height: 10),
        isPaid
            ? const _StatusChip('All Bills Paid ✓  •  Completed', Color(0xFF2E7D32))
            : _StatusChip('Payment Pending — ₹${total.toStringAsFixed(0)}', Colors.red.shade700),

        const SizedBox(height: 8),
        _InfoRow(icon: Icons.logout_rounded, label: 'Check-out', value: _fmtDate(checkOut), color: c),
        _InfoRow(icon: Icons.access_time_rounded, label: 'Time', value: _fmtTime(checkOut), color: c),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  const _BillRow(this.label, this.amount, {required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textHint),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        amount > 0
            ? Text('₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Not taken', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}
