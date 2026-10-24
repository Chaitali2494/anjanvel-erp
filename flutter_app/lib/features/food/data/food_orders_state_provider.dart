import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guest_sync.dart';
import '../../../core/services/cloud_store.dart';

const _cloudCollection = 'food_orders';

// ── Session-persistent food orders ─────────────────────────────────────────────

final List<Map<String, dynamic>> _sessionOrders = [
  {
    'id': '1',
    'order_number': 'FO-001',
    'status': 'PENDING',
    'total_amount': 850.0,
    'meal_type': 'BREAKFAST',
    'ordered_at': DateTime.now().toIso8601String(),
    'guests': {'full_name': 'Priya Sharma'},
    'bookings': {'booking_number': 'BK-001', 'room_number': '101'},
    'items': [
      {'name': 'Veg Breakfast Thali', 'qty': 2, 'price': 320.0},
      {'name': 'Masala Chai',         'qty': 2, 'price': 40.0},
      {'name': 'Mango Lassi',         'qty': 1, 'price': 90.0},
    ],
  },
  {
    'id': '2',
    'order_number': 'FO-002',
    'status': 'PREPARING',
    'total_amount': 1200.0,
    'meal_type': 'LUNCH',
    'ordered_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    'guests': {'full_name': 'Rajesh Kumar'},
    'bookings': {'booking_number': 'BK-002', 'room_number': '102'},
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
    'guests': {'full_name': 'Anita Patel'},
    'bookings': {'booking_number': 'BK-003', 'room_number': '201'},
    'items': [
      {'name': 'BBQ Chicken', 'qty': 1, 'price': 380.0},
      {'name': 'Veg Starter', 'qty': 1, 'price': 220.0},
      {'name': 'Fresh Juice', 'qty': 1, 'price': 80.0},
    ],
  },
  {
    'id': '4',
    'order_number': 'FO-004',
    'status': 'DELIVERED',
    'total_amount': 560.0,
    'meal_type': 'LUNCH',
    'ordered_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    'guests': {'full_name': 'Suresh Mehta'},
    'bookings': {'booking_number': 'BK-004', 'room_number': '301'},
    'items': [
      {'name': 'Veg Thali',   'qty': 2, 'price': 250.0},
      {'name': 'Masala Chai', 'qty': 2, 'price': 40.0},
    ],
  },
];

// ── Notifier ───────────────────────────────────────────────────────────────────

class FoodOrdersNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  /// Cancel callbacks for BroadcastChannel listeners
  void Function()? _cancelOrderListener;
  void Function()? _cancelStatusListener;

  FoodOrdersNotifier() : super(List.from(_sessionOrders)) {
    // Merge any guest orders from localStorage (placed in another tab / prev session)
    _mergeFromStorage();
    // Listen for new orders / status updates broadcast by the guest portal tab
    _cancelOrderListener = GuestSync.listenForOrders((order) {
      if (!_sessionOrders.any((o) => o['id'] == order['id'])) {
        _sessionOrders.insert(0, order);
        state = List.from(_sessionOrders);
      }
    });
    _cancelStatusListener = GuestSync.listenForStatusUpdates((id, status) {
      final idx = _sessionOrders.indexWhere((o) => o['id'] == id);
      if (idx >= 0) {
        _sessionOrders[idx] = {..._sessionOrders[idx], 'status': status};
        state = List.from(_sessionOrders);
      }
    });
    _initCloud();
  }

  void Function()? _cancelCloud;

  /// Load saved orders from Supabase and listen for changes from other devices.
  Future<void> _initCloud() async {
    _applyRemote(await CloudStore.load(_cloudCollection));
    _cancelCloud = CloudStore.watch(_cloudCollection, (id, data, deleted) {
      if (deleted) {
        _sessionOrders.removeWhere((o) => o['id']?.toString() == id);
        if (mounted) state = List.from(_sessionOrders);
      } else {
        _applyRemote([data]);
      }
    });
  }

  void _applyRemote(List<Map<String, dynamic>> remote) {
    if (remote.isEmpty) return;
    for (final r in remote) {
      final idx = _sessionOrders.indexWhere((o) => o['id']?.toString() == r['id']?.toString());
      if (idx >= 0) {
        _sessionOrders[idx] = r;
      } else {
        _sessionOrders.insert(0, r);
      }
    }
    if (mounted) state = List.from(_sessionOrders);
  }

  void _save(Map<String, dynamic> order) =>
      CloudStore.put(_cloudCollection, order['id'].toString(), order);

  @override
  void dispose() {
    _cancelOrderListener?.call();
    _cancelStatusListener?.call();
    _cancelCloud?.call();
    super.dispose();
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _mergeFromStorage() {
    try {
      final stored = GuestSync.loadOrders();
      bool changed = false;
      for (final o in stored) {
        if (!_sessionOrders.any((s) => s['id'] == o['id'])) {
          _sessionOrders.insert(0, o);
          changed = true;
        }
      }
      if (changed) state = List.from(_sessionOrders);
    } catch (_) {}
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  void addOrder(Map<String, dynamic> order) {
    // Avoid duplicates (e.g. if listener fires before direct call resolves)
    if (_sessionOrders.any((o) => o['id'] == order['id'])) return;
    _sessionOrders.insert(0, order);
    state = List.from(_sessionOrders);
    _save(order);
    // Persist + broadcast so other tabs (management app) pick it up immediately
    if (order['source'] == 'GUEST_QR') {
      GuestSync.saveOrder(order);
    }
  }

  void updateStatus(String id, String newStatus) {
    final idx = _sessionOrders.indexWhere((o) => o['id'] == id);
    if (idx >= 0) {
      _sessionOrders[idx] = {..._sessionOrders[idx], 'status': newStatus};
      state = List.from(_sessionOrders);
      _save(_sessionOrders[idx]);
      GuestSync.updateOrderStatus(id, newStatus);
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
