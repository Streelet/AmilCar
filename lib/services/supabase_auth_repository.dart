import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/perfil.dart';
import 'auth_repository.dart';

/// Implementación de [AuthRepository] para el MODO SUPABASE.
///
/// Autenticación real + lectura del perfil desde la tabla relacional
/// `perfiles`. La sesión se persiste automáticamente por el SDK
/// (`supabase_flutter`), por lo que sobrevive a cierres de la app.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Perfil> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('No se pudo iniciar sesión.');
      }
      return _fetchPerfil(user.id, user.email);
    } on AuthException catch (e) {
      throw AuthFailure(_traducir(e.message));
    } on PostgrestException catch (e) {
      throw AuthFailure('Perfil no encontrado: ${e.message}');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Perfil?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (_client.auth.currentSession == null || user == null) return null;
    try {
      return await _fetchPerfil(user.id, user.email);
    } catch (_) {
      // Sesión inválida o sin conectividad: tratar como no autenticado.
      return null;
    }
  }

  /// Consulta la fila del usuario en `perfiles` y arma el [Perfil] global.
  Future<Perfil> _fetchPerfil(String userId, String? authEmail) async {
    final data =
        await _client.from('perfiles').select().eq('id', userId).single();
    final perfil = Perfil.fromJson(data);
    // El correo vive en auth.users; lo inyectamos para la pantalla de perfil.
    return perfil.email == null ? perfil.copyWith(email: authEmail) : perfil;
  }

  String _traducir(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('invalid login') || m.contains('credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (m.contains('network') || m.contains('failed host')) {
      return 'Sin conexión. Verifica tu red e intenta de nuevo.';
    }
    return mensaje;
  }
}
