import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_store.dart';

const _cloudCollection = 'session_bookings';

/// Session-scoped list of bookings created in this browser session.
/// Updated by [CreateBookingScreen] so the calendar and booking list
/// reflect newly created bookings without needing a Supabase round-trip.

// Module-level store — persists for the app session (same as food_orders pattern)
final List<Map<String, dynamic>> _sessionBookings = [];

class SessionBookingsNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  SessionBookingsNotifier() : super(List.from(_sessionBookings)) {
    _initCloud();
  }

  void Function()? _cancelCloud;

  Future<void> _initCloud() async {
    _applyRemote(await CloudStore.load(_cloudCollection));
    _cancelCloud = CloudStore.watch(_cloudCollection, (id, data, deleted) {
      if (deleted) {
        _sessionBookings.removeWhere((b) => b['id']?.toString() == id);
        if (mounted) state = List.from(_sessionBookings);
      } else {
        _applyRemote([data]);
      }
    });
  }

  void _applyRemote(List<Map<String, dynamic>> remote) {
    if (remote.isEmpty) return;
    for (final r in remote) {
      final idx = _sessionBookings.indexWhere((b) => b['id']?.toString() == r['id']?.toString());
      if (idx >= 0) {
        _sessionBookings[idx] = r;
      } else {
        _sessionBookings.insert(0, r);
      }
    }
    if (mounted) state = List.from(_sessionBookings);
  }

  void _save(Map<String, dynamic> b) {
    if (b['id'] == null) return;
    CloudStore.put(_cloudCollection, b['id'].toString(), b);
  }

  @override
  void dispose() {
    _cancelCloud?.call();
    super.dispose();
  }

  void addBooking(Map<String, dynamic> booking) {
    // Avoid duplicates
    _sessionBookings.removeWhere((b) => b['id'] == booking['id']);
    _sessionBookings.insert(0, booking);
    state = List.from(_sessionBookings);
    _save(booking);
  }

  void updateStatus(String id, String newStatus) {
    final idx = _sessionBookings.indexWhere((b) => b['id'] == id);
    if (idx >= 0) {
      _sessionBookings[idx] = {..._sessionBookings[idx], 'status': newStatus};
      state = List.from(_sessionBookings);
      _save(_sessionBookings[idx]);
    }
  }

  /// Sets status to CHECKED_IN and stores the actual check-in timestamp.
  void setCheckedIn(String id) {
    final idx = _sessionBookings.indexWhere((b) => b['id'] == id);
    if (idx >= 0) {
      _sessionBookings[idx] = {
        ..._sessionBookings[idx],
        'status': 'CHECKED_IN',
        'checked_in_at': DateTime.now().toIso8601String(),
      };
      state = List.from(_sessionBookings);
      _save(_sessionBookings[idx]);
    }
  }

  List<Map<String, dynamic>> get all => List.from(_sessionBookings);
}

final sessionBookingsProvider =
    StateNotifierProvider<SessionBookingsNotifier, List<Map<String, dynamic>>>(
        (ref) => SessionBookingsNotifier());
