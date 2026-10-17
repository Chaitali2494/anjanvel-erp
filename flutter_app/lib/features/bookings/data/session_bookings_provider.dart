import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped list of bookings created in this browser session.
/// Updated by [CreateBookingScreen] so the calendar and booking list
/// reflect newly created bookings without needing a Supabase round-trip.

// Module-level store — persists for the app session (same as food_orders pattern)
final List<Map<String, dynamic>> _sessionBookings = [];

class SessionBookingsNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  SessionBookingsNotifier() : super(List.from(_sessionBookings));

  void addBooking(Map<String, dynamic> booking) {
    // Avoid duplicates
    _sessionBookings.removeWhere((b) => b['id'] == booking['id']);
    _sessionBookings.insert(0, booking);
    state = List.from(_sessionBookings);
  }

  void updateStatus(String id, String newStatus) {
    final idx = _sessionBookings.indexWhere((b) => b['id'] == id);
    if (idx >= 0) {
      _sessionBookings[idx] = {..._sessionBookings[idx], 'status': newStatus};
      state = List.from(_sessionBookings);
    }
  }

  List<Map<String, dynamic>> get all => List.from(_sessionBookings);
}

final sessionBookingsProvider =
    StateNotifierProvider<SessionBookingsNotifier, List<Map<String, dynamic>>>(
        (ref) => SessionBookingsNotifier());
