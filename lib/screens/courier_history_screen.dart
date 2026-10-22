import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/courier_models.dart';
import '../providers/courier_provider.dart';

/// Formatea un monto en pesos, p. ej. `$1,234.50`.
String formatoMoneda(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '\$$entero.${partes[1]}';
}

String _formatoFecha(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}

/// Resumen de ganancias (hoy, semana, mes) e historial de viajes.
class CourierHistoryScreen extends ConsumerWidget {
  const CourierHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viajes = ref.watch(courierTripsProvider);
    final resumen = ref.watch(earningsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial y ganancias')),
      body: viajes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(courierTripsProvider);
            await ref.read(courierTripsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (resumen.valueOrNull case final r?) ...[
                Row(
                  children: [
                    Expanded(child: _TarjetaResumen(titulo: 'Hoy', datos: r.today)),
                    const SizedBox(width: 8),
                    Expanded(child: _TarjetaResumen(titulo: 'Semana', datos: r.week)),
                    const SizedBox(width: 8),
                    Expanded(child: _TarjetaResumen(titulo: 'Mes', datos: r.month)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Text('Viajes recientes',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Aún no tienes viajes')),
                )
              else
                for (final v in lista) _TarjetaViaje(viaje: v),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  final String titulo;
  final PeriodEarnings datos;

  const _TarjetaResumen({required this.titulo, required this.datos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                formatoMoneda(datos.total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${datos.trips} ${datos.trips == 1 ? 'viaje' : 'viajes'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaViaje extends StatelessWidget {
  final DeliveryTrip viaje;

  const _TarjetaViaje({required this.viaje});

  @override
  Widget build(BuildContext context) {
    final cancelado = !viaje.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          cancelado ? Icons.cancel_outlined : Icons.check_circle_outline,
          color: cancelado ? Colors.red : Colors.green,
        ),
        title: Text(viaje.restaurantName),
        subtitle: Text(
          '${viaje.dropoffAddress}\n'
          '${_formatoFecha(viaje.completedAt)} · ${viaje.distanceKm.toStringAsFixed(1)} km',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              cancelado ? 'Cancelado' : formatoMoneda(viaje.total),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cancelado ? Colors.red : null,
              ),
            ),
            if (!cancelado && viaje.tip > 0)
              Text(
                'Propina ${formatoMoneda(viaje.tip)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}