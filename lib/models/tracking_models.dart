/// Etapas del pedido que ve el cliente.
class OrderStage {
  static const preparing = 'preparing';
  static const onTheWay = 'on_the_way';
  static const delivered = 'delivered';

  static const all = [preparing, onTheWay, delivered];

  static String label(String stage) {
    switch (stage) {
      case preparing:
        return 'Preparando tu pedido';
      case onTheWay:
        return 'En camino';
      case delivered:
        return 'Entregado';
      default:
        return stage;
    }
  }
}

/// Punto geográfico simple (para no depender de Google Maps en los modelos).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);
}

/// Punto de respaldo cuando un restaurante aún no tiene coordenadas
/// (centro de Ciudad de México). Pon `lat`/`lng` en `restaurants` para evitarlo.
const _puntoRespaldo = GeoPoint(19.4326, -99.1332);

/// Seguimiento de un pedido (fila de `order_tracking`).
class OrderTracking {
  final String orderId;
  final String stage; // preparing | on_the_way | delivered
  final String? restaurantName;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final int etaMinutes;
  final DateTime? onTheWayAt;

  const OrderTracking({
    required this.orderId,
    required this.stage,
    this.restaurantName,
    this.restaurantLat,
    this.restaurantLng,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    required this.etaMinutes,
    this.onTheWayAt,
  });

  factory OrderTracking.fromMap(Map<String, dynamic> map) => OrderTracking(
        orderId: map['order_id'] as String,
        stage: map['stage'] as String,
        restaurantName: map['restaurant_name'] as String?,
        restaurantLat: (map['restaurant_lat'] as num?)?.toDouble(),
        restaurantLng: (map['restaurant_lng'] as num?)?.toDouble(),
        dropoffAddress: map['dropoff_address'] as String?,
        dropoffLat: (map['dropoff_lat'] as num?)?.toDouble(),
        dropoffLng: (map['dropoff_lng'] as num?)?.toDouble(),
        etaMinutes: (map['eta_minutes'] as num?)?.toInt() ?? 20,
        onTheWayAt: map['on_the_way_at'] == null
            ? null
            : DateTime.parse(map['on_the_way_at'] as String).toLocal(),
      );

  bool get isDelivered => stage == OrderStage.delivered;
  bool get isOnTheWay => stage == OrderStage.onTheWay;

  /// Si faltan coordenadas del restaurante, se usa el punto de respaldo.
  bool get usaCoordenadasDeRespaldo => restaurantLat == null || restaurantLng == null;

  GeoPoint get restaurantPoint => usaCoordenadasDeRespaldo
      ? _puntoRespaldo
      : GeoPoint(restaurantLat!, restaurantLng!);

  /// Si no hay destino, se coloca un punto cercano (~1.5 km) al restaurante.
  GeoPoint get dropoffPoint {
    if (dropoffLat != null && dropoffLng != null) {
      return GeoPoint(dropoffLat!, dropoffLng!);
    }
    final r = restaurantPoint;
    return GeoPoint(r.lat + 0.010, r.lng + 0.012);
  }

  /// Avance del recorrido (0 a 1), calculado por tiempo transcurrido.
  /// En camino nunca llega a 1: el destino se alcanza al marcarse "entregado".
  double progreso(DateTime ahora) {
    if (isDelivered) return 1;
    if (!isOnTheWay || onTheWayAt == null) return 0;
    final total = Duration(minutes: etaMinutes <= 0 ? 1 : etaMinutes).inSeconds;
    final pasado = ahora.difference(onTheWayAt!).inSeconds;
    return (pasado / total).clamp(0.0, 0.95);
  }

  /// Posición simulada del repartidor entre restaurante y destino.
  GeoPoint posicionRepartidor(DateTime ahora) {
    final a = restaurantPoint;
    final b = dropoffPoint;
    final p = progreso(ahora);
    return GeoPoint(a.lat + (b.lat - a.lat) * p, a.lng + (b.lng - a.lng) * p);
  }

  /// Minutos restantes estimados (mínimo 1 mientras va en camino).
  int minutosRestantes(DateTime ahora) {
    if (!isOnTheWay) return etaMinutes;
    final restante = (1 - progreso(ahora)) * etaMinutes;
    return restante.ceil().clamp(1, etaMinutes);
  }
}

/// Pedido del cliente con su seguimiento (si ya está pagado).
class OrderSummary {
  final String id;
  final String status;
  final double total;
  final String currency;
  final DateTime createdAt;
  final List<String> itemNames;
  final OrderTracking? tracking;

  const OrderSummary({
    required this.id,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.itemNames,
    this.tracking,
  });

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    // `order_tracking(*)` llega como objeto (relación 1 a 1) o como lista.
    final rawTracking = map['order_tracking'];
    Map<String, dynamic>? trackingMap;
    if (rawTracking is Map<String, dynamic>) {
      trackingMap = rawTracking;
    } else if (rawTracking is List && rawTracking.isNotEmpty) {
      trackingMap = rawTracking.first as Map<String, dynamic>;
    }

    final items = (map['order_items'] as List? ?? [])
        .map((i) => '${i['quantity']}× ${i['name']}')
        .toList();

    return OrderSummary(
      id: map['id'] as String,
      status: map['status'] as String,
      total: (map['total'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'mxn',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      itemNames: items,
      tracking: trackingMap == null ? null : OrderTracking.fromMap(trackingMap),
    );
  }
}
