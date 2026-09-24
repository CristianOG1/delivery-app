import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración central de Supabase.
///
/// IMPORTANTE: reemplaza estos valores con los de TU proyecto de Supabase.
/// Los encuentras en: Supabase Dashboard -> Project Settings -> API.
///
/// Por seguridad, en un proyecto real es mejor no dejar estas claves
/// escritas directamente en el código. Puedes pasarlas al compilar con:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// y leerlas aquí con String.fromEnvironment(...).
class SupabaseConfig {
  static const String url = 'https://ofvwnelehovrjcgofawq.supabase.co';
  static const String anonKey = 'sb_publishable_tNjPC2ct0vENT9cPpb9AcA_PU9DSc1u';

  /// Inicializa Supabase. Se llama una sola vez, en main().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// Acceso rápido al cliente de Supabase desde cualquier parte de la app.
final supabase = Supabase.instance.client;