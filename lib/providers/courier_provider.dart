import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/courier_models.dart';

const _bucketDocumentos = 'courier-documents';

/// Perfil del repartidor del usuario actual (null si aún no se ha registrado).
final courierProvider =
    AsyncNotifierProvider<CourierController, Courier?>(CourierController.new);

class CourierController extends AsyncNotifier<Courier?> {
  @override
  Future<Courier?> build() async {
    // Si cambia la sesión (login/logout), se vuelve a cargar el perfil.
    final sub = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(sub.cancel);

    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final fila =
        await supabase.from('couriers').select().eq('id', user.id).maybeSingle();
    return fila == null ? null : Courier.fromMap(fila);
  }

  /// Registra al usuario actual como repartidor (queda en estado `pending`).
  Future<void> register({
    required String fullName,
    required String phone,
    required String vehicleType,
    String? plate,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Inicia sesión para registrarte');

    final fila = await supabase
        .from('couriers')
        .insert({
          'id': user.id,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'vehicle_type': vehicleType,
          'plate': (plate == null || plate.trim().isEmpty) ? null : plate.trim().toUpperCase(),
        })
        .select()
        .single();
    state = AsyncData(Courier.fromMap(fila));
  }

  /// Conecta o desconecta al repartidor. Lanza excepción si no está aprobado.
  Future<void> setOnline(bool value) async {
    final actual = state.valueOrNull;
    if (actual == null) return;
    if (value && !actual.isApproved) {
      throw Exception('Tu cuenta aún no está aprobada');
    }

    final fila = await supabase
        .from('couriers')
        .update({'is_online': value})
        .eq('id', actual.id)
        .select()
        .single();
    state = AsyncData(Courier.fromMap(fila));
  }

  /// Vuelve a leer el perfil (por ejemplo, para ver si ya fue aprobado).
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Documentos subidos por el repartidor, indexados por tipo.
final courierDocumentsProvider = AsyncNotifierProvider.autoDispose<
    CourierDocumentsController, Map<String, CourierDocument>>(
  CourierDocumentsController.new,
);

class CourierDocumentsController
    extends AutoDisposeAsyncNotifier<Map<String, CourierDocument>> {
  @override
  Future<Map<String, CourierDocument>> build() async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};

    final filas =
        await supabase.from('courier_documents').select().eq('courier_id', user.id);
    final docs = filas.map<CourierDocument>(CourierDocument.fromMap);
    return {for (final d in docs) d.docType: d};
  }

  /// Sube (o reemplaza) el documento de un tipo.
  Future<void> upload(String docType, PlatformFile archivo) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Inicia sesión para subir documentos');

    final bytes = archivo.bytes;
    if (bytes == null) throw Exception('No se pudo leer el archivo');

    final ext = (archivo.extension ?? 'jpg').toLowerCase();
    final ruta = '${user.id}/$docType.$ext';

    await supabase.storage.from(_bucketDocumentos).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: _mime(ext)),
        );

    await supabase.from('courier_documents').upsert(
      {
        'courier_id': user.id,
        'doc_type': docType,
        'file_path': ruta,
        'status': 'pending',
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'courier_id,doc_type',
    );

    ref.invalidateSelf();
    await future;
  }

  String _mime(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }
}

/// Historial de viajes del repartidor (más recientes primero).
final courierTripsProvider =
    FutureProvider.autoDispose<List<DeliveryTrip>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final filas = await supabase
      .from('deliveries')
      .select()
      .eq('courier_id', user.id)
      .order('completed_at', ascending: false)
      .limit(200);
  return filas.map<DeliveryTrip>(DeliveryTrip.fromMap).toList();
});

/// Resumen de ganancias calculado a partir del historial.
final earningsSummaryProvider = Provider.autoDispose<AsyncValue<EarningsSummary>>(
  (ref) => ref.watch(courierTripsProvider).whenData(EarningsSummary.fromTrips),
);
