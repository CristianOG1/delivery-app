import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/tracking_models.dart';

/// Pedidos pagados del cliente (más recientes primero), con su seguimiento.
final myOrdersProvider = FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final filas = await supabase
      .from('orders')
      .select('*, order_items(*), order_tracking(*)')
      .eq('user_id', user.id)
      .neq('status', 'pending') // los pendientes son pagos sin completar
      .order('created_at', ascending: false)
      .limit(50);
  return filas.map<OrderSummary>(OrderSummary.fromMap).toList();
});

/// Seguimiento de un pedido en tiempo real: se actualiza solo cuando
/// cambia la etapa en Supabase (Realtime).
final orderTrackingProvider =
    StreamProvider.autoDispose.family<OrderTracking?, String>((ref, orderId) {
  return supabase
      .from('order_tracking')
      .stream(primaryKey: ['order_id'])
      .eq('order_id', orderId)
      .map((filas) => filas.isEmpty ? null : OrderTracking.fromMap(filas.first));
});
