import '../models/pago.dart';

/// Contrato de acceso a datos de los pagos / anticipos.
///
/// Capa desacoplada: la UI consume SOLO esta interfaz. La implementación
/// real ([SupabasePagosRepository]) o ficticia ([MockPagosRepository]) se
/// elige en tiempo de arranque según `AppConfig.useMockData`.
abstract interface class PagosRepository {
  /// Flujo en tiempo real de TODOS los pagos (no soft-deleted).
  /// La UI agrupa por `ordenId` para mostrarlos donde correspondan.
  Stream<List<Pago>> watchPagos();

  /// Alta o edición de un pago.
  Future<void> upsertPago(Pago pago);

  /// Cancela un pago: marca `cancelado_at = now()` y guarda el [motivo].
  /// El pago se sigue viendo en la UI (tachado), pero deja de contar
  /// para el saldo. Distinto de [softDeletePago] que oculta totalmente.
  Future<void> cancelarPago(String id, String motivo);

  /// Soft delete: marca `deleted_at = now()`. El pago desaparece de
  /// todas las vistas. La UI usa [cancelarPago] en su lugar; este
  /// método queda disponible solo para flujos administrativos futuros.
  Future<void> softDeletePago(String id);

  /// Libera recursos (cierra streams).
  void dispose();
}
