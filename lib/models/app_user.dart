/// Representa al usuario dentro de nuestra app (no el objeto crudo de Supabase).
///
/// Lo separamos del User de Supabase para no acoplar toda la app a esa
/// librería: si en el futuro cambiamos de backend, solo tocamos este
/// modelo y el AuthProvider, no cada pantalla.
class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;

  AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
  });

  /// Crea un AppUser a partir de la sesión/usuario que devuelve Supabase.
  factory AppUser.fromSupabase({
    required String id,
    required String email,
    Map<String, dynamic>? metadata,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: metadata?['full_name'] as String?,
      phone: metadata?['phone'] as String?,
    );
  }
}