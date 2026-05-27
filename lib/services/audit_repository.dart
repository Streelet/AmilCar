import '../models/audit_entry.dart';

/// Contrato del repositorio de auditoría.
///
/// Dos responsabilidades:
///  • [registrar] — escribe un evento (fire-and-forget; los errores se tragan
///    para no romper la UI).
///  • [watchLogs] — stream en tiempo real de los [limite] eventos más recientes,
///    ordenados del más nuevo al más antiguo. Solo accesible para admin.
abstract class AuditRepository {
  /// Registra un evento de auditoría.
  ///
  /// La llamada es asíncrona pero el llamador no necesita esperarla; los
  /// errores se capturan internamente y jamás se propagan hacia la UI.
  Future<void> registrar({
    required AuditAccion accion,
    String? entidad,
    String? entidadId,
    Map<String, dynamic>? datos,
    String? usuarioId,
    String? usuarioEmail,
  });

  /// Stream de los [limite] eventos más recientes, más nuevo primero.
  Stream<List<AuditEntry>> watchLogs({int limite = 300});

  void dispose();
}
