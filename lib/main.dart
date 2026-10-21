import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show Stripe;

import 'core/stripe_config.dart';
import 'core/supabase_client.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  // Stripe solo funciona en Android/iOS. Si falta la clave, la app arranca igual
  // y el botón de pagar avisa qué falta.
  if (StripeConfig.plataformaSoportada && StripeConfig.estaConfigurado) {
    Stripe.publishableKey = StripeConfig.publishableKey;
    await Stripe.instance.applySettings();
  }

  runApp(
    // ProviderScope habilita Riverpod en toda la app.
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según si hay sesión activa o no.
/// Al escuchar authStateChangesProvider, esto se actualiza automáticamente
/// en cuanto el usuario inicia sesión, se registra o cierra sesión.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}