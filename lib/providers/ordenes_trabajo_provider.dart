import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nota.dart';
import '../models/orden_trabajo.dart';
import '../models/pdf_cotizacion.dart';
import '../services/ordenes_trabajo_repository.dart';
import 'repository_providers.dart';

/// Flujo en tiempo real de todas las órdenes de trabajo (mock o Supabase).
/// La UI consume este [StreamProvider] y se reconstruye sola ante cada
/// cambio sincronizado desde el otro dispositivo.
final ordenesTrabajoStreamProvider =
    StreamProvider<List<OrdenTrabajo>>((ref) {
  return ref
      .watch(ordenesTrabajoRepositoryProvider)
      .watchOrdenesTrabajo();
});

/// Órdenes activas (no archivadas), ordenadas por fecha de creación.
final ordenesTrabajoActivasProvider = Provider<List<OrdenTrabajo>>((ref) {
  final lista =
      ref.watch(ordenesTrabajoStreamProvider).valueOrNull ?? const [];
  return lista.where((o) => !o.archivado).toList();
});

/// Órdenes archivadas, para la pantalla de recuperación.
final ordenesTrabajoArchivadasProvider =
    Provider<List<OrdenTrabajo>>((ref) {
  final lista =
      ref.watch(ordenesTrabajoStreamProvider).valueOrNull ?? const [];
  return lista.where((o) => o.archivado).toList();
});

/// Acciones de negocio sobre las órdenes de trabajo. Centraliza las reglas
/// para que las vistas no manipulen el repositorio directamente.
class OrdenesTrabajoController {
  OrdenesTrabajoController(this._repo);

  final OrdenesTrabajoRepository _repo;

  /// Mueve una orden a otra columna del Kanban o pestaña.
  Future<void> moverA(OrdenTrabajo ordenTrabajo, EstadoKanban destino) {
    return _repo.updateEstado(ordenTrabajo.id, destino);
  }

  /// Cierre de trato remoto: inyecta el monto de la opción que el cliente
  /// aprobó en el lugar y envía la tarjeta a "Pendientes de Trabajo".
  Future<void> aprobarTrato({
    required OrdenTrabajo ordenTrabajo,
    required PdfCotizacion opcionElegida,
  }) {
    return _repo.aprobarOrdenTrabajo(
      id: ordenTrabajo.id,
      montoAprobado: opcionElegida.montoSugerido,
      nuevoEstado: EstadoKanban.pendienteTrabajo,
    );
  }

  /// Archiva una orden (solo admin).
  Future<void> archivar(OrdenTrabajo ordenTrabajo) {
    return _repo.setArchivado(ordenTrabajo.id, true);
  }

  /// Restaura una orden archivada al tablero.
  Future<void> restaurar(OrdenTrabajo ordenTrabajo) {
    return _repo.setArchivado(ordenTrabajo.id, false);
  }

  /// Agrega una cotización (PDF) a la orden.
  Future<void> agregarCotizacion(
    OrdenTrabajo ordenTrabajo,
    PdfCotizacion cotizacion,
  ) {
    return _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(
        pdfsUrls: [...ordenTrabajo.pdfsUrls, cotizacion],
      ),
    );
  }

  /// Quita una cotización de la orden por su posición.
  Future<void> quitarCotizacion(OrdenTrabajo ordenTrabajo, int indice) {
    final nuevas = [...ordenTrabajo.pdfsUrls]..removeAt(indice);
    return _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(pdfsUrls: nuevas),
    );
  }

  /// Agrega una foto del daño a la orden.
  Future<void> agregarFoto(OrdenTrabajo ordenTrabajo, String nombreArchivo) {
    return _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(
        fotosUrls: [...ordenTrabajo.fotosUrls, nombreArchivo],
      ),
    );
  }

  /// Agrega una nota con detalles del trabajo.
  Future<void> agregarNota(OrdenTrabajo ordenTrabajo, Nota nota) {
    return _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(notas: [...ordenTrabajo.notas, nota]),
    );
  }

  /// Quita una nota de la orden por su posición.
  Future<void> quitarNota(OrdenTrabajo ordenTrabajo, int indice) {
    final nuevas = [...ordenTrabajo.notas]..removeAt(indice);
    return _repo.upsertOrdenTrabajo(ordenTrabajo.copyWith(notas: nuevas));
  }

  /// Edita el texto de una nota existente, conservando la fecha original.
  Future<void> editarNota(
    OrdenTrabajo ordenTrabajo,
    int indice,
    String nuevoTexto,
  ) {
    final nuevas = [...ordenTrabajo.notas];
    nuevas[indice] = nuevas[indice].copyWith(texto: nuevoTexto);
    return _repo.upsertOrdenTrabajo(ordenTrabajo.copyWith(notas: nuevas));
  }
}

/// Provider del controlador de acciones.
final ordenesTrabajoControllerProvider =
    Provider<OrdenesTrabajoController>((ref) {
  return OrdenesTrabajoController(
    ref.watch(ordenesTrabajoRepositoryProvider),
  );
});
