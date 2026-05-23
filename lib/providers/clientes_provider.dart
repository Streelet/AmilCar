import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cliente.dart';
import '../services/clientes_repository.dart';
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
  ClientesController(this._repo);

  final ClientesRepository _repo;

  /// Alta o edición de un cliente.
  Future<void> upsertCliente(Cliente cliente) => _repo.upsertCliente(cliente);
}

/// Provider del controlador de acciones de clientes.
final clientesControllerProvider = Provider<ClientesController>((ref) {
  return ClientesController(ref.watch(clientesRepositoryProvider));
});
