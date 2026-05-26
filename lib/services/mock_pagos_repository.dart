import 'dart:async';

import '../models/pago.dart';
import 'mock_data.dart';
import 'pagos_repository.dart';

/// Implementación de [PagosRepository] para el MODO MOCKUP.
class MockPagosRepository implements PagosRepository {
  MockPagosRepository() : _pagos = MockData.seedPagos();

  final List<Pago> _pagos;
  final StreamController<List<Pago>> _controller =
      StreamController<List<Pago>>.broadcast();

  @override
  Stream<List<Pago>> watchPagos() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  /// Filtra soft-deleted (paridad con políticas RLS de Supabase).
  List<Pago> _snapshot() =>
      List<Pago>.unmodifiable(_pagos.where((p) => p.deletedAt == null));

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  Future<void> _simularLatencia() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  int _indexOf(String id) => _pagos.indexWhere((p) => p.id == id);

  @override
  Future<void> upsertPago(Pago pago) async {
    await _simularLatencia();
    final i = _indexOf(pago.id);
    if (i == -1) {
      _pagos.add(pago);
    } else {
      _pagos[i] = pago;
    }
    _emit();
  }

  @override
  Future<void> cancelarPago(String id, String motivo) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _pagos[i] = _pagos[i].copyWith(
      canceladoAt: DateTime.now(),
      motivoCancelacion: motivo,
    );
    _emit();
  }

  @override
  Future<void> softDeletePago(String id) async {
    await _simularLatencia();
    final i = _indexOf(id);
    if (i == -1) return;
    _pagos[i] = _pagos[i].copyWith(deletedAt: DateTime.now());
    _emit();
  }

  @override
  void dispose() {
    _controller.close();
  }
}
