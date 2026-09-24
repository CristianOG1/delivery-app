import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi carrito')),
      body: cartItems.isEmpty
          ? const Center(child: Text('Tu carrito está vacío'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cartItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final cartItem = cartItems[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cartItem.menuItem.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('\$${cartItem.menuItem.price.toStringAsFixed(2)} c/u'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(cartItem.menuItem.id, cartItem.quantity - 1),
                    ),
                    Text('${cartItem.quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(cartItem.menuItem.id, cartItem.quantity + 1),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '\$${cartItem.totalPrice.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    FilledButton(
                      // El checkout real (crear la orden en Supabase) lo
                      // construimos en un paso futuro.
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Checkout: lo construimos en el siguiente paso')),
                        );
                      },
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}