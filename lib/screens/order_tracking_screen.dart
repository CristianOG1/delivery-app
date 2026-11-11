import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/tracking_models.dart';
import '../providers/tracking_provider.dart';

/// Seguimiento de un pedido con Google Maps.
/// La etapa llega en tiempo real desde Supabase; la posición del repartidor
/// se simula entre el restaurante y el destino según el tiempo estimado.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  GoogleMapController? _mapa;
  Timer? _reloj;
  DateTime _ahora = DateTime.now();
  bool _encuadrado = false;

  // google_maps_flutter solo funciona en Android/iOS (no en Windows ni web sin configurar).
  bool get _mapaSoportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Refresca la posición simulada cada 5 segundos.
    _reloj = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _mapa?.dispose();
    super.dispose();
  }

  LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

  /// Ajusta la cámara para que se vean restaurante y destino.
  Future<void> _encuadrar(OrderTracking t) async {
    final a = t.restaurantPoint;
    final b = t.dropoffPoint;
    final bounds = LatLngBounds(
      southwest: LatLng(a.lat < b.lat ? a.lat : b.lat, a.lng < b.lng ? a.lng : b.lng),
      northeast: LatLng(a.lat > b.lat ? a.lat : b.lat, a.lng > b.lng ? a.lng : b.lng),
    );
    // Pequeña espera: en Android el mapa debe tener tamaño antes de animar la cámara.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _mapa?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      // Si aún no tiene tamaño, se queda con la cámara inicial.
    }
  }

  @override
  Widget build(BuildContext context) {
    final seguimiento = ref.watch(orderTrackingProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento del pedido')),
      body: seguimiento.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (t) {
          if (t == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu pedido aún no tiene seguimiento. Vuelve a intentarlo en unos segundos.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(child: _mapaWidget(t)),
              _Panel(seguimiento: t, ahora: _ahora),
            ],
          );
        },
      ),
    );
  }

  Widget _mapaWidget(OrderTracking t) {
    if (!_mapaSoportado) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'El mapa solo está disponible en Android e iOS. '
            'Abre la app en tu teléfono para ver el recorrido.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final restaurante = _ll(t.restaurantPoint);
    final destino = _ll(t.dropoffPoint);
    final repartidor = _ll(t.posicionRepartidor(_ahora));

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: restaurante, zoom: 14),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('restaurante'),
          position: restaurante,
          infoWindow: InfoWindow(title: t.restaurantName ?? 'Restaurante'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          infoWindow: InfoWindow(title: 'Tu entrega', snippet: t.dropoffAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        if (t.isOnTheWay)
          Marker(
            markerId: const MarkerId('repartidor'),
            position: repartidor,
            infoWindow: const InfoWindow(title: 'Tu repartidor'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('ruta'),
          points: [restaurante, destino],
          color: Colors.blue,
          width: 4,
        ),
      },
      onMapCreated: (c) {
        _mapa = c;
        if (!_encuadrado) {
          _encuadrado = true;
          _encuadrar(t);
        }
      },
    );
  }
}

/// Panel inferior: etapa actual, tiempo estimado y pasos del pedido.
class _Panel extends StatelessWidget {
  final OrderTracking seguimiento;
  final DateTime ahora;

  const _Panel({required this.seguimiento, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final t = seguimiento;
    final indiceActual = OrderStage.all.indexOf(t.stage);

    final titulo = t.isDelivered
        ? '¡Tu pedido fue entregado!'
        : t.isOnTheWay
            ? 'Llega en ~${t.minutosRestantes(ahora)} min'
            : 'Estamos preparando tu pedido';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          if (t.restaurantName != null)
            Text('De ${t.restaurantName}', style: Theme.of(context).textTheme.bodyMedium),
          if (t.dropoffAddress != null)
            Text('Entrega: ${t.dropoffAddress}',
                style: Theme.of(context).textTheme.bodyMedium),
          if (t.isOnTheWay) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: t.progreso(ahora)),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < OrderStage.all.length; i++)
            _Paso(
              texto: OrderStage.label(OrderStage.all[i]),
              hecho: i < indiceActual || t.isDelivered,
              actual: i == indiceActual && !t.isDelivered,
            ),
          if (t.usaCoordenadasDeRespaldo)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ubicación aproximada.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final String texto;
  final bool hecho;
  final bool actual;

  const _Paso({required this.texto, required this.hecho, required this.actual});

  @override
  Widget build(BuildContext context) {
    final color = hecho
        ? Colors.green
        : actual
            ? Theme.of(context).colorScheme.primary
            : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hecho ? Icons.check_circle : (actual ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: actual ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
