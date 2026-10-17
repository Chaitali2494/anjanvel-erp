import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/session_bookings_provider.dart';

// ── Supabase / demo bookings for the viewed month ──────────────────────────────

final calendarBookingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, month) async {
  final client = ref.watch(supabaseClientProvider);
  final start  = DateTime(month.year, month.month, 1);
  final end    = DateTime(month.year, month.month + 1, 0);
  try {
    return await client
        .from('bookings')
        .select(
            'id, booking_number, check_in_date, check_out_date, status,'
            ' num_adults, num_children, guests:primary_guest_id(full_name)')
        .gte('check_in_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('check_in_date', DateFormat('yyyy-MM-dd').format(end))
        .neq('status', 'CANCELLED')
        .order('check_in_date', ascending: true);
  } catch (_) {
    // Offline: return demo bookings for the current month only
    if (month.year != DateTime.now().year ||
        month.month != DateTime.now().month) return [];
    return _buildDemoBookings();
  }
});

/// Build demo bookings with safe date arithmetic (no day overflow).
List<Map<String, dynamic>> _buildDemoBookings() {
  final now      = DateTime.now();
  final lastDay  = DateTime(now.year, now.month + 1, 0).day; // last day of month

  DateTime safeDate(int addDays) {
    final d = now.add(Duration(days: addDays));
    // Clamp to same month so date strings stay valid
    if (d.month != now.month) {
      return DateTime(now.year, now.month, lastDay);
    }
    return d;
  }

  String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  return [
    {
      'id': 'cb1', 'booking_number': 'BK-001',
      'check_in_date' : fmt(safeDate(0)),
      'check_out_date': fmt(safeDate(2)),
      'status': 'CHECKED_IN', 'num_adults': 2, 'num_children': 0,
      'guests': {'full_name': 'Rahul Sharma'},
    },
    {
      'id': 'cb2', 'booking_number': 'BK-002',
      'check_in_date' : fmt(safeDate(1)),
      'check_out_date': fmt(safeDate(3)),
      'status': 'CONFIRMED', 'num_adults': 4, 'num_children': 2,
      'guests': {'full_name': 'Priya Patel'},
    },
    {
      'id': 'cb3', 'booking_number': 'BK-003',
      'check_in_date' : fmt(safeDate(3)),
      'check_out_date': fmt(safeDate(5)),
      'status': 'CONFIRMED', 'num_adults': 2, 'num_children': 1,
      'guests': {'full_name': 'Amit Desai'},
    },
    {
      'id': 'cb4', 'booking_number': 'BK-004',
      'check_in_date' : fmt(safeDate(5)),
      'check_out_date': fmt(safeDate(7)),
      'status': 'CONFIRMED', 'num_adults': 3, 'num_children': 0,
      'guests': {'full_name': 'Meena Gupta'},
    },
    {
      'id': 'cb5', 'booking_number': 'BK-005',
      'check_in_date' : fmt(safeDate(7)),
      'check_out_date': fmt(safeDate(10)),
      'status': 'INQUIRY', 'num_adults': 6, 'num_children': 2,
      'guests': {'full_name': 'Suresh Patil'},
    },
  ];
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class BookingCalendarScreen extends ConsumerStatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  ConsumerState<BookingCalendarScreen> createState() =>
      _BookingCalendarScreenState();
}

class _BookingCalendarScreenState
    extends ConsumerState<BookingCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  // ── Date helpers ─────────────────────────────────────────────────────────────

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  /// True if [day] falls within [checkIn, checkOut) — open-ended on checkout.
  bool _dayInStay(Map<String, dynamic> b, DateTime day) {
    final ci = _parseDate(b['check_in_date'] as String?);
    final co = _parseDate(b['check_out_date'] as String?);
    if (ci == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final ciNorm = DateTime(ci.year, ci.month, ci.day);
    if (co == null) return isSameDay(d, ciNorm);
    final coNorm = DateTime(co.year, co.month, co.day);
    return !d.isBefore(ciNorm) && d.isBefore(coNorm);
  }

  /// Returns ALL bookings that overlap with [day] (any night of the stay).
  List<Map<String, dynamic>> _bookingsForDay(
      List<Map<String, dynamic>> all, DateTime day) {
    return all.where((b) => _dayInStay(b, day)).toList();
  }

  /// Builds the event-dot map: every day of every stay gets dots.
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<Map<String, dynamic>> bookings) {
    final Map<DateTime, List<Map<String, dynamic>>> map = {};
    for (final b in bookings) {
      final ci = _parseDate(b['check_in_date'] as String?);
      final co = _parseDate(b['check_out_date'] as String?);
      if (ci == null) continue;
      final end = co ?? ci.add(const Duration(days: 1));
      DateTime cur = DateTime(ci.year, ci.month, ci.day);
      while (cur.isBefore(DateTime(end.year, end.month, end.day))) {
        map[cur] = (map[cur] ?? [])..add(b);
        cur = cur.add(const Duration(days: 1));
      }
    }
    return map;
  }

  /// Merge Supabase/demo bookings with session-local ones (dedup by id).
  List<Map<String, dynamic>> _merge(
      List<Map<String, dynamic>> remote,
      List<Map<String, dynamic>> session) {
    final ids    = remote.map((b) => b['id']).toSet();
    final extras = session.where((b) => !ids.contains(b['id'])).toList();
    return [...extras, ...remote];
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookingsAsync  = ref.watch(calendarBookingsProvider(_focusedDay));
    final sessionBookings = ref.watch(sessionBookingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Booking Calendar',
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Today',
            onPressed: () => setState(() {
              _focusedDay  = DateTime.now();
              _selectedDay = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );
            }),
          ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => _buildBody([], sessionBookings),
        error:   (_, __) => _buildBody([], sessionBookings),
        data:    (remote) => _buildBody(remote, sessionBookings),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bookings/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildBody(
      List<Map<String, dynamic>> remote,
      List<Map<String, dynamic>> session) {
    final all       = _merge(remote, session);
    final eventMap  = _buildEventMap(all);
    final dayList   = _selectedDay == null
        ? <Map<String, dynamic>>[]
        : _bookingsForDay(all, _selectedDay!);

    return Column(
      children: [
        // ── Calendar ──────────────────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          child: TableCalendar(
            firstDay : DateTime(2024, 1, 1),
            lastDay  : DateTime(2028, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return eventMap[key] ?? [];
            },
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay  = focused;
              });
            },
            onFormatChanged: (f) => setState(() => _calendarFormat = f),
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
              ref.invalidate(calendarBookingsProvider(focused));
            },
            calendarBuilders: CalendarBuilders(
              // Colour-code day cells that have bookings
              defaultBuilder: (ctx, day, _) =>
                  _stayCell(day, eventMap, isSelected: false, isToday: false),
              todayBuilder: (ctx, day, _) =>
                  _stayCell(day, eventMap, isSelected: false, isToday: true),
              selectedBuilder: (ctx, day, _) =>
                  _stayCell(day, eventMap, isSelected: true, isToday: false),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle : const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              weekendTextStyle : const TextStyle(color: AppTheme.error,       fontSize: 14),
              outsideTextStyle : TextStyle(color: AppTheme.textPrimary.withOpacity(0.3), fontSize: 14),
              disabledTextStyle: TextStyle(color: AppTheme.textPrimary.withOpacity(0.2), fontSize: 14),
              todayDecoration  : BoxDecoration(color: AppTheme.primary.withOpacity(0.25), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              markerDecoration : const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
              markersMaxCount  : 3,
              markerSize       : 5,
              markerMargin     : const EdgeInsets.symmetric(horizontal: 0.3),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(color: AppTheme.error,       fontSize: 12, fontWeight: FontWeight.w600),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible  : true,
              titleCentered        : true,
              titleTextStyle       : TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              leftChevronIcon      : Icon(Icons.chevron_left,  color: AppTheme.textPrimary),
              rightChevronIcon     : Icon(Icons.chevron_right, color: AppTheme.textPrimary),
              formatButtonDecoration: BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              formatButtonTextStyle: TextStyle(color: AppTheme.primary, fontSize: 12),
            ),
          ),
        ),

        // ── Legend ────────────────────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(children: [
            _LegendDot(color: const Color(0xFF2E7D32), label: 'Checked-in'),
            const SizedBox(width: 16),
            _LegendDot(color: AppTheme.primary,        label: 'Confirmed'),
            const SizedBox(width: 16),
            _LegendDot(color: AppTheme.warning,        label: 'Inquiry'),
            const SizedBox(width: 16),
            _LegendDot(color: AppTheme.info,           label: 'Other'),
          ]),
        ),

        // ── Day's bookings ────────────────────────────────────────────────────
        Expanded(child: _buildDayList(dayList)),
      ],
    );
  }

  /// A calendar day cell that is tinted when the day is booked.
  Widget _stayCell(
    DateTime day,
    Map<DateTime, List<Map<String, dynamic>>> eventMap, {
    required bool isSelected,
    required bool isToday,
  }) {
    final key      = DateTime(day.year, day.month, day.day);
    final bookings = eventMap[key] ?? [];
    final hasStay  = bookings.isNotEmpty;

    Color? bg;
    if (isSelected) {
      bg = AppTheme.primary;
    } else if (hasStay) {
      // Tint by primary status of overlapping bookings
      final statuses = bookings.map((b) => b['status'] as String? ?? '').toSet();
      if (statuses.contains('CHECKED_IN'))  bg = const Color(0xFF2E7D32).withOpacity(0.18);
      else if (statuses.contains('CONFIRMED')) bg = AppTheme.primary.withOpacity(0.12);
      else if (statuses.contains('INQUIRY'))   bg = AppTheme.warning.withOpacity(0.15);
      else bg = AppTheme.info.withOpacity(0.1);
    } else if (isToday) {
      bg = AppTheme.primary.withOpacity(0.25);
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday
                  ? AppTheme.error
                  : AppTheme.textPrimary),
          fontSize: 13,
          fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDayList(List<Map<String, dynamic>> dayBookings) {
    final dayStr = _selectedDay == null
        ? ''
        : DateFormat('d MMMM yyyy').format(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  dayStr,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayBookings.length} booking${dayBookings.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              if (dayBookings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _CountChip(
                    label: 'Checked In',
                    count: dayBookings.where((b) => b['status'] == 'CHECKED_IN').length,
                    color: const Color(0xFF2E7D32),
                  ),
                  _CountChip(
                    label: 'Confirmed',
                    count: dayBookings.where((b) => b['status'] == 'CONFIRMED').length,
                    color: AppTheme.primary,
                  ),
                  _CountChip(
                    label: 'Inquiry',
                    count: dayBookings.where((b) => b['status'] == 'INQUIRY').length,
                    color: AppTheme.warning,
                  ),
                  _CountChip(
                    label: 'Adv. Paid',
                    count: dayBookings.where((b) => b['status'] == 'ADVANCE_PAID').length,
                    color: const Color(0xFF6A1B9A),
                  ),
                ].where((c) => (c as _CountChip).count > 0).toList()),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: dayBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 48,
                          color: AppTheme.textPrimary.withOpacity(0.35)),
                      const SizedBox(height: 8),
                      Text('No bookings on $dayStr',
                          style: TextStyle(
                              color: AppTheme.textPrimary.withOpacity(0.6))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dayBookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _CalendarBookingTile(booking: dayBookings[i]),
                ),
        ),
      ],
    );
  }
}

// ── Count chip (day summary bar) ──────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text('$count $label',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textPrimary.withOpacity(0.7))),
      ]);
}

// ── Calendar Booking Tile ─────────────────────────────────────────────────────

class _CalendarBookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _CalendarBookingTile({required this.booking});

  static const _statusColors = {
    'CONFIRMED'   : Color(0xFF1565C0),
    'CHECKED_IN'  : Color(0xFF2E7D32),
    'ADVANCE_PAID': Color(0xFF6A1B9A),
    'INQUIRY'     : Color(0xFFF57C00),
    'CHECKED_OUT' : Color(0xFF00838F),
    'CANCELLED'   : Color(0xFFB71C1C),
  };
  static const _statusLabels = {
    'CONFIRMED'   : 'Confirmed',
    'CHECKED_IN'  : 'Checked In',
    'ADVANCE_PAID': 'Advance Paid',
    'INQUIRY'     : 'Inquiry',
    'CHECKED_OUT' : 'Checked Out',
    'CANCELLED'   : 'Cancelled',
  };

  static String _fmt(String? s) {
    if (s == null || s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'CONFIRMED';
    final color  = _statusColors[status] ?? AppTheme.textHint;
    final label  = _statusLabels[status] ?? status.replaceAll('_', ' ');

    // Guest name — Supabase nests it; session bookings store it flat
    final guestMap  = booking['guests'] as Map<String, dynamic>?;
    final guestName = guestMap?['full_name'] as String?
        ?? booking['guest_name']  as String?
        ?? booking['full_name']   as String?
        ?? 'Guest';

    final bookingNo = booking['booking_number'] as String?
        ?? booking['id'] as String? ?? '';
    final checkIn  = booking['check_in_date']  as String? ?? '';
    final checkOut = booking['check_out_date'] as String? ?? '';
    final adults   = (booking['num_adults']   as num?)?.toInt() ?? 0;
    final children = (booking['num_children'] as num?)?.toInt() ?? 0;
    final total    = (booking['total_amount'] as num?)?.toDouble();
    final roomType = booking['room_type_name'] as String?
        ?? booking['package_name'] as String?;
    final roomNo   = booking['room_number'] as String?;

    // Nights
    int nights = 0;
    if (checkIn.isNotEmpty && checkOut.isNotEmpty) {
      final ci = DateTime.tryParse(checkIn);
      final co = DateTime.tryParse(checkOut);
      if (ci != null && co != null) nights = co.difference(ci).inDays;
    }

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Colour sidebar ──────────────────────────────────────────
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppTheme.radiusMD)),
                ),
              ),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Row 1: Guest name + status badge
                      Row(children: [
                        Expanded(
                          child: Text(
                            guestName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11, color: color,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 5),

                      // Row 2: Booking number + room type
                      Row(children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(bookingNo,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600)),
                        if (roomNo != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.hotel_outlined,
                              size: 12, color: AppTheme.textHint),
                          const SizedBox(width: 4),
                          Text('Room $roomNo',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                        if (roomType != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('• $roomType',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textHint),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 6),

                      // Row 3: Dates + nights
                      Row(children: [
                        const Icon(Icons.login_rounded,
                            size: 13, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(_fmt(checkIn),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 11, color: AppTheme.textHint),
                        ),
                        const Icon(Icons.logout_rounded,
                            size: 13, color: Color(0xFFB71C1C)),
                        const SizedBox(width: 4),
                        Text(_fmt(checkOut),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500)),
                        if (nights > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$nights N',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 5),

                      // Row 4: Pax + total
                      Row(children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(
                          adults > 0
                              ? '$adults Adult${adults != 1 ? "s" : ""}'
                                  '${children > 0 ? "  +  $children Child${children != 1 ? "ren" : ""}" : ""}'
                              : 'Guests TBD',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        if (total != null && total > 0) ...[
                          const Icon(Icons.currency_rupee,
                              size: 12, color: AppTheme.success),
                          Text(
                            total.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppTheme.textHint),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
