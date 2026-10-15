import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Session-persistent food orders (same pattern as activity bookings) ─────────

final List<Map<String, dynamic>> _sessionOrders = [
  {
    'id': '1',
    'order_number': 'FO-001',
    'status': 'PENDING',
    'total_amount': 850.0,
    'meal_type': 'BREAKFAST',
    'ordered_at': DateTime.now().toIso8601String(),
    'guests': {'full_name': 'Rahul Sharma'},
    'bookings': {'booking_number': 'BK-001', 'room_number': 'R01'},
    'items': [
      {'name': 'Breakfast Plate', 'qty': 2, 'price': 250.0},
      {'name': 'Masala Chai',     'qty': 7, 'price': 40.0},
    ],
  },
  {
    'id': '2',
    'order_number': 'FO-002',
    'status': 'PREPARING',
    'total_amount': 1200.0,
    'meal_type': 'LUNCH',
    'ordered_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    'guests': {'full_name': 'Priya Patel'},
    'bookings': {'booking_number': 'BK-002', 'room_number': 'T01'},
    'items': [
      {'name': 'Veg Thali',   'qty': 2, 'price': 350.0},
      {'name': 'Fresh Juice', 'qty': 2, 'price': 80.0},
      {'name': 'Masala Chai', 'qty': 2, 'price': 40.0},
    ],
  },
  {
    'id': '3',
    'order_number': 'FO-003',
    'status': 'SERVED',
    'total_amount': 650.0,
    'meal_type': 'DINNER',
    'ordered_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    'guests': {'full_name': 'Amit Desai'},
    'bookings': {'booking_number': 'BK-003', 'room_number': 'D01'},
    'items': [
      {'name': 'BBQ Chicken', 'qty': 1, 'price': 380.0},
      {'name': 'Veg Starter', 'qty': 1, 'price': 220.0},
      {'name': 'Fresh Juice', 'qty': 1, 'price': 80.0},
    ],
  },
];

// ── Notifier ───────────────────────────────────────────────────────────────────

class FoodOrdersNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  FoodOrdersNotifier() : super(List.from(_sessionOrders));

  void addOrder(Map<String, dynamic> order) {
    _sessionOrders.insert(0, order);
    state = List.from(_sessionOrders);
  }

  void updateStatus(String id, String newStatus) {
    final idx = _sessionOrders.indexWhere((o) => o['id'] == id);
    if (idx >= 0) {
      _sessionOrders[idx] = {..._sessionOrders[idx], 'status': newStatus};
      state = List.from(_sessionOrders);
    }
  }

  /// All non-cancelled orders for a given room number
  List<Map<String, dynamic>> ordersForRoom(String roomNumber) =>
      _sessionOrders
          .where((o) =>
              (_roomNo(o) == roomNumber) && o['status'] != 'CANCELLED')
          .toList();

  double totalForRoom(String roomNumber) =>
      ordersForRoom(roomNumber)
          .fold(0.0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0.0));

  static String _roomNo(Map<String, dynamic> o) =>
      (o['bookings'] as Map<String, dynamic>?)?['room_number'] as String? ?? '';
}

final foodOrdersStateProvider =
    StateNotifierProvider<FoodOrdersNotifier, List<Map<String, dynamic>>>(
        (ref) => FoodOrdersNotifier());
