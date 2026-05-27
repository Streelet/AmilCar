import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_entry.dart';
import '../models/perfil.dart';
import '../services/audit_repository.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AuditLogger
// ─────────────────────────────────────────────────────────────────────────────
//  Helper que combina el [AuditRepository] con el [Perfil] del usuario actual
//  para que los controladores no tengan que preocuparse por el userId/email.
//
//  El método [log] es fire-and-forget: no lanza excepciones, no requiere await.
//  Esto garantiza que ningún fallo de logging bloquee la UI.
// ─────────────────────────────────────────────────────────────────────────────

class AuditLogger {
  const AuditLogger(this._repo, this._perfil);

  final AuditRepository _repo;
  final Perfil? _perfil;

  /// Registra un evento de auditoría de forma asíncrona sin bloquear al llamador.
  void log({
    required AuditAccion accion,
    String? entidad,
    String? entidadId,
    Map<String, dynamic>? datos,
  }) {
    // unawaited intencional: los logs son secundarios, jamás deben detener la UI.
    unawaited(_repo.registrar(
      accion: accion,
      entidad: entidad,
      entidadId: entidadId,
      datos: datos,
      usuarioId: _perfil?.id,
      usuarioEmail: _perfil?.email,
    ));
  }
}

/// Provider del [AuditLogger]. Reacciona a cambios de sesión automáticamente:
/// si el usuario cambia, las llamadas posteriores a [log] usarán el nuevo perfil.
final auditLoggerProvider = Provider<AuditLogger>((ref) {
  final repo = ref.watch(auditRepositoryProvider);
  final perfil = ref.watch(currentPerfilProvider);
  return AuditLogger(repo, perfil);
});

// ─────────────────────────────────────────────────────────────────────────────
//  Stream de logs (admin only)
// ─────────────────────────────────────────────────────────────────────────────

/// Stream en tiempo real de las [AuditEntry] más recientes.
///
/// Las RLS de Supabase garantizan que solo el admin reciba datos; cualquier
/// otro rol obtendrá una lista vacía. En modo mock, devuelve los eventos
/// generados en sesión.
final auditLogStreamProvider = StreamProvider<List<AuditEntry>>((ref) {
  return ref.watch(auditRepositoryProvider).watchLogs();
});
