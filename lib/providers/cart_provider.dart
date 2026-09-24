import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';

/// Carrito en memoria. Vive mientras la app está abierta; en un paso futuro
/// lo podemos persistir en Supabase (tabla 'orders') al hacer checkout.
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(MenuItem menuItem, {int quantity = 1}) {
    final index = state.indexWhere((c) => c.menuItem.id == menuItem.id);

    if (index == -1) {
      state = [...state, CartItem(menuItem: menuItem, quantity: quantity)];
    } else {
      final updated = [...state];
      updated[index] =
          updated[index].copyWith(quantity: updated[index].quantity + quantity);
      state = updated;
    }
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }
    state = [
      for (final c in state)
        if (c.menuItem.id == menuItemId) c.copyWith(quantity: quantity) else c,
    ];
  }

  void removeItem(String menuItemId) {
    state = state.where((c) => c.menuItem.id != menuItemId).toList();
  }

  void clear() {
    state = [];
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold(0.0, (sum, item) => sum + item.totalPrice);
});

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(0, (sum, item) => sum + item.quantity);
});