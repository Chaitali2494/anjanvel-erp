import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';
import '../../data/session_bookings_provider.dart';
import '../../models/booking_model.dart';

// ─── Journey stages ───────────────────────────────────────────────────────────
const _stageLabels = ['Created', 'Confirmed', 'Checked In', 'Checked Out'];
const _stageIcons  = [
  Icons.add_circle_outline_rounded,
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
      return 0; // INQUIRY / NEW / PENDING
  }
}

// ─── Helper: BookingModel → Map ───────────────────────────────────────────────
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
  'room_number':
      b.roomNumbers?.isNotEmpty == true ? b.roomNumbers!.first : null,
  'guests': b.guest,
};

// ─── Screen ──────────────────────────────────────────────────────────────────
class BookingRoadmapScreen extends ConsumerWidget {
  const BookingRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionBookings = ref.watch(sessionBookingsProvider);
    final allBookingsAsync = ref.watch(bookingsProvider(const BookingFilter()));

    final supaModels = allBookingsAsync.valueOrNull ?? <BookingModel>[];
    final sessionIds = sessionBookings.map((b) => b['id'] as String).toSet();
    final merged = [
      ...sessionBookings,
      ...supaModels
          .where((b) => !sessionIds.contains(b.id))
          .map(_modelToMap),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Booking Roadmap',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Booking',
            onPressed: () => context.push('/bookings/create'),
          ),
        ],
      ),
      body: allBookingsAsync.isLoading && merged.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : merged.isEmpty
              ? EmptyState(
                  title: 'No Bookings Yet',
                  subtitle: 'Create a booking to track its journey here',
                  icon: Icons.route_rounded,
                  buttonLabel: 'New Booking',
                  onButtonTap: () => context.push('/bookings/create'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: merged.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _BookingJourneyCard(booking: merged[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('New Booking', style: TextStyle(color: Colors.white)),
        onPressed: () => context.push('/bookings/create'),
      ),
    );
  }
}

// ─── Per-booking journey card ─────────────────────────────────────────────────
class _BookingJourneyCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingJourneyCard({required this.booking});

  static String _fmt(String? d) {
    if (d == null || d.isEmpty) return '—';
    try {
      return DateFormat('d MMM').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = booking['id']?.toString() ?? '';

    final guestsMap = booking['guests'] as Map<String, dynamic>?;
    final guestName = guestsMap?['full_name'] as String? ??
        booking['guest_name'] as String? ??
        booking['full_name'] as String? ??
        'Guest';

    final bookingNo = booking['booking_number']?.toString() ??
        id.substring(0, 8).toUpperCase();

    final roomNo = booking['room_number']?.toString() ??
        (booking['booking_rooms'] is List &&
                (booking['booking_rooms'] as List).isNotEmpty
            ? ((booking['booking_rooms'] as List).first['room_number'] ?? '—')
            : '—');

    final checkIn  = booking['check_in_date']  as String? ?? booking['check_in']  as String?;
    final checkOut = booking['check_out_date'] as String? ?? booking['check_out'] as String?;

    int nights = 1;
    try {
      if (checkIn != null && checkOut != null) {
        nights = DateTime.parse(checkOut).difference(DateTime.parse(checkIn)).inDays;
        if (nights < 1) nights = 1;
      }
    } catch (_) {}

    final pax    = (booking['pax_count'] as num?)?.toInt() ??
        (booking['adults'] as num?)?.toInt() ?? 1;
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final status = (booking['status'] as String? ?? '').toUpperCase();
    final stage  = _stageIndex(status);
    final stageColor = _stageColors[stage];

    return GestureDetector(
      onTap: () { if (id.isNotEmpty) context.push('/bookings/$id'); },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: stageColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Guest info row ──────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: stageColor.withOpacity(0.15),
                    child: Text(
                      guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: stageColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guestName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '#$bookingNo  •  Rm $roomNo  •  ${_fmt(checkIn)} – ${_fmt(checkOut)}  •  ${nights}N $pax👤',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (amount > 0)
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: stageColor,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Horizontal journey line ─────────────────────────────────
              _HorizontalStepper(currentStage: stage),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Horizontal stepper ───────────────────────────────────────────────────────
class _HorizontalStepper extends StatelessWidget {
  final int currentStage; // 0–3
  const _HorizontalStepper({required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_stageLabels.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final segIdx = i ~/ 2; // segment between stage segIdx and segIdx+1
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

        final idx   = i ~/ 2;
        final done  = currentStage > idx;
        final active = currentStage == idx;
        final color = _stageColors[idx];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 34 : 28,
              height: active ? 34 : 28,
              decoration: BoxDecoration(
                color: done || active ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done || active ? color : const Color(0xFFBDBDBD),
                  width: active ? 3 : 2,
                ),
                boxShadow: active
                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: Icon(
                done ? Icons.check_rounded : _stageIcons[idx],
                size: active ? 18 : 14,
                color: done || active ? Colors.white : const Color(0xFFBDBDBD),
              ),
            ),
            const SizedBox(height: 5),
            // Label
            Text(
              _stageLabels[idx],
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active
                    ? color
                    : done
                        ? AppTheme.textSecondary
                        : const Color(0xFFBDBDBD),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }
}
