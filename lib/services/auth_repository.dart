import '../models/perfil.dart';

/// Excepción de dominio para errores de autenticación. Permite a la UI
/// mostrar un mensaje claro sin depender de tipos de Supabase.
class AuthFailure implements Exception {
  const AuthFailure(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Contrato de autenticación.
///
/// Capa desacoplada: las vistas y providers dependen SOLO de esta interfaz.
/// Existen dos implementaciones intercambiables vía `AppConfig.useMockData`:
///  - [MockAuthRepository]      -> login simulado, sin internet.
///  - [SupabaseAuthRepository]  -> autenticación real contra Supabase.
abstract interface class AuthRepository {
  /// Inicia sesión y devuelve el [Perfil] completo leído de `perfiles`.
  /// Lanza [AuthFailure] si las credenciales son inválidas.
  Future<Perfil> signIn({
    required String email,
    required String password,
  });

  /// Cierra la sesión activa.
  Future<void> signOut();

  /// Restaura la sesión persistida (si existe) al abrir la app.
  /// Devuelve `null` si no hay sesión activa.
  Future<Perfil?> restoreSession();
}
