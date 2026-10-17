import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activities/data/activity_bookings_provider.dart';
import '../../bookings/data/booking_service.dart';

// ── Demo rooms eligible for billing — keyed by DB room number (101–302) ────────
// Room numbers match v_room_availability + room_service.dart + sessionRoomBookings

final kBillableRooms = <Map<String, dynamic>>[
  {
    'room_number': '101',
    'guest_name': 'Priya Sharma',
    'room_type': 'Tent Stay',
    'nights': 3,
    'rate': 1500.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-06',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '102',
    'guest_name': 'Rajesh Kumar',
    'room_type': 'Dormitory (Small) Stay',
    'nights': 2,
    'rate': 3000.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-07',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '103',
    'guest_name': 'Anita Patel',
    'room_type': 'Dormitory (Large) Stay',
    'nights': 1,
    'rate': 6000.0,
    'status': 'BOOKED',
    'check_in': '2026-10-08',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '201',
    'guest_name': 'Vikram Singh',
    'room_type': 'Anjanpushp Villa',
    'nights': 4,
    'rate': 8000.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-05',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '202',
    'guest_name': 'Meena Gupta',
    'room_type': 'Deluxe/Cottage Room',
    'nights': 2,
    'rate': 3500.0,
    'status': 'ADVANCE_PAID',
    'check_in': '2026-10-08',
    'check_out': '2026-10-10',
  },
  {
    'room_number': '301',
    'guest_name': 'Suresh Patil',
    'room_type': 'Premium Room - Tikona View',
    'nights': 3,
    'rate': 5000.0,
    'status': 'ADVANCE_PAID',
    'check_in': '2026-10-07',
    'check_out': '2026-10-10',
  },
  {
    'room_number': '302',
    'guest_name': 'Kavita Desai',
    'room_type': 'Premium Room - Deck Bed',
    'nights': 2,
    'rate': 5500.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-07',
    'check_out': '2026-10-09',
  },
];

// Demo food charges per room (keyed by DB room number)
const Map<String, double> kDemoFoodCharges = {
  '101': 1380.0,
  '102': 2100.0,
  '103': 3200.0,
  '201': 4800.0,
  '202': 780.0,
  '301': 960.0,
  '302': 1150.0,
};

// ── Session state for payment tracking ────────────────────────────────────────

Map<String, Map<String, dynamic>> _sessionBillingState = {};

class BillingStateNotifier
    extends StateNotifier<Map<String, Map<String, dynamic>>> {
  BillingStateNotifier() : super(_sessionBillingState);

  void markPaid(String roomNumber, double amount) {
    _sessionBillingState = {
      ..._sessionBillingState,
      roomNumber: {
        'is_paid': true,
        'paid_at': DateTime.now().toIso8601String(),
        'amount': amount,
      },
    };
    state = Map<String, Map<String, dynamic>>.from(_sessionBillingState);
  }

  bool isPaid(String roomNumber) =>
      _sessionBillingState[roomNumber]?['is_paid'] == true;

  double? paidAmount(String roomNumber) =>
      (_sessionBillingState[roomNumber]?['amount'] as num?)?.toDouble();
}

final billingStateProvider = StateNotifierProvider<BillingStateNotifier,
    Map<String, Map<String, dynamic>>>((ref) => BillingStateNotifier());

// ── Helper: get actual nights from session booking or fall back to demo ────────

int getActualNights(String roomNumber) {
  // Check session room bookings first (populated when room is assigned)
  final session = sessionRoomBookings[roomNumber];
  if (session != null) {
    final ci  = DateTime.tryParse((session['check_in_date']  as String?) ?? '');
    final co  = DateTime.tryParse((session['check_out_date'] as String?) ?? '');
    if (ci != null && co != null && co.isAfter(ci)) {
      return co.difference(ci).inDays;
    }
  }
  // Fall back to kBillableRooms hardcoded nights
  final room = kBillableRooms.firstWhere(
    (r) => r['room_number'] == roomNumber,
    orElse: () => {},
  );
  return (room['nights'] as int?) ?? 1;
}

// ── Helper: get room info, merging session data over demo data ────────────────

Map<String, dynamic> getRoomInfo(String roomNumber) {
  final demo = kBillableRooms.firstWhere(
    (r) => r['room_number'] == roomNumber,
    orElse: () => <String, dynamic>{
      'room_number': roomNumber,
      'guest_name': 'Guest',
      'room_type': 'Room',
      'nights': 1,
      'rate': 3500.0,
      'persons': 1,
      'status': 'CHECKED_IN',
    },
  );

  final session = sessionRoomBookings[roomNumber];
  if (session == null) return {
    ...demo,
    'persons': demo['persons'] ?? 1,
  };

  // Merge: session data takes priority for guest name, dates, persons
  final ci  = DateTime.tryParse((session['check_in_date']  as String?) ?? '');
  final co  = DateTime.tryParse((session['check_out_date'] as String?) ?? '');
  final actualNights = (ci != null && co != null && co.isAfter(ci))
      ? co.difference(ci).inDays
      : (demo['nights'] as int? ?? 1);

  final guestName = (session['guests'] as Map<String, dynamic>?)?['full_name']
      as String?
      ?? demo['guest_name'] as String? ?? 'Guest';

  // persons = adults from session booking; fall back to demo or 1
  final sessionAdults = (session['num_adults'] as num?)?.toInt();
  final persons = sessionAdults != null && sessionAdults > 0
      ? sessionAdults
      : (demo['persons'] as int? ?? 1);

  // rate: prefer rate stored in session (from room assignment), then demo
  final sessionRate = (session['rate'] as num?)?.toDouble();
  final rate = sessionRate != null && sessionRate > 0
      ? sessionRate
      : (demo['rate'] as num?)?.toDouble() ?? 3500.0;

  return {
    ...demo,
    'guest_name': guestName,
    'nights':     actualNights,
    'persons':    persons,
    'rate':       rate,
    'room_type':  session['room_type_name'] ?? demo['room_type'] ?? 'Room',
    'check_in':   session['check_in_date']  ?? demo['check_in'],
    'check_out':  session['check_out_date'] ?? demo['check_out'],
  };
}

// ── Helper: calculate total bill for a room ───────────────────────────────────

double calcRoomTotal(String roomNumber, List<Map<String, dynamic>> activityBookings) {
  final room = getRoomInfo(roomNumber);

  final nights     = room['nights'] as int;
  final rate       = (room['rate'] as num).toDouble();
  final roomCharge = rate * nights;
  final foodCharge = kDemoFoodCharges[roomNumber] ?? 0.0;
  final activityCharge = activityBookings
      .where((b) => b['room_number'] == roomNumber && b['status'] != 'CANCELLED')
      .fold(0.0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0.0));

  final subtotal = roomCharge + foodCharge + activityCharge;
  return subtotal * 1.12; // +12% GST
}
