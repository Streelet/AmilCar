import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_entry.dart';
import '../models/nota.dart';
import '../models/orden_trabajo.dart';
import '../models/pdf_cotizacion.dart';
import '../services/ordenes_trabajo_repository.dart';
import 'audit_provider.dart';
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
  OrdenesTrabajoController(this._repo, this._audit);

  final OrdenesTrabajoRepository _repo;
  final AuditLogger _audit;

  // Helper interno para loguear acciones sobre órdenes.
  void _log(AuditAccion accion, OrdenTrabajo o,
      [Map<String, dynamic>? extras]) {
    _audit.log(
      accion: accion,
      entidad: 'orden_trabajo',
      entidadId: o.id,
      datos: {
        'vehiculo': o.vehiculoResumen,
        ...?extras,
      },
    );
  }

  /// Alta de una orden de trabajo (nueva fila).
  ///
  /// El `id` debe estar generado client-side (UUID v4). Las fases siguientes
  /// — fotos, PDFs, notas — se agregan después por separado vía el modal de
  /// detalle.
  Future<void> agregarOrdenTrabajo(OrdenTrabajo ordenTrabajo) async {
    await _repo.upsertOrdenTrabajo(ordenTrabajo);
    _log(AuditAccion.crearOrden, ordenTrabajo);
  }

  /// Mueve una orden a otra columna del Kanban o pestaña.
  Future<void> moverA(OrdenTrabajo ordenTrabajo, EstadoKanban destino) async {
    await _repo.updateEstado(ordenTrabajo.id, destino);
    _log(AuditAccion.moverOrden, ordenTrabajo, {
      'de': ordenTrabajo.estadoKanban.label,
      'a': destino.label,
    });
  }

  /// Reasigna la orden a otro cliente del directorio.
  /// No hace nada si el cliente es el mismo.
  Future<void> cambiarCliente(
    OrdenTrabajo ordenTrabajo,
    String nuevoClienteId,
  ) async {
    if (ordenTrabajo.clienteId == nuevoClienteId) return;
    await _repo.upsertOrdenTrabajo(
      ordenTrabajo.copyWith(clienteId: nuevoClienteId),
    );
    _log(AuditAccion.editarOrden, ordenTrabajo,
        {'cambio': 'cliente', 'nuevo_cliente_id': nuevoClienteId});
  }

  /// Cierre de trato remoto: mueve la orden a "Pendientes de Trabajo".
  /// Si [montoAprobado] viene con valor, lo registra; si es `null`, solo
  /// mueve el estado sin tocar el monto previo.
  Future<void> aprobarTrato({
    required OrdenTrabajo ordenTrabajo,
    double? montoAprobado,
  }) async {
    if (montoAprobado == null) {
      await _repo.updateEstado(
          ordenTrabajo.id, EstadoKanban.pendienteTrabajo);
    } else {
      await _repo.aprobarOrdenTrabajo(
        id: ordenTrabajo.id,
        montoAprobado: montoAprobado,
        nuevoEstado: EstadoKanban.pendienteTrabajo,
      );
    }
    _log(AuditAccion.moverOrden, ordenTrabajo, {
      'de': ordenTrabajo.estadoKanban.label,
      'a': EstadoKanban.pendienteTrabajo.label,
      if (montoAprobado != null) 'monto': montoAprobado,
    });
  }

  /// Mueve la orden a [destino] sobrescribiendo el `monto_aprobado` con [monto].
  Future<void> moverConMonto({
    required OrdenTrabajo ordenTrabajo,
    required double monto,
    required EstadoKanban destino,
  }) async {
    await _repo.aprobarOrdenTrabajo(
      id: ordenTrabajo.id,
      montoAprobado: monto,
      nuevoEstado: destino,
    );
    _log(AuditAccion.moverOrden, ordenTrabajo, {
      'de': ordenTrabajo.estadoKanban.label,
      'a': destino.label,
      'monto': monto,
    });
  }

  /// Archiva una orden (solo admin).
  Future<void> archivar(OrdenTrabajo ordenTrabajo) async {
    await _repo.setArchivado(ordenTrabajo.id, true);
    _log(AuditAccion.archivarOrden, ordenTrabajo);
  }

  /// Restaura una orden archivada al tablero.
  Future<void> restaurar(OrdenTrabajo ordenTrabajo) async {
    await _repo.setArchivado(ordenTrabajo.id, false);
    _log(AuditAccion.restaurarOrden, ordenTrabajo);
  }

  /// Soft delete: la orden desaparece de todas las vistas.
  Future<void> eliminarOrdenTrabajo(OrdenTrabajo ordenTrabajo) async {
    await _repo.softDeleteOrdenTrabajo(ordenTrabajo.id);
    _log(AuditAccion.eliminarOrden, ordenTrabajo);
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
    ref.watch(auditLoggerProvider),
  );
});
