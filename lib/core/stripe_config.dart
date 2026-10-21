import 'package:flutter/foundation.dart';

/// Configuración pública de Stripe.
///
/// La clave PUBLICABLE (empieza con pk_test_) sí puede ir en el código: está
/// hecha para vivir dentro de la app.
///
/// La clave SECRETA (empieza con sk_test_) NUNCA va aquí ni en GitHub. Vive solo
/// en los secretos de Supabase y la usan únicamente las Edge Functions.
class StripeConfig {
  /// Reemplaza este valor con tu clave publicable de PRUEBA (modo test).
  static const String publishableKey = 'pk_test_REEMPLAZA_CON_TU_CLAVE_PUBLICA';

  static bool get estaConfigurado =>
      publishableKey.startsWith('pk_') && !publishableKey.contains('REEMPLAZA');

  /// La hoja de pago de Stripe solo existe en Android e iOS (no en web ni en
  /// Windows/Linux/macOS).
  static bool get plataformaSoportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
