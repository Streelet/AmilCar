import 'dart:async';

import '../models/orden_trabajo.dart';
import 'mock_data.dart';
import 'ordenes_trabajo_repository.dart';

/// Implementación de [OrdenesTrabajoRepository] para el MODO MOCKUP.
///
/// Mantiene las órdenes en memoria y simula tiempo real con un
/// [StreamController] broadcast: cada mutación (drag&drop, aprobación,
/// archivado) reemite la lista completa, igual que haría un WebSocket.
class MockOrdenesTrabajoRepository implements OrdenesTrabajoRepository {
  MockOrdenesTrabajoRepository()
      : _ordenesTrabajo = MockData.seedOrdenesTrabajo();

  final List<OrdenTrabajo> _ordenesTrabajo;
  final StreamController<List<OrdenTrabajo>> _controller =
      StreamController<List<OrdenTrabajo>>.broadcast();

  @override
  Stream<List<OrdenTrabajo>> watchOrdenesTrabajo() async* {
    // El nuevo suscriptor recibe el snapshot actual y luego las mutaciones.
    yield _snapshot();
    yield* _controller.stream;
  }

  List<OrdenTrabajo> _snapshot() =>
      List<OrdenTrabajo>.unmodifiable(_ordenesTrabajo);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  Future<void> _simularLatencia() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  int _indexOf(String id) => _ordenesTrabajo.indexWhere((o) => o.id == id);

  @override
  Future<void> updateEstado(String id, EstadoKanban nuevoEstado) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _ordenesTrabajo[i] =
        _ordenesTrabajo[i].copyWith(estadoKanban: nuevoEstado);
    _emit();
  }

  @override
  Future<void> aprobarOrdenTrabajo({
    required String id,
    required double montoAprobado,
    required EstadoKanban nuevoEstado,
  }) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _ordenesTrabajo[i] = _ordenesTrabajo[i].copyWith(
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
    _ordenesTrabajo[i] = _ordenesTrabajo[i].copyWith(archivado: archivado);
    _emit();
  }

  @override
  Future<void> upsertOrdenTrabajo(OrdenTrabajo ordenTrabajo) async {
    await _simularLatencia();
    final i = _indexOf(ordenTrabajo.id);
    if (i == -1) {
      _ordenesTrabajo.add(ordenTrabajo);
    } else {
      _ordenesTrabajo[i] = ordenTrabajo;
    }
    _emit();
  }

  @override
  void dispose() {
    _controller.close();
  }
}
