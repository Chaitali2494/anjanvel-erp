import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_store.dart';

const _cloudCharges = 'shop_room_charges';

/// One shop charge linked to a room
class ShopRoomCharge {
  final String product, roomNumber;
  final double price;
  final int qty;
  final DateTime time;

  final String id;

  ShopRoomCharge({
    required this.product,
    required this.roomNumber,
    required this.price,
    required this.qty,
    DateTime? time,
    String? id,
  })  : time = time ?? DateTime.now(),
        id = id ?? '${DateTime.now().microsecondsSinceEpoch}';

  double get total => price * qty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': product,
        'room_number': roomNumber,
        'price': price,
        'qty': qty,
        'time': time.toIso8601String(),
      };

  factory ShopRoomCharge.fromJson(Map<String, dynamic> j) => ShopRoomCharge(
        id: j['id']?.toString(),
        product: j['product']?.toString() ?? '',
        roomNumber: j['room_number']?.toString() ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        time: DateTime.tryParse(j['time']?.toString() ?? '')?.toLocal(),
      );
}

// Session-level storage (survives navigation, cleared on app restart)
List<ShopRoomCharge> _sessionShopCharges = [];

class ShopRoomChargesNotifier extends StateNotifier<List<ShopRoomCharge>> {
  ShopRoomChargesNotifier() : super(_sessionShopCharges) {
    _initCloud();
  }

  void Function()? _cancelCloud;

  Future<void> _initCloud() async {
    _applyRemote(await CloudStore.load(_cloudCharges));
    _cancelCloud = CloudStore.watch(_cloudCharges, (id, data, deleted) {
      if (deleted) {
        _sessionShopCharges = _sessionShopCharges.where((c) => c.id != id).toList();
        if (mounted) state = List.from(_sessionShopCharges);
      } else {
        _applyRemote([data]);
      }
    });
  }

  void _applyRemote(List<Map<String, dynamic>> remote) {
    if (remote.isEmpty) return;
    final list = List<ShopRoomCharge>.from(_sessionShopCharges);
    for (final r in remote) {
      final c = ShopRoomCharge.fromJson(r);
      final idx = list.indexWhere((x) => x.id == c.id);
      if (idx >= 0) {
        list[idx] = c;
      } else {
        list.add(c);
      }
    }
    list.sort((a, b) => b.time.compareTo(a.time));
    _sessionShopCharges = list;
    if (mounted) state = List.from(_sessionShopCharges);
  }

  @override
  void dispose() {
    _cancelCloud?.call();
    super.dispose();
  }

  void addCharge(ShopRoomCharge charge) {
    _sessionShopCharges = [charge, ..._sessionShopCharges];
    state = List.from(_sessionShopCharges);
    CloudStore.put(_cloudCharges, charge.id, charge.toJson());
  }

  /// All charges for a specific room number
  List<ShopRoomCharge> chargesForRoom(String roomNumber) =>
      state.where((c) => c.roomNumber == roomNumber).toList();
}

final shopRoomChargesProvider =
    StateNotifierProvider<ShopRoomChargesNotifier, List<ShopRoomCharge>>(
  (ref) => ShopRoomChargesNotifier(),
);
