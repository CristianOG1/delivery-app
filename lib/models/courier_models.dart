class Courier {
  final String id;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String? plate;
  final String status; // pending | approved | rejected
  final bool isOnline;

  const Courier({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    this.plate,
    required this.status,
    required this.isOnline,
  });

  bool get isApproved => status == 'approved';

  factory Courier.fromMap(Map<String, dynamic> map) => Courier(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String,
        vehicleType: map['vehicle_type'] as String,
        plate: map['plate'] as String?,
        status: map['status'] as String,
        isOnline: map['is_online'] as bool? ?? false,
      );
}

/// Tipos de documento que debe subir el repartidor.
class CourierDocType {
  static const license = 'license';
  static const idCard = 'id_card';
  static const insurance = 'insurance';

  static const all = [license, idCard, insurance];

  static String label(String type) {
    switch (type) {
      case license:
        return 'Licencia de conducir';
      case idCard:
        return 'Identificación oficial';
      case insurance:
        return 'Seguro del vehículo';
      default:
        return type;
    }
  }
}

/// Documento subido (fila de `courier_documents`).
class CourierDocument {
  final String docType;
  final String filePath;
  final String status; // pending | approved | rejected
  final DateTime uploadedAt;

  const CourierDocument({
    required this.docType,
    required this.filePath,
    required this.status,
    required this.uploadedAt,
  });

  factory CourierDocument.fromMap(Map<String, dynamic> map) => CourierDocument(
        docType: map['doc_type'] as String,
        filePath: map['file_path'] as String,
        status: map['status'] as String,
        uploadedAt: DateTime.parse(map['uploaded_at'] as String).toLocal(),
      );
}

/// Viaje terminado (fila de `deliveries`).
class DeliveryTrip {
  final String id;
  final String restaurantName;
  final String dropoffAddress;
  final double distanceKm;
  final double earnings;
  final double tip;
  final String status; // completed | cancelled
  final DateTime completedAt;

  const DeliveryTrip({
    required this.id,
    required this.restaurantName,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.earnings,
    required this.tip,
    required this.status,
    required this.completedAt,
  });

  double get total => earnings + tip;
  bool get isCompleted => status == 'completed';

  factory DeliveryTrip.fromMap(Map<String, dynamic> map) => DeliveryTrip(
        id: map['id'] as String,
        restaurantName: map['restaurant_name'] as String,
        dropoffAddress: map['dropoff_address'] as String,
        distanceKm: (map['distance_km'] as num).toDouble(),
        earnings: (map['earnings'] as num).toDouble(),
        tip: (map['tip'] as num).toDouble(),
        status: map['status'] as String,
        completedAt: DateTime.parse(map['completed_at'] as String).toLocal(),
      );
}

/// Total de ganancias y número de viajes de un periodo.
class PeriodEarnings {
  final int trips;
  final double total;

  const PeriodEarnings(this.trips, this.total);
}

/// Resumen de ganancias (solo cuenta viajes completados).
class EarningsSummary {
  final PeriodEarnings today;
  final PeriodEarnings week;
  final PeriodEarnings month;

  const EarningsSummary({
    required this.today,
    required this.week,
    required this.month,
  });

  factory EarningsSummary.fromTrips(List<DeliveryTrip> trips, [DateTime? now]) {
    final ahora = now ?? DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    // La semana empieza el lunes.
    final inicioSemana = inicioHoy.subtract(Duration(days: ahora.weekday - 1));
    final inicioMes = DateTime(ahora.year, ahora.month, 1);

    PeriodEarnings suma(DateTime desde) {
      final viajes = trips.where((t) => t.isCompleted && !t.completedAt.isBefore(desde));
      return PeriodEarnings(
        viajes.length,
        viajes.fold<double>(0, (acc, t) => acc + t.total),
      );
    }

    return EarningsSummary(
      today: suma(inicioHoy),
      week: suma(inicioSemana),
      month: suma(inicioMes),
    );
  }
}