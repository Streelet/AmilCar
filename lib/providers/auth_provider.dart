import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_entry.dart';
import '../models/perfil.dart';
import '../services/audit_repository.dart';
import '../services/auth_repository.dart';
import 'repository_providers.dart';

/// Estado global de autenticación.
///
/// - [checking] : la app está restaurando una sesión persistida al arrancar.
/// - [perfil]   : perfil del usuario autenticado (rol, nombre, foto). Nulo
///                si no hay sesión.
class AuthState {
  const AuthState({this.checking = true, this.perfil});

  final bool checking;
  final Perfil? perfil;

  bool get isAuthenticated => perfil != null;

  AuthState copyWith({bool? checking, Perfil? perfil}) {
    return AuthState(
      checking: checking ?? this.checking,
      perfil: perfil ?? this.perfil,
    );
  }
}

/// Controla el ciclo de vida de la sesión y guarda el perfil en el estado
/// global, de modo que toda la interfaz pueda modularse según el rol.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._auditRepo)
      : super(const AuthState(checking: true)) {
    _restore();
  }

  final AuthRepository _repo;
  final AuditRepository _auditRepo;

  Future<void> _restore() async {
    try {
      final perfil = await _repo.restoreSession();
      state = AuthState(checking: false, perfil: perfil);
    } catch (_) {
      state = const AuthState(checking: false);
    }
  }

  /// Inicia sesión. Lanza [AuthFailure] si las credenciales fallan; la
  /// pantalla de login captura esa excepción para mostrar el mensaje.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final perfil = await _repo.signIn(email: email, password: password);
    state = AuthState(checking: false, perfil: perfil);
    // Log exitoso (fire-and-forget)
    unawaited(_auditRepo.registrar(
      accion: AuditAccion.login,
      usuarioId: perfil.id,
      usuarioEmail: perfil.email,
      datos: {'nombre': perfil.nombre, 'rol': perfil.rol.label},
    ));
  }

  /// Cierra sesión y vuelve al estado no autenticado.
  Future<void> signOut() async {
    final perfil = state.perfil;
    // Log antes de borrar el estado (aún tenemos el usuario)
    unawaited(_auditRepo.registrar(
      accion: AuditAccion.logout,
      usuarioId: perfil?.id,
      usuarioEmail: perfil?.email,
    ));
    await _repo.signOut();
    state = const AuthState(checking: false);
  }
}

/// Provider del controlador de autenticación.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(auditRepositoryProvider),
  );
});

/// Atajo para leer el perfil del usuario actual desde cualquier widget.
final currentPerfilProvider = Provider<Perfil?>((ref) {
  return ref.watch(authControllerProvider).perfil;
});
