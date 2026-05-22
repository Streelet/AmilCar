import '../models/estimado.dart';

/// Contrato de acceso a datos de los estimados / órdenes de servicio.
///
/// Capa desacoplada: la UI consume SOLO esta interfaz. La implementación
/// real ([SupabaseEstimadosRepository]) o ficticia ([MockEstimadosRepository])
/// se elige en tiempo de arranque según `AppConfig.useMockData`.
///
/// El método [watchEstimados] entrega un flujo en tiempo real: en Supabase
/// usa Streams/WebSockets nativos; en mock, un stream en memoria que reemite
/// tras cada mutación (drag&drop, aprobación, archivado).
abstract interface class EstimadosRepository {
  /// Flujo en tiempo real de TODOS los estimados (archivados o no).
  /// La UI filtra por pestaña, columna Kanban y estado de archivado.
  Stream<List<Estimado>> watchEstimados();

  /// Cambia la columna/estado de un estimado (drag&drop del Kanban o
  /// avance entre pestañas).
  Future<void> updateEstado(String id, EstadoKanban nuevoEstado);

  /// Cierre de trato: inyecta el [montoAprobado] elegido por el cliente
  /// y mueve el estimado a [nuevoEstado] (normalmente `pendienteTrabajo`).
  Future<void> aprobarEstimado({
    required String id,
    required double montoAprobado,
    required EstadoKanban nuevoEstado,
  });

  /// Conmuta el flag `archivado` (archivar o restaurar una orden).
  Future<void> setArchivado(String id, bool archivado);

  /// Persiste cambios generales de un estimado (edición de campos).
  Future<void> upsertEstimado(Estimado estimado);

  /// Libera recursos (cierra streams). Llamar al destruir el provider.
  void dispose();
}
