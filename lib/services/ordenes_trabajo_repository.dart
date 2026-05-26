import '../models/orden_trabajo.dart';

/// Contrato de acceso a datos de las órdenes de trabajo del taller.
///
/// Capa desacoplada: la UI consume SOLO esta interfaz. La implementación
/// real ([SupabaseOrdenesTrabajoRepository]) o ficticia
/// ([MockOrdenesTrabajoRepository]) se elige en tiempo de arranque según
/// `AppConfig.useMockData`.
///
/// El método [watchOrdenesTrabajo] entrega un flujo en tiempo real: en
/// Supabase usa Streams/WebSockets nativos; en mock, un stream en memoria
/// que reemite tras cada mutación (drag&drop, aprobación, archivado).
abstract interface class OrdenesTrabajoRepository {
  /// Flujo en tiempo real de TODAS las órdenes (archivadas o no).
  /// La UI filtra por pestaña, columna Kanban y estado de archivado.
  Stream<List<OrdenTrabajo>> watchOrdenesTrabajo();

  /// Cambia la columna/estado de una orden (drag&drop del Kanban o avance
  /// entre pestañas).
  Future<void> updateEstado(String id, EstadoKanban nuevoEstado);

  /// Cierre de trato: inyecta el [montoAprobado] elegido por el cliente y
  /// mueve la orden a [nuevoEstado] (normalmente `pendienteTrabajo`).
  Future<void> aprobarOrdenTrabajo({
    required String id,
    required double montoAprobado,
    required EstadoKanban nuevoEstado,
  });

  /// Conmuta el flag `archivado` (archivar o restaurar una orden).
  Future<void> setArchivado(String id, bool archivado);

  /// Persiste cambios generales de una orden (edición de campos).
  Future<void> upsertOrdenTrabajo(OrdenTrabajo ordenTrabajo);

  /// Soft delete: marca `deleted_at = now()`. La orden y sus pagos
  /// vinculados (vía cascade) desaparecen de la app, pero las filas
  /// permanecen para auditoría.
  Future<void> softDeleteOrdenTrabajo(String id);

  /// Libera recursos (cierra streams). Llamar al destruir el provider.
  void dispose();
}
