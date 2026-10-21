import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/stripe_config.dart';
import '../models/order_receipt.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import 'receipt_screen.dart';

/// Resumen del pedido + botón de pago. El formulario de tarjeta lo muestra
/// Stripe (hoja de pago nativa), así los datos de la tarjeta nunca pasan por
/// nuestro código.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final cargando = checkout.isLoading;

    ref.listen<AsyncValue<OrderReceipt?>>(checkoutControllerProvider,
        (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${next.error}')),
        );
        return;
      }

      final receipt = next.value;
      final terminoDePagar = (previous?.isLoading ?? false) && !next.isLoading;
      if (terminoDePagar && receipt != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar pedido')),
      body: items.isEmpty
          ? const Center(child: Text('Tu carrito está vacío'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Resumen del pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                for (final c in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${c.quantity} × ${c.menuItem.name}')),
                        Text('\$${c.totalPrice.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                const Divider(height: 32),
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '\$${total.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pago seguro. Tus datos de tarjeta los captura '
                          'directamente Stripe: esta app nunca ve ni guarda '
                          'tu número de tarjeta.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: cargando ? null : () => _pagar(context, ref),
                  icon: cargando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    cargando
                        ? 'Procesando...'
                        : 'Pagar \$${total.toStringAsFixed(2)} MXN',
                  ),
                ),
              ),
            ),
    );
  }

  void _pagar(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);

    if (!StripeConfig.plataformaSoportada) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'El pago con tarjeta solo está disponible en la app de Android o iOS.',
          ),
        ),
      );
      return;
    }
    if (!StripeConfig.estaConfigurado) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Falta la clave de Stripe: edita lib/core/stripe_config.dart.',
          ),
        ),
      );
      return;
    }

    ref.read(checkoutControllerProvider.notifier).pay();
  }
}
