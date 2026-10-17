import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shop charge linked to a room
class ShopRoomCharge {
  final String product, roomNumber;
  final double price;
  final int qty;
  final DateTime time;

  ShopRoomCharge({
    required this.product,
    required this.roomNumber,
    required this.price,
    required this.qty,
  }) : time = DateTime.now();

  double get total => price * qty;
}

// Session-level storage (survives navigation, cleared on app restart)
List<ShopRoomCharge> _sessionShopCharges = [];

class ShopRoomChargesNotifier extends StateNotifier<List<ShopRoomCharge>> {
  ShopRoomChargesNotifier() : super(_sessionShopCharges);

  void addCharge(ShopRoomCharge charge) {
    _sessionShopCharges = [charge, ..._sessionShopCharges];
    state = List.from(_sessionShopCharges);
  }

  /// All charges for a specific room number
  List<ShopRoomCharge> chargesForRoom(String roomNumber) =>
      state.where((c) => c.roomNumber == roomNumber).toList();
}

final shopRoomChargesProvider =
    StateNotifierProvider<ShopRoomChargesNotifier, List<ShopRoomCharge>>(
  (ref) => ShopRoomChargesNotifier(),
);
