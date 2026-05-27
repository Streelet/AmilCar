import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_entry.dart';
import '../models/cliente.dart';
import '../services/clientes_repository.dart';
import 'audit_provider.dart';
import 'repository_providers.dart';

/// Flujo en tiempo real de todos los clientes (mock o Supabase).
///
/// Las vistas consumen este [StreamProvider] indirectamente vía
/// [clientesByIdProvider], que entrega un lookup O(1).
final clientesStreamProvider = StreamProvider<List<Cliente>>((ref) {
  return ref.watch(clientesRepositoryProvider).watchClientes();
});

/// Mapa derivado para resolver un [Cliente] por su id en tiempo constante
/// desde cualquier vista.
///
/// Devuelve un mapa vacío mientras el stream todavía no emitió por primera
/// vez. Las vistas deben renderizar un fallback (`'Cliente desconocido'`)
/// para ese instante transitorio.
final clientesByIdProvider = Provider<Map<String, Cliente>>((ref) {
  final lista =
      ref.watch(clientesStreamProvider).valueOrNull ?? const <Cliente>[];
  return {for (final c in lista) c.id: c};
});

/// Acciones de negocio sobre el directorio de clientes.
class ClientesController {
  ClientesController(this._repo, this._audit);

  final ClientesRepository _repo;
  final AuditLogger _audit;

  /// Alta o edición de un cliente.
  ///
  /// Usa [esNuevo] para distinguir entre creación y edición en el log.
  Future<void> upsertCliente(Cliente cliente, {bool esNuevo = false}) async {
    await _repo.upsertCliente(cliente);
    _audit.log(
      accion: esNuevo ? AuditAccion.crearCliente : AuditAccion.editarCliente,
      entidad: 'cliente',
      entidadId: cliente.id,
      datos: {'nombre': cliente.nombre},
    );
  }

  /// Soft delete: el cliente desaparece de las queries (RLS lo oculta en
  /// Supabase, el repo lo filtra en mock). Las órdenes que lo referencian
  /// seguirán existiendo pero mostrarán "Cliente desconocido" — el
  /// llamador debe avisar al usuario antes de invocar este método.
  Future<void> eliminarCliente(String id, {String? nombre}) async {
    await _repo.softDeleteCliente(id);
    _audit.log(
      accion: AuditAccion.eliminarCliente,
      entidad: 'cliente',
      entidadId: id,
      datos: nombre != null ? {'nombre': nombre} : null,
    );
  }
}

/// Provider del controlador de acciones de clientes.
final clientesControllerProvider = Provider<ClientesController>((ref) {
  return ClientesController(
    ref.watch(clientesRepositoryProvider),
    ref.watch(auditLoggerProvider),
  );
});
