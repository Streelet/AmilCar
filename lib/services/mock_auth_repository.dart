import '../models/perfil.dart';
import 'auth_repository.dart';
import 'mock_data.dart';

/// Implementación de [AuthRepository] para el MODO MOCKUP.
///
/// Login 100% offline contra las cuentas de prueba de [MockData].
/// No persiste sesión: cada arranque inicia en la pantalla de Login,
/// lo que facilita probar el cambio entre roles 'admin' y 'asesor'.
class MockAuthRepository implements AuthRepository {
  @override
  Future<Perfil> signIn({
    required String email,
    required String password,
  }) async {
    // Latencia simulada para que la UI ejercite sus estados de carga.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final correo = email.trim().toLowerCase();
    for (final cuenta in MockData.demoAccounts) {
      if (cuenta.email.toLowerCase() == correo &&
          cuenta.password == password) {
        return cuenta.perfil;
      }
    }
    throw const AuthFailure(
      'Credenciales inválidas. Usa admin@amilcar.com o '
      'asesor@amilcar.com con la contraseña 123456.',
    );
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<Perfil?> restoreSession() async {
    // En modo mock no se persiste sesión: siempre arranca en Login.
    return null;
  }
}
