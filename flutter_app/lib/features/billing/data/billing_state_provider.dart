import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activities/data/activity_bookings_provider.dart';

// ── Demo rooms eligible for billing (booked / advance-paid / checked-in) ───────

final kBillableRooms = <Map<String, dynamic>>[
  {
    'room_number': '101',
    'guest_name': 'Priya Sharma',
    'room_type': 'Deluxe',
    'nights': 3,
    'rate': 3500.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-06',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '102',
    'guest_name': 'Rajesh Kumar',
    'room_type': 'Suite',
    'nights': 2,
    'rate': 5500.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-07',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '201',
    'guest_name': 'Anita Patel',
    'room_type': 'Standard',
    'nights': 1,
    'rate': 2000.0,
    'status': 'BOOKED',
    'check_in': '2026-10-08',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '205',
    'guest_name': 'Vikram Singh',
    'room_type': 'Deluxe',
    'nights': 4,
    'rate': 3500.0,
    'status': 'CHECKED_IN',
    'check_in': '2026-10-05',
    'check_out': '2026-10-09',
  },
  {
    'room_number': '301',
    'guest_name': 'Meena Gupta',
    'room_type': 'Cottage',
    'nights': 2,
    'rate': 4000.0,
    'status': 'ADVANCE_PAID',
    'check_in': '2026-10-08',
    'check_out': '2026-10-10',
  },
  {
    'room_number': '302',
    'guest_name': 'Suresh Patil',
    'room_type': 'Cottage',
    'nights': 3,
    'rate': 4000.0,
    'status': 'ADVANCE_PAID',
    'check_in': '2026-10-07',
    'check_out': '2026-10-10',
  },
];

// Demo food charges per room
const Map<String, double> kDemoFoodCharges = {
  '101': 1380.0,
  '102': 2100.0,
  '201': 430.0,
  '205': 1850.0,
  '301': 780.0,
  '302': 960.0,
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

// ── Helper: calculate total bill for a room ───────────────────────────────────

double calcRoomTotal(String roomNumber, List<Map<String, dynamic>> activityBookings) {
  final room = kBillableRooms.firstWhere(
    (r) => r['room_number'] == roomNumber,
    orElse: () => {},
  );
  if (room.isEmpty) return 0;

  final roomCharge = (room['rate'] as num).toDouble() * (room['nights'] as int);
  final foodCharge = kDemoFoodCharges[roomNumber] ?? 0.0;
  final activityCharge = activityBookings
      .where((b) => b['room_number'] == roomNumber && b['status'] != 'CANCELLED')
      .fold(0.0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0.0));

  final subtotal = roomCharge + foodCharge + activityCharge;
  return subtotal * 1.12; // +12% GST
}
