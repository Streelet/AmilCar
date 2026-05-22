import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/estimado.dart';
import '../models/pdf_cotizacion.dart';
import '../services/estimados_repository.dart';
import 'repository_providers.dart';

/// Flujo en tiempo real de todos los estimados (mock o Supabase).
/// La UI consume este [StreamProvider] y se reconstruye sola ante cada
/// cambio sincronizado desde el otro dispositivo.
final estimadosStreamProvider = StreamProvider<List<Estimado>>((ref) {
  return ref.watch(estimadosRepositoryProvider).watchEstimados();
});

/// Estimados activos (no archivados), ordenados por fecha de creación.
final estimadosActivosProvider = Provider<List<Estimado>>((ref) {
  final lista = ref.watch(estimadosStreamProvider).valueOrNull ?? const [];
  return lista.where((e) => !e.archivado).toList();
});

/// Estimados archivados, para la pantalla de recuperación.
final estimadosArchivadosProvider = Provider<List<Estimado>>((ref) {
  final lista = ref.watch(estimadosStreamProvider).valueOrNull ?? const [];
  return lista.where((e) => e.archivado).toList();
});

/// Acciones de negocio sobre los estimados. Centraliza las reglas para que
/// las vistas no manipulen el repositorio directamente.
class EstimadosController {
  EstimadosController(this._repo);

  final EstimadosRepository _repo;

  /// Mueve un estimado a otra columna del Kanban o pestaña.
  Future<void> moverA(Estimado estimado, EstadoKanban destino) {
    return _repo.updateEstado(estimado.id, destino);
  }

  /// Cierre de trato remoto: inyecta el monto de la opción que el cliente
  /// aprobó en el lugar y envía la tarjeta a "Pendientes de Trabajo".
  Future<void> aprobarTrato({
    required Estimado estimado,
    required PdfCotizacion opcionElegida,
  }) {
    return _repo.aprobarEstimado(
      id: estimado.id,
      montoAprobado: opcionElegida.montoSugerido,
      nuevoEstado: EstadoKanban.pendienteTrabajo,
    );
  }

  /// Archiva una orden (solo admin).
  Future<void> archivar(Estimado estimado) {
    return _repo.setArchivado(estimado.id, true);
  }

  /// Restaura una orden archivada al tablero.
  Future<void> restaurar(Estimado estimado) {
    return _repo.setArchivado(estimado.id, false);
  }

  /// Agrega una cotización (PDF) al estimado.
  Future<void> agregarCotizacion(Estimado estimado, PdfCotizacion cotizacion) {
    return _repo.upsertEstimado(
      estimado.copyWith(pdfsUrls: [...estimado.pdfsUrls, cotizacion]),
    );
  }

  /// Quita una cotización del estimado por su posición.
  Future<void> quitarCotizacion(Estimado estimado, int indice) {
    final nuevas = [...estimado.pdfsUrls]..removeAt(indice);
    return _repo.upsertEstimado(estimado.copyWith(pdfsUrls: nuevas));
  }

  /// Agrega una foto del daño al estimado.
  Future<void> agregarFoto(Estimado estimado, String nombreArchivo) {
    return _repo.upsertEstimado(
      estimado.copyWith(fotosUrls: [...estimado.fotosUrls, nombreArchivo]),
    );
  }
}

/// Provider del controlador de acciones.
final estimadosControllerProvider = Provider<EstimadosController>((ref) {
  return EstimadosController(ref.watch(estimadosRepositoryProvider));
});
