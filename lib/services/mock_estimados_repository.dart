import 'dart:async';

import '../models/estimado.dart';
import 'estimados_repository.dart';
import 'mock_data.dart';

/// Implementación de [EstimadosRepository] para el MODO MOCKUP.
///
/// Mantiene los estimados en memoria y simula tiempo real con un
/// [StreamController] broadcast: cada mutación (drag&drop, aprobación,
/// archivado) reemite la lista completa, igual que haría un WebSocket.
class MockEstimadosRepository implements EstimadosRepository {
  MockEstimadosRepository() : _estimados = MockData.seedEstimados();

  final List<Estimado> _estimados;
  final StreamController<List<Estimado>> _controller =
      StreamController<List<Estimado>>.broadcast();

  @override
  Stream<List<Estimado>> watchEstimados() async* {
    // El nuevo suscriptor recibe el snapshot actual y luego las mutaciones.
    yield _snapshot();
    yield* _controller.stream;
  }

  List<Estimado> _snapshot() => List<Estimado>.unmodifiable(_estimados);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  Future<void> _simularLatencia() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  int _indexOf(String id) => _estimados.indexWhere((e) => e.id == id);

  @override
  Future<void> updateEstado(String id, EstadoKanban nuevoEstado) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _estimados[i] = _estimados[i].copyWith(estadoKanban: nuevoEstado);
    _emit();
  }

  @override
  Future<void> aprobarEstimado({
    required String id,
    required double montoAprobado,
    required EstadoKanban nuevoEstado,
  }) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _estimados[i] = _estimados[i].copyWith(
      montoAprobado: montoAprobado,
      estadoKanban: nuevoEstado,
    );
    _emit();
  }

  @override
  Future<void> setArchivado(String id, bool archivado) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _estimados[i] = _estimados[i].copyWith(archivado: archivado);
    _emit();
  }

  @override
  Future<void> upsertEstimado(Estimado estimado) async {
    await _simularLatencia();
    final i = _indexOf(estimado.id);
    if (i == -1) {
      _estimados.add(estimado);
    } else {
      _estimados[i] = estimado;
    }
    _emit();
  }

  @override
  void dispose() {
    _controller.close();
  }
}
