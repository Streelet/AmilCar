import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pago.dart';
import '../services/pagos_repository.dart';
import 'repository_providers.dart';

/// Flujo en tiempo real de TODOS los pagos activos (no soft-deleted).
final pagosStreamProvider = StreamProvider<List<Pago>>((ref) {
  return ref.watch(pagosRepositoryProvider).watchPagos();
});

/// Mapa derivado: `ordenId -> List<Pago>` para lookup O(1) desde las
/// vistas que necesitan los pagos de una orden específica.
///
/// Los pagos quedan ordenados del más reciente al más antiguo dentro de
/// cada orden.
final pagosByOrdenIdProvider = Provider<Map<String, List<Pago>>>((ref) {
  final lista = ref.watch(pagosStreamProvider).valueOrNull ?? const <Pago>[];
  final mapa = <String, List<Pago>>{};
  for (final p in lista) {
    (mapa[p.ordenId] ??= []).add(p);
  }
  for (final entries in mapa.entries) {
    entries.value.sort((a, b) => b.fecha.compareTo(a.fecha));
  }
  return mapa;
});

/// Resumen de pagos para una orden: total cobrado y cantidad de pagos.
class ResumenPagos {
  const ResumenPagos({
    required this.totalCobrado,
    required this.cantidad,
  });
  final double totalCobrado;
  final int cantidad;
}

/// Provider familia: dado un `ordenId`, calcula el total cobrado y la
/// cantidad de pagos activos asociados. Excluye pagos cancelados (no
/// deben sumar al saldo). Útil para tablas y banners de resumen.
final resumenPagosProvider =
    Provider.family<ResumenPagos, String>((ref, ordenId) {
  final pagos = ref.watch(pagosByOrdenIdProvider)[ordenId] ?? const <Pago>[];
  final activos = pagos.where((p) => !p.estaCancelado);
  final total = activos.fold<double>(0, (acc, p) => acc + p.monto);
  return ResumenPagos(totalCobrado: total, cantidad: activos.length);
});

/// Acciones de negocio sobre los pagos.
class PagosController {
  PagosController(this._repo);

  final PagosRepository _repo;

  /// Alta o edición de un pago.
  Future<void> registrarOEditarPago(Pago pago) => _repo.upsertPago(pago);

  /// Cancela un pago: queda visible (tachado) y guarda el [motivo], pero
  /// deja de contar para el saldo.
  Future<void> cancelarPago(Pago pago, String motivo) =>
      _repo.cancelarPago(pago.id, motivo);
}

final pagosControllerProvider = Provider<PagosController>((ref) {
  return PagosController(ref.watch(pagosRepositoryProvider));
});
