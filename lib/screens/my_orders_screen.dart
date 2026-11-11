import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tracking_models.dart';
import '../providers/tracking_provider.dart';
import 'courier_history_screen.dart' show formatoMoneda;
import 'order_tracking_screen.dart';

/// Lista de pedidos del cliente. Al tocar uno se abre su seguimiento.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: pedidos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myOrdersProvider);
            await ref.read(myOrdersProvider.future);
          },
          child: lista.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Aún no tienes pedidos')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _TarjetaPedido(pedido: lista[i]),
                ),
        ),
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  final OrderSummary pedido;

  const _TarjetaPedido({required this.pedido});

  String _fecha(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final etapa = pedido.tracking?.stage;
    final (texto, color) = switch (etapa) {
      OrderStage.preparing => ('Preparando', Colors.orange),
      OrderStage.onTheWay => ('En camino', Colors.blue),
      OrderStage.delivered => ('Entregado', Colors.green),
      _ => ('Pagado', Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: pedido.id),
          ),
        ),
        title: Text(
          pedido.tracking?.restaurantName ?? 'Pedido ${pedido.id.substring(0, 8)}',
        ),
        subtitle: Text(
          '${pedido.itemNames.join(', ')}\n${_fecha(pedido.createdAt)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatoMoneda(pedido.total),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(texto, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
