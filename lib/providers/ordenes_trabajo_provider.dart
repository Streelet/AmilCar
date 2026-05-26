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

  /// Alta de una orden de trabajo (nueva fila).
  ///
  /// El `id` debe estar generado client-side (UUID v4). Las fases siguientes
  /// — fotos, PDFs, notas — se agregan después por separado vía el modal de
  /// detalle.
  Future<void> agregarOrdenTrabajo(OrdenTrabajo ordenTrabajo) {
    return _repo.upsertOrdenTrabajo(ordenTrabajo);
  }

  /// Mueve una orden a otra columna del Kanban o pestaña.
  Future<void> moverA(OrdenTrabajo ordenTrabajo, EstadoKanban destino) {
    return _repo.updateEstado(ordenTrabajo.id, destino);
  }

  /// Reasigna la orden a otro cliente del directorio.
  /// No hace nada si el cliente es el mismo.
  Future<void> cambiarCliente(
    OrdenTrabajo ordenTrabajo,
    String nuevoClienteId,
  ) {
    if (ordenTrabajo.clienteId == nuevoClienteId) return Future.value();
    return _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(clienteId: nuevoClienteId),
    );
  }

  /// Cierre de trato remoto: mueve la orden a "Pendientes de Trabajo".
  /// Si [montoAprobado] viene con valor, lo registra; si es `null`, solo
  /// mueve el estado sin tocar el monto previo (sirve cuando la orden no
  /// tiene Estimados PDF y aún no se acordó cifra).
  Future<void> aprobarTrato({
    required OrdenTrabajo ordenTrabajo,
    double? montoAprobado,
  }) {
    if (montoAprobado == null) {
      return _repo.updateEstado(
          ordenTrabajo.id, EstadoKanban.pendienteTrabajo);
    }
    return _repo.aprobarOrdenTrabajo(
      id: ordenTrabajo.id,
      montoAprobado: montoAprobado,
      nuevoEstado: EstadoKanban.pendienteTrabajo,
    );
  }

  /// Mueve la orden a [destino] sobrescribiendo el `monto_aprobado` con
  /// [monto]. Operación atómica (un solo UPDATE en Supabase). Pensado
  /// para transiciones como "En Proceso → Pendiente de Pago" donde se
  /// fija el monto definitivo a cobrar.
  Future<void> moverConMonto({
    required OrdenTrabajo ordenTrabajo,
    required double monto,
    required EstadoKanban destino,
  }) {
    return _repo.aprobarOrdenTrabajo(
      id: ordenTrabajo.id,
      montoAprobado: monto,
      nuevoEstado: destino,
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

  /// Soft delete: la orden desaparece de todas las vistas (incluido el
  /// tablero de archivadas). Los pagos vinculados quedan huérfanos en la
  /// BD para auditoría — el cascade SQL los borra solo si se hace HARD
  /// delete, no si se hace soft delete. Recuperable por SQL.
  Future<void> eliminarOrdenTrabajo(OrdenTrabajo ordenTrabajo) {
    return _repo.softDeleteOrdenTrabajo(ordenTrabajo.id);
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
