import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';
import '../../data/session_bookings_provider.dart';
import '../../models/booking_model.dart';

// ─── Stage definition ────────────────────────────────────────────────────────
class _Stage {
  final String label;
  final String subtitle;
  final List<String> statuses; // Supabase status strings that belong here
  final Color color;
  final Color bg;
  final IconData icon;
  const _Stage({
    required this.label,
    required this.subtitle,
    required this.statuses,
    required this.color,
    required this.bg,
    required this.icon,
  });
}

const _stages = [
  _Stage(
    label: 'New Booking',
    subtitle: 'Just created',
    statuses: ['INQUIRY', 'PENDING', 'NEW', ''],
    color: Color(0xFF7B61FF),
    bg: Color(0xFFF3F1FF),
    icon: Icons.add_circle_outline_rounded,
  ),
  _Stage(
    label: 'Confirmed',
    subtitle: 'Advance paid / confirmed',
    statuses: ['CONFIRMED', 'ADVANCE_PAID'],
    color: Color(0xFF0288D1),
    bg: Color(0xFFE1F5FE),
    icon: Icons.check_circle_outline_rounded,
  ),
  _Stage(
    label: 'Checked In',
    subtitle: 'Guest is staying',
    statuses: ['CHECKED_IN'],
    color: Color(0xFF2E7D32),
    bg: Color(0xFFE8F5E9),
    icon: Icons.login_rounded,
  ),
  _Stage(
    label: 'Checked Out',
    subtitle: 'Stay completed',
    statuses: ['CHECKED_OUT', 'COMPLETED'],
    color: Color(0xFFE65100),
    bg: Color(0xFFFFF3E0),
    icon: Icons.logout_rounded,
  ),
];

// ─── Helper: convert BookingModel → unified map ───────────────────────────────
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
  'room_number': b.roomNumbers?.isNotEmpty == true ? b.roomNumbers!.first : null,
  'guests': b.guest,
};

// ─── Screen ──────────────────────────────────────────────────────────────────
class BookingRoadmapScreen extends ConsumerWidget {
  const BookingRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionBookings = ref.watch(sessionBookingsProvider);
    final allBookingsAsync = ref.watch(bookingsProvider(const BookingFilter()));

    // Merge session + Supabase bookings (session takes priority)
    final supaModels = allBookingsAsync.valueOrNull ?? <BookingModel>[];
    final sessionIds = sessionBookings.map((b) => b['id'] as String).toSet();
    final supaBookings = supaModels
        .where((b) => !sessionIds.contains(b.id))
        .map(_modelToMap)
        .toList();
    final merged = [...sessionBookings, ...supaBookings];

    // Group by stage
    List<List<Map<String, dynamic>>> groups = List.generate(_stages.length, (_) => []);
    for (final b in merged) {
      final status = (b['status'] as String? ?? '').toUpperCase();
      int placed = 0;
      for (int i = 0; i < _stages.length; i++) {
        if (_stages[i].statuses.contains(status)) {
          groups[i].add(b);
          placed = 1;
          break;
        }
      }
      // Unknown statuses → New Booking column
      if (placed == 0) groups[0].add(b);
    }

    final total = merged.length;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header summary bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Booking Journey',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total bookings',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Stage progress strip ────────────────────────────────────────
          _StageProgressStrip(groups: groups),

          const SizedBox(height: 4),

          // ── Pipeline columns ────────────────────────────────────────────
          Expanded(
            child: allBookingsAsync.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _PipelineView(groups: groups),
          ),
        ],
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

// ─── Stage progress strip ─────────────────────────────────────────────────────
class _StageProgressStrip extends StatelessWidget {
  final List<List<Map<String, dynamic>>> groups;
  const _StageProgressStrip({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Row(
        children: List.generate(_stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector arrow
            return Expanded(
              child: Container(
                height: 2,
                color: const Color(0xFFE0E0E0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
            );
          }
          final idx = i ~/ 2;
          final stage = _stages[idx];
          final count = groups[idx].length;
          return _StageChip(stage: stage, count: count);
        }),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final _Stage stage;
  final int count;
  const _StageChip({required this.stage, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: count > 0 ? stage.color : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Icon(stage.icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: count > 0 ? stage.color : const Color(0xFF9E9E9E),
          ),
        ),
      ],
    );
  }
}

// ─── Pipeline view (horizontal scroll with 4 columns) ────────────────────────
class _PipelineView extends StatelessWidget {
  final List<List<Map<String, dynamic>>> groups;
  const _PipelineView({required this.groups});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // On wide screens show all 4, on narrow scroll
    final colW = screenW > 900 ? (screenW - 32) / 4 : 260.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_stages.length, (i) {
          return SizedBox(
            width: colW,
            child: _PipelineColumn(
              stage: _stages[i],
              bookings: groups[i],
              stageIndex: i,
            ),
          );
        }),
      ),
    );
  }
}

// ─── Single pipeline column ───────────────────────────────────────────────────
class _PipelineColumn extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> bookings;
  final int stageIndex;
  const _PipelineColumn({
    required this.stage,
    required this.bookings,
    required this.stageIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: stage.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stage.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: stage.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(stage.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        stage.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${bookings.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cards
          if (bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(stage.icon, color: stage.color.withOpacity(0.3), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'No bookings here',
                    style: TextStyle(
                      color: stage.color.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...bookings.map((b) => _BookingCard(booking: b, stage: stage)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final _Stage stage;
  const _BookingCard({required this.booking, required this.stage, super.key});

  static String _fmt(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('d MMM yy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = booking['id']?.toString() ?? '';

    // Guest name — handle nested Supabase guests or flat session
    final guestsMap = booking['guests'] as Map<String, dynamic>?;
    final guestName = guestsMap?['full_name'] as String? ??
        booking['guest_name'] as String? ??
        booking['full_name'] as String? ??
        'Guest';

    final bookingNo = booking['booking_number']?.toString() ??
        booking['id']?.toString().substring(0, 8).toUpperCase() ??
        '—';

    final roomNo = booking['room_number']?.toString() ??
        (booking['booking_rooms'] is List && (booking['booking_rooms'] as List).isNotEmpty
            ? ((booking['booking_rooms'] as List).first['room_number'] ?? '')
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

    final pax = (booking['pax_count'] as num?)?.toInt() ??
        (booking['adults'] as num?)?.toInt() ?? 1;

    final amount = (booking['total_amount'] as num?)?.toDouble() ??
        (booking['amount'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () {
        if (id.isNotEmpty) {
          context.push('/bookings/$id');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: stage.color.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(left: BorderSide(color: stage.color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guest name + booking number
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: stage.color.withOpacity(0.15),
                    child: Text(
                      guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: stage.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guestName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#$bookingNo',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
              const SizedBox(height: 8),

              // Room + Nights + Pax
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.bed_rounded,
                    label: 'Rm $roomNo',
                    color: stage.color,
                  ),
                  const SizedBox(width: 4),
                  _InfoChip(
                    icon: Icons.nightlight_round,
                    label: '${nights}N',
                    color: stage.color,
                  ),
                  const SizedBox(width: 4),
                  _InfoChip(
                    icon: Icons.people_outline_rounded,
                    label: '$pax',
                    color: stage.color,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Dates
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmt(checkIn)}  →  ${_fmt(checkOut)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),

              if (amount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded, size: 12, color: AppTheme.textHint),
                    const SizedBox(width: 2),
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stage.color,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
