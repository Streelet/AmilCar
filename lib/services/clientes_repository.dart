import '../models/cliente.dart';

/// Contrato de acceso a datos del directorio de clientes.
///
/// Capa desacoplada: la UI consume SOLO esta interfaz. La implementación
/// real ([SupabaseClientesRepository]) o ficticia ([MockClientesRepository])
/// se elige en tiempo de arranque según `AppConfig.useMockData`.
///
/// El método [watchClientes] entrega un flujo en tiempo real: en Supabase
/// usa Streams/WebSockets nativos; en mock, un stream en memoria que
/// reemite tras cada mutación.
abstract interface class ClientesRepository {
  /// Flujo en tiempo real de TODOS los clientes registrados.
  Stream<List<Cliente>> watchClientes();

  /// Persiste cambios generales de un cliente (alta o edición).
  Future<void> upsertCliente(Cliente cliente);

  /// Soft delete: marca `deleted_at = now()`. El cliente desaparece de
  /// todas las queries pero la fila permanece en la BD para auditoría.
  /// Recuperable por SQL.
  Future<void> softDeleteCliente(String id);

  /// Libera recursos (cierra streams). Llamar al destruir el provider.
  void dispose();
}
