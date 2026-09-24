import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/supabase_client.dart';
import '../models/app_user.dart';

/// Escucha en tiempo real los cambios de sesión (login, logout, token
/// refrescado). Gracias a esto, si el usuario ya inició sesión antes,
/// al abrir la app de nuevo seguirá logueado automáticamente.
final authStateChangesProvider = StreamProvider<sb.AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Expone el usuario actual (o null si no hay sesión) como un AppUser
/// simple, listo para usar en la UI.
final currentUserProvider = Provider<AppUser?>((ref) {
  // Nos re-evaluamos cada vez que cambia el estado de auth.
  final authState = ref.watch(authStateChangesProvider).value;
  final user = authState?.session?.user ?? supabase.auth.currentUser;

  if (user == null) return null;

  return AppUser.fromSupabase(
    id: user.id,
    email: user.email ?? '',
    metadata: user.userMetadata,
  );
});

/// Controlador que ejecuta las acciones de autenticación.
/// Usamos AsyncNotifier para que la UI pueda mostrar loading/error
/// fácilmente con un solo objeto (AsyncValue).
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Estado inicial: no hay ninguna operación en curso.
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signOut();
    });
  }

  /// Actualiza el nombre y/o teléfono del usuario actual.
  /// Supabase emite un evento 'userUpdated' en el stream de auth, así que
  /// currentUserProvider se refresca solo, sin recargar la app.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.updateUser(
        sb.UserAttributes(
          data: {
            'full_name': fullName,
            'phone': phone,
          },
        ),
      );
    });
  }

  /// Cambia la contraseña del usuario actual (debe tener sesión activa).
  Future<void> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);