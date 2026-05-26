import 'dart:async';

import '../models/cliente.dart';
import 'clientes_repository.dart';
import 'mock_data.dart';

/// Implementación de [ClientesRepository] para el MODO MOCKUP.
///
/// Mantiene los clientes en memoria y simula tiempo real con un
/// [StreamController] broadcast: cada mutación (upsert) reemite la lista
/// completa, igual que haría un WebSocket.
class MockClientesRepository implements ClientesRepository {
  MockClientesRepository() : _clientes = MockData.seedClientes();

  final List<Cliente> _clientes;
  final StreamController<List<Cliente>> _controller =
      StreamController<List<Cliente>>.broadcast();

  @override
  Stream<List<Cliente>> watchClientes() async* {
    // El nuevo suscriptor recibe el snapshot actual y luego las mutaciones.
    yield _snapshot();
    yield* _controller.stream;
  }

  /// Snapshot filtra los soft-deleted (mismo comportamiento que las
  /// políticas RLS de Supabase: las filas con `deleted_at != null` son
  /// invisibles desde la app).
  List<Cliente> _snapshot() => List<Cliente>.unmodifiable(
      _clientes.where((c) => c.deletedAt == null));

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  Future<void> _simularLatencia() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  int _indexOf(String id) => _clientes.indexWhere((c) => c.id == id);

  @override
  Future<void> upsertCliente(Cliente cliente) async {
    await _simularLatencia();
    final i = _indexOf(cliente.id);
    if (i == -1) {
      _clientes.add(cliente);
    } else {
      _clientes[i] = cliente;
    }
    _emit();
  }

  @override
  Future<void> softDeleteCliente(String id) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _clientes[i] = _clientes[i].copyWith(deletedAt: DateTime.now());
    _emit();
  }

  @override
  void dispose() {
    _controller.close();
  }
}
