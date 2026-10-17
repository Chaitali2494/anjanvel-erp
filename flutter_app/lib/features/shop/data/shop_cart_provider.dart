import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final String name, emoji, category, unit;
  final double price;
  int qty;

  CartItem({
    required this.name,
    required this.emoji,
    required this.category,
    required this.unit,
    required this.price,
    this.qty = 1,
  });

  double get total => price * qty;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem({
    required String name,
    required String emoji,
    required String category,
    required String unit,
    required double price,
  }) {
    final existing = state.indexWhere((i) => i.name == name);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state);
      updated[existing].qty++;
      state = updated;
    } else {
      state = [...state, CartItem(name: name, emoji: emoji, category: category, unit: unit, price: price)];
    }
  }

  void increment(String name) {
    final updated = List<CartItem>.from(state);
    final i = updated.indexWhere((c) => c.name == name);
    if (i >= 0) { updated[i].qty++; state = updated; }
  }

  void decrement(String name) {
    final updated = List<CartItem>.from(state);
    final i = updated.indexWhere((c) => c.name == name);
    if (i >= 0) {
      if (updated[i].qty > 1) {
        updated[i].qty--;
        state = updated;
      } else {
        updated.removeAt(i);
        state = updated;
      }
    }
  }

  void remove(String name) {
    state = state.where((c) => c.name != name).toList();
  }

  void clear() => state = [];

  double get subtotal => state.fold(0.0, (s, c) => s + c.total);
  int get itemCount  => state.fold(0, (s, c) => s + c.qty);
}

final shopCartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);
