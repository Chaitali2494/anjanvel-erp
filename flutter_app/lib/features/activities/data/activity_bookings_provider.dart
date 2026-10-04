import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

// ── Demo catalogue of activities ───────────────────────────────────────────────

final kActivityCatalogue = <Map<String, dynamic>>[
  {'id': 'a1', 'name': 'Heritage Walk',    'category': 'Cultural',   'price': 500.0,  'duration': '2 hrs', 'emoji': '🏛️'},
  {'id': 'a2', 'name': 'Pottery Class',    'category': 'Cultural',   'price': 400.0,  'duration': '3 hrs', 'emoji': '🏺'},
  {'id': 'a3', 'name': 'Farm Tour',        'category': 'Nature',     'price': 300.0,  'duration': '2 hrs', 'emoji': '🚜'},
  {'id': 'a4', 'name': 'Bonfire Evening',  'category': 'Leisure',    'price': 200.0,  'duration': '2 hrs', 'emoji': '🔥'},
  {'id': 'a5', 'name': 'Bullock Cart Ride','category': 'Cultural',   'price': 250.0,  'duration': '1 hr',  'emoji': '🐂'},
  {'id': 'a6', 'name': 'Bird Watching',    'category': 'Nature',     'price': 300.0,  'duration': '2 hrs', 'emoji': '🦜'},
  {'id': 'a7', 'name': 'Cooking Class',    'category': 'Cultural',   'price': 600.0,  'duration': '3 hrs', 'emoji': '👨‍🍳'},
  {'id': 'a8', 'name': 'Nature Walk',      'category': 'Nature',     'price': 200.0,  'duration': '2 hrs', 'emoji': '🌿'},
  {'id': 'a9', 'name': 'Zip Line',         'category': 'Adventure',  'price': 600.0,  'duration': '1 hr',  'emoji': '🪂'},
  {'id':'a10', 'name': 'Rappelling',       'category': 'Adventure',  'price': 800.0,  'duration': '3 hrs', 'emoji': '🧗'},
];

// ── Demo currently checked-in rooms ───────────────────────────────────────────

final kCheckedInRooms = <Map<String, dynamic>>[
  {'room_number': '101', 'guest_name': 'Priya Sharma',  'room_type': 'Deluxe', 'nights': 3},
  {'room_number': '102', 'guest_name': 'Rajesh Kumar',  'room_type': 'Suite',  'nights': 2},
  {'room_number': '201', 'guest_name': 'Anita Patel',   'room_type': 'Standard','nights': 1},
  {'room_number': '205', 'guest_name': 'Vikram Singh',  'room_type': 'Deluxe', 'nights': 4},
  {'room_number': '301', 'guest_name': 'Meena Gupta',   'room_type': 'Cottage', 'nights': 2},
  {'room_number': '302', 'guest_name': 'Suresh Patil',  'room_type': 'Cottage', 'nights': 3},
];

// ── Module-level session state — persists across navigations ──────────────────

List<Map<String, dynamic>> _sessionBookings = <Map<String, dynamic>>[
  // Pre-seeded demo bookings (room 205 so billing demo shows data)
  {
    'id': 'demo1',
    'room_number': '205',
    'activity_name': 'Heritage Walk',
    'activity_emoji': '🏛️',
    'persons': 2,
    'price_per_person': 500.0,
    'total_amount': 1000.0,
    'date': _today(),
    'time': '09:00 AM',
    'status': 'CONFIRMED',
    'guest_name': 'Vikram Singh',
    'created_at': DateTime.now().toIso8601String(),
  },
  {
    'id': 'demo2',
    'room_number': '205',
    'activity_name': 'Pottery Class',
    'activity_emoji': '🏺',
    'persons': 1,
    'price_per_person': 400.0,
    'total_amount': 400.0,
    'date': _today(),
    'time': '02:00 PM',
    'status': 'CONFIRMED',
    'guest_name': 'Vikram Singh',
    'created_at': DateTime.now().toIso8601String(),
  },
];
bool _sessionUseLocal = false;

String _today() => DateTime.now().toIso8601String().substring(0, 10);

// ── StateNotifier ──────────────────────────────────────────────────────────────

class ActivityBookingsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final SupabaseClient _client;

  ActivityBookingsNotifier(this._client) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('activity_registrations')
          .select('*')
          .order('created_at', ascending: false);
      _sessionUseLocal = false;
      _sessionBookings = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionBookings));
    } catch (_) {
      _sessionUseLocal = true;
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionBookings));
    }
  }

  Future<void> refresh() => _load();

  // ── Book an activity ────────────────────────────────────────────────────────

  Future<void> addBooking(Map<String, dynamic> booking) async {
    if (_sessionUseLocal) {
      final newBooking = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'CONFIRMED',
        ...booking,
      };
      _sessionBookings = <Map<String, dynamic>>[newBooking, ..._sessionBookings];
      state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionBookings));
    } else {
      try {
        await _client.from('activity_registrations').insert(<String, dynamic>{
          ...booking,
          'created_at': DateTime.now().toIso8601String(),
          'status': 'CONFIRMED',
        });
        await _load();
      } catch (_) {
        // Fall back to local if Supabase insert fails
        _sessionUseLocal = true;
        final newBooking = <String, dynamic>{
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'CONFIRMED',
          ...booking,
        };
        _sessionBookings = <Map<String, dynamic>>[newBooking, ..._sessionBookings];
        state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionBookings));
      }
    }
  }

  // ── Cancel a booking ────────────────────────────────────────────────────────

  Future<void> cancelBooking(String id) async {
    _sessionBookings = _sessionBookings.map((b) {
      if (b['id'] == id) return <String, dynamic>{...b, 'status': 'CANCELLED'};
      return b;
    }).toList();
    state = AsyncValue.data(List<Map<String, dynamic>>.from(_sessionBookings));
  }

  // ── Get bookings for a specific room ───────────────────────────────────────
  List<Map<String, dynamic>> bookingsForRoom(String roomNumber) =>
      _sessionBookings
          .where((b) =>
              b['room_number'] == roomNumber && b['status'] != 'CANCELLED')
          .toList();

  double totalForRoom(String roomNumber) => bookingsForRoom(roomNumber)
      .fold(0.0, (sum, b) => sum + ((b['total_amount'] as num?)?.toDouble() ?? 0.0));
}

// ── Provider ──────────────────────────────────────────────────────────────────

final activityBookingsProvider = StateNotifierProvider<
    ActivityBookingsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ActivityBookingsNotifier(client);
});
