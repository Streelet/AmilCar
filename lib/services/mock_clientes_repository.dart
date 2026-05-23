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

  List<Cliente> _snapshot() => List<Cliente>.unmodifiable(_clientes);

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
  void dispose() {
    _controller.close();
  }
}
