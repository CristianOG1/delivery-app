import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show Stripe, StripeException, FailureCode, SetupPaymentSheetParameters;
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../core/supabase_client.dart';
import '../models/cart_item.dart';
import '../models/order_receipt.dart';
import 'cart_provider.dart';

/// Error con un mensaje listo para mostrarle al usuario.
class CheckoutException implements Exception {
  final String message;
  CheckoutException(this.message);

  @override
  String toString() => message;
}

/// Ejecuta todo el flujo de pago:
///  1. Pide a la Edge Function `create-payment-intent` que cree el pedido y el
///     cobro en Stripe (el servidor calcula el monto con los precios reales).
///  2. Abre la hoja de pago de Stripe, donde el cliente escribe su tarjeta.
///     Los datos de la tarjeta van directo a Stripe; esta app nunca los ve.
///  3. Pide a `confirm-payment` que verifique con Stripe que el cobro se hizo
///     y marque el pedido como pagado.
///
/// El estado es el recibo cuando el pago termina bien, `null` si todavía no se
/// ha pagado (o el cliente canceló), y error si algo falló.
class CheckoutController extends AutoDisposeAsyncNotifier<OrderReceipt?> {
  @override
  Future<OrderReceipt?> build() async => null;

  Future<void> pay() async {
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;

    state = const AsyncLoading();

    try {
      final receipt = await _procesarPago(items);
      state = AsyncData(receipt);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        // El cliente cerró la hoja de pago: no es un error.
        state = const AsyncData(null);
      } else {
        state = AsyncError(
          CheckoutException(
            e.error.localizedMessage ?? 'No se pudo completar el pago.',
          ),
          StackTrace.current,
        );
      }
    } on FunctionException catch (e) {
      state = AsyncError(CheckoutException(_mensajeDe(e)), StackTrace.current);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<OrderReceipt> _procesarPago(List<CartItem> items) async {
    // 1. Crear pedido + cobro en el servidor. Solo mandamos ids y cantidades:
    //    el precio lo lee el servidor de la base de datos, no de la app.
    final intentRes = await supabase.functions.invoke(
      'create-payment-intent',
      body: {
        'items': [
          for (final c in items)
            {'menu_item_id': c.menuItem.id, 'quantity': c.quantity},
        ],
      },
    );
    final intentData = intentRes.data as Map<String, dynamic>;
    final clientSecret = intentData['client_secret'] as String;
    final orderId = intentData['order_id'] as String;

    // 2. Hoja de pago segura de Stripe.
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Delivery App',
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    // 3. Confirmar en el servidor que el cobro realmente se completó.
    final confirmRes = await supabase.functions.invoke(
      'confirm-payment',
      body: {'order_id': orderId},
    );
    final confirmData = confirmRes.data as Map<String, dynamic>;

    if (confirmData['status'] != 'paid') {
      throw CheckoutException(
        'No pudimos confirmar tu pago. Si te lo cobraron, guarda este número '
        'de pedido: ${orderId.substring(0, 8).toUpperCase()}',
      );
    }

    // Pago listo: vaciamos el carrito y devolvemos el recibo.
    ref.read(cartProvider.notifier).clear();
    return OrderReceipt.fromMap(confirmData['order'] as Map<String, dynamic>);
  }

  String _mensajeDe(FunctionException e) {
    final detalles = e.details;
    if (detalles is Map && detalles['error'] is String) {
      return detalles['error'] as String;
    }
    return 'No se pudo conectar con el servidor de pagos (código ${e.status}).';
  }
}

final checkoutControllerProvider =
    AutoDisposeAsyncNotifierProvider<CheckoutController, OrderReceipt?>(
  CheckoutController.new,
);
