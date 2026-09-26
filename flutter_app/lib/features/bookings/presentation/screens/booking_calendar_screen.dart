import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// Provider: fetch bookings for a given month
final calendarBookingsProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, month) async {
  final client = ref.watch(supabaseClientProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  return await client
      .from('bookings')
      .select('id, booking_number, check_in_date, check_out_date, status, num_adults, num_children, guests:primary_guest_id(full_name)')
      .gte('check_in_date', DateFormat('yyyy-MM-dd').format(start))
      .lte('check_in_date', DateFormat('yyyy-MM-dd').format(end))
      .neq('status', 'CANCELLED')
      .order('check_in_date', ascending: true);
});

class BookingCalendarScreen extends ConsumerStatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  ConsumerState<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends ConsumerState<BookingCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  List<Map<String, dynamic>> _getBookingsForDay(List<Map<String, dynamic>> all, DateTime day) {
    final dayStr = DateFormat('yyyy-MM-dd').format(day);
    return all.where((b) => b['check_in_date'] == dayStr).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(calendarBookingsProvider(_focusedDay));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Booking Calendar',
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Today',
            onPressed: () => setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            color: AppTheme.surface,
            child: bookingsAsync.when(
              loading: () => _buildCalendar([], {}),
              error: (_, __) => _buildCalendar([], {}),
              data: (bookings) {
                // Build event map: date -> list of bookings
                final Map<DateTime, List<Map<String, dynamic>>> events = {};
                for (final b in bookings) {
                  final dateStr = b['check_in_date'] as String?;
                  if (dateStr == null) continue;
                  final parts = dateStr.split('-');
                  if (parts.length != 3) continue;
                  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                  events[date] = (events[date] ?? [])..add(b);
                }
                return _buildCalendar(bookings, events);
              },
            ),
          ),

          // Bookings for selected day
          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bookings) {
                final selected = _selectedDay;
                if (selected == null) return const SizedBox();
                final dayBookings = _getBookingsForDay(bookings, selected);
                final dayStr = DateFormat('d MMMM yyyy').format(selected);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Check-ins on $dayStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${dayBookings.length} booking${dayBookings.length != 1 ? 's' : ''}',
                              style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: dayBookings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_available_outlined, size: 48, color: AppTheme.textHint.withOpacity(0.4)),
                                  const SizedBox(height: 8),
                                  Text('No check-ins on $dayStr',
                                      style: const TextStyle(color: AppTheme.textHint)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: dayBookings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _CalendarBookingTile(booking: dayBookings[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bookings/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildCalendar(List<Map<String, dynamic>> bookings, Map<DateTime, List<Map<String, dynamic>>> events) {
    return TableCalendar(
      firstDay: DateTime(2024, 1, 1),
      lastDay: DateTime(2027, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return events[key] ?? [];
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) => setState(() => _calendarFormat = format),
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
        ref.invalidate(calendarBookingsProvider(focusedDay));
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: AppTheme.secondary,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        markerSize: 6,
        weekendTextStyle: const TextStyle(color: AppTheme.error),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonDecoration: BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        formatButtonTextStyle: TextStyle(color: AppTheme.primary, fontSize: 12),
      ),
    );
  }
}

// ── Calendar Booking Tile ─────────────────────────────────────────────────────

class _CalendarBookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _CalendarBookingTile({required this.booking});

  Color get _statusColor {
    switch (booking['status']) {
      case 'CONFIRMED': return AppTheme.success;
      case 'CHECKED_IN': return AppTheme.info;
      case 'INQUIRY': return AppTheme.warning;
      default: return AppTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = booking['guests'] as Map<String, dynamic>? ?? {};
    final guestName = guest['full_name'] as String? ?? 'Guest';
    final status = booking['status'] as String? ?? '';
    final checkOut = booking['check_out_date'] as String?;
    final adults = booking['num_adults'] as int? ?? 0;
    final children = booking['num_children'] as int? ?? 0;

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking['id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: _statusColor.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        booking['booking_number'] as String? ?? '',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                      if (checkOut != null) ...[
                        const Text(' · ', style: TextStyle(color: AppTheme.textHint)),
                        const Icon(Icons.logout_rounded, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 3),
                        Text(checkOut, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ],
                      const Text(' · ', style: TextStyle(color: AppTheme.textHint)),
                      const Icon(Icons.people_outline, size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 3),
                      Text('$adults A $children C', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
