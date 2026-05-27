import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/audit_entry.dart';
import '../utils/platform_info.dart';
import 'audit_repository.dart';

/// Implementación mock del [AuditRepository].
///
/// Guarda los eventos en memoria y los emite por un [StreamController] local.
/// Imprime cada evento en consola (debug only) para que sea útil durante
/// desarrollo sin necesidad de Supabase.
class MockAuditRepository implements AuditRepository {
  final _controller = StreamController<List<AuditEntry>>.broadcast();
  final _entries = <AuditEntry>[];
  int _counter = 0;

  @override
  Future<void> registrar({
    required AuditAccion accion,
    String? entidad,
    String? entidadId,
    Map<String, dynamic>? datos,
    String? usuarioId,
    String? usuarioEmail,
  }) async {
    final entry = AuditEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      createdAt: DateTime.now(),
      usuarioId: usuarioId,
      usuarioEmail: usuarioEmail,
      accion: accion,
      entidad: entidad,
      entidadId: entidadId,
      datos: datos,
      plataforma: currentPlatform(),
    );

    _entries.insert(0, entry);
    if (_entries.length > 300) _entries.removeLast();

    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_entries));
    }

    debugPrint(
      '[AUDIT] ${accion.label}'
      '${entidad != null ? " · $entidad" : ""}'
      '${entidadId != null ? ":${entidadId.substring(0, 8)}…" : ""}'
      '${datos != null ? " · $datos" : ""}',
    );
  }

  @override
  Stream<List<AuditEntry>> watchLogs({int limite = 300}) {
    // Emite el estado actual inmediatamente al suscribirse y luego las
    // actualizaciones posteriores.
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_entries.take(limite).toList()));
      final sub = _controller.stream.listen(
        (all) => controller.add(all.take(limite).toList()),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}
