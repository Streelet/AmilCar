import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cliente.dart';
import '../../models/orden_trabajo.dart';
import '../../models/pago.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import '../../config/app_config.dart';
import '../../providers/filtros_provider.dart';
import '../../providers/pagos_provider.dart';
import '../../services/pdf_export_service.dart';
import '../widgets/aprobacion_dialog.dart';
import '../widgets/barra_filtros.dart';
import '../widgets/estado_pill.dart';
import '../widgets/orden_trabajo_detail_modal.dart';
import '../widgets/pago_form_dialog.dart';
import '../widgets/pdf_preview_screen.dart';
import '../widgets/soft_card.dart';

/// Estilo de la acción rápida que se aplica al apretar el botón en la fila.
enum EstiloAccionRapida {
  /// Mueve la orden al destino y muestra snackbar con "Deshacer".
  movimientoSimple,

  /// Abre el diálogo "Mover a Por Cobrar" (monto manual preferido, o
  /// desde Estimado PDF) antes de mover. Sin Deshacer: la confirmación
  /// está en el diálogo.
  moverAPendientePagoConMonto,

  /// Abre el formulario de pago. NO mueve la orden; solo registra un
  /// pago contra ella. Pensado para la vista "Por Cobrar".
  registrarPago,
}

/// Botón rápido de transición de estado para mostrar en cada fila/tarjeta.
///
/// [label] es el texto largo (para botones de tarjeta).
/// [labelCorta] es el texto compacto (para celdas de tabla); si es null,
/// la vista tabla usa [label].
class AccionRapidaOrden {
  const AccionRapidaOrden({
    required this.icono,
    required this.label,
    this.labelCorta,
    required this.destino,
    this.estilo = EstiloAccionRapida.movimientoSimple,
  });

  final IconData icono;
  final String label;
  final String? labelCorta;
  final EstadoKanban destino;
  final EstiloAccionRapida estilo;
}

/// Ejecuta la acción según su estilo. Centralizado para que la fila de
/// tabla y la tarjeta de grilla compartan el mismo comportamiento.
Future<void> _ejecutarAccion(
  BuildContext context,
  WidgetRef ref,
  OrdenTrabajo orden,
  AccionRapidaOrden accion,
) async {
  switch (accion.estilo) {
    case EstiloAccionRapida.movimientoSimple:
      final messenger = ScaffoldMessenger.of(context);
      final estadoOrigen = orden.estadoKanban;
      await ref
          .read(ordenesTrabajoControllerProvider)
          .moverA(orden, accion.destino);
      messenger.showSnackBar(SnackBar(
        content: Text('Movido a "${accion.destino.label}".'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => ref
              .read(ordenesTrabajoControllerProvider)
              .moverA(orden, estadoOrigen),
        ),
      ));
      break;
    case EstiloAccionRapida.moverAPendientePagoConMonto:
      await ejecutarMoverAPendientePago(context, ref, orden);
      break;
    case EstiloAccionRapida.registrarPago:
      final resumen = ref.read(resumenPagosProvider(orden.id));
      final aprobado = orden.montoAprobado ?? 0;
      final restante = (aprobado - resumen.totalCobrado).clamp(0, 1e15).toDouble();
      await mostrarFormularioPago(
        context,
        orden: orden,
        restante: restante,
      );
      break;
  }
}

/// Pestaña genérica de listado para las fases posteriores a la fase
/// "Estimado" ("Pendientes de Trabajo", "En Proceso", "Pendiente de Pago").
///
/// Modos:
///  - Por defecto: grilla de 1 o 2 columnas con tarjetas.
///  - [comoTabla] = true: tabla densa pensada para ver muchas órdenes a la
///    vez con sus datos esenciales (cliente, vehículo, monto, fecha,
///    acción rápida).
///
/// Si se pasa [accionRapida], cada fila/tarjeta muestra un botón que mueve
/// la orden al estado indicado, con snackbar de "Deshacer".
class ListaOrdenesTrabajoTab extends ConsumerWidget {
  const ListaOrdenesTrabajoTab({
    super.key,
    required this.estado,
    required this.icono,
    required this.mensajeVacio,
    this.comoTabla = false,
    this.accionRapida,
    this.vistaCobros = false,
  });

  final EstadoKanban estado;
  final IconData icono;
  final String mensajeVacio;
  final bool comoTabla;
  final AccionRapidaOrden? accionRapida;

  /// `true` cambia las columnas Monto + Creada por Total + Cobrado + Restante.
  /// Solo aplica cuando [comoTabla] es true. Pensado para "Por Cobrar".
  final bool vistaCobros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordenesTrabajoStreamProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => _Mensaje(
        icono: Icons.cloud_off_rounded,
        texto: 'Sin conexión. Revisa tu red e intenta de nuevo.',
      ),
      data: (todas) {
        final filtroCliente = ref.watch(filtroClienteIdProvider);
        final filtroRango = ref.watch(filtroRangoFechasProvider);
        final hayFiltros = ref.watch(hayFiltrosActivosProvider);

        final items = todas.where((o) {
          if (o.archivado) return false;
          if (o.estadoKanban != estado) return false;
          if (filtroCliente != null && o.clienteId != filtroCliente) {
            return false;
          }
          if (filtroRango != null) {
            final f = o.createdAt;
            if (f == null) return false;
            final desde = filtroRango.start;
            final hasta = filtroRango.end.add(const Duration(days: 1));
            if (f.isBefore(desde) || !f.isBefore(hasta)) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Barra de filtros compartida con el Kanban — el estado es
            // global, así que el filtro que pongas acá también se ve en
            // las otras pestañas.
            const BarraFiltros(),
            Expanded(
              child: items.isEmpty
                  ? _Mensaje(
                      icono: hayFiltros
                          ? Icons.filter_alt_off_rounded
                          : icono,
                      texto: hayFiltros
                          ? 'Sin resultados para los filtros actuales.'
                          : mensajeVacio,
                    )
                  : comoTabla
                      ? _VistaTabla(
                          items: items,
                          estado: estado,
                          accionRapida: accionRapida,
                          vistaCobros: vistaCobros,
                        )
                      : _VistaGrilla(
                          items: items,
                          icono: icono,
                          accionRapida: accionRapida,
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════ VISTA TABLA ════════════════════════

class _VistaTabla extends ConsumerWidget {
  const _VistaTabla({
    required this.items,
    required this.estado,
    this.accionRapida,
    this.vistaCobros = false,
  });

  final List<OrdenTrabajo> items;
  final EstadoKanban estado;
  final AccionRapidaOrden? accionRapida;
  final bool vistaCobros;

  /// Solo las pestañas "Pendientes de Trabajo", "En Proceso" y
  /// "Pendiente de Pago" tienen reporte PDF.
  bool get _puedeExportarPdf =>
      estado == EstadoKanban.pendienteTrabajo ||
      estado == EstadoKanban.enProceso ||
      estado == EstadoKanban.pendientePago;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clientesById = ref.watch(clientesByIdProvider);
    final pagosByOrden = vistaCobros
        ? ref.watch(pagosByOrdenIdProvider)
        : const <String, List<Pago>>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${items.length} orden${items.length == 1 ? '' : 'es'} en esta etapa',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      if (_puedeExportarPdf && items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _exportarPdf(
                            context,
                            items: items,
                            clientesById: clientesById,
                            pagosByOrden: pagosByOrden,
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 18),
                          label: const Text('Exportar PDF'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 48,
                          dataRowMinHeight: 70,
                          dataRowMaxHeight: 88,
                          headingRowColor: WidgetStateProperty.all(
                              AppColors.surfaceContainerLow),
                          dividerThickness: 0.6,
                          columnSpacing: 28,
                          horizontalMargin: 20,
                          columns: [
                            const DataColumn(label: _HeaderText('Cliente')),
                            const DataColumn(
                                label: _HeaderText('Vehículo')),
                            if (vistaCobros) ...const [
                              DataColumn(
                                  label: _HeaderText('Total'),
                                  numeric: true),
                              DataColumn(
                                  label: _HeaderText('Cobrado'),
                                  numeric: true),
                              DataColumn(
                                  label: _HeaderText('Restante'),
                                  numeric: true),
                              DataColumn(label: _HeaderText('Desde')),
                            ] else ...const [
                              DataColumn(
                                  label: _HeaderText('Monto'),
                                  numeric: true),
                              DataColumn(label: _HeaderText('Creada')),
                            ],
                            if (accionRapida != null)
                              const DataColumn(
                                  label: _HeaderText('Acción')),
                          ],
                          rows: [
                            for (final o in items)
                              DataRow(
                                onSelectChanged: (_) =>
                                    mostrarDetalleOrdenTrabajo(
                                        context, o.id),
                                cells: [
                                  DataCell(_CeldaCliente(
                                      cliente:
                                          clientesById[o.clienteId])),
                                  DataCell(_CeldaVehiculo(orden: o)),
                                  if (vistaCobros) ...[
                                    DataCell(_CeldaMonto(orden: o)),
                                    DataCell(_CeldaCobrado(
                                        orden: o,
                                        cobrado: _cobradoDe(
                                            pagosByOrden, o.id))),
                                    DataCell(_CeldaRestante(
                                        orden: o,
                                        cobrado: _cobradoDe(
                                            pagosByOrden, o.id))),
                                    DataCell(_CeldaDesde(orden: o)),
                                  ] else ...[
                                    DataCell(_CeldaMonto(orden: o)),
                                    DataCell(Text(
                                      o.fechaRelativa.isEmpty
                                          ? '—'
                                          : o.fechaRelativa,
                                      style: theme.textTheme.bodyMedium,
                                    )),
                                  ],
                                  if (accionRapida != null)
                                    DataCell(_BotonAccionTabla(
                                        orden: o,
                                        accion: accionRapida!)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _cobradoDe(Map<String, List<Pago>> mapa, String ordenId) {
    final pagos = mapa[ordenId];
    if (pagos == null) return 0;
    // Los pagos cancelados NO suman al saldo.
    return pagos
        .where((p) => !p.estaCancelado)
        .fold<double>(0, (acc, p) => acc + p.monto);
  }

  /// Abre el preview del PDF en una pantalla full-screen con controles
  /// integrados para descargar, imprimir y compartir.
  ///
  /// El render del preview en web requiere `pdf.js` cargado en
  /// `web/index.html` — ya está incluido.
  Future<void> _exportarPdf(
    BuildContext context, {
    required List<OrdenTrabajo> items,
    required Map<String, Cliente> clientesById,
    required Map<String, List<Pago>> pagosByOrden,
  }) async {
    PdfIdioma? idiomaPago;
    if (estado == EstadoKanban.pendientePago) {
      idiomaPago = await _elegirIdiomaPdf(context);
      if (idiomaPago == null) return;
    }
    final (titulo, nombre) = switch (estado) {
      EstadoKanban.pendientePago => (
          idiomaPago == PdfIdioma.en ? 'Pending invoices' : 'Facturas pendientes',
          idiomaPago == PdfIdioma.en
              ? 'pending_invoices_${_timestampArchivo()}.pdf'
              : 'facturas_pendientes_${_timestampArchivo()}.pdf',
        ),
      EstadoKanban.enProceso => (
          'En Proceso',
          'en_proceso_${_timestampArchivo()}.pdf',
        ),
      _ => (
          'Pendientes de Trabajo',
          'pendientes_de_trabajo_${_timestampArchivo()}.pdf',
        ),
    };

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PdfPreviewScreen(
          titulo: titulo,
          nombreArchivo: nombre,
          buildBytes: () {
            switch (estado) {
              case EstadoKanban.pendientePago:
                return PdfExportService.pendientesDePago(
                  ordenes: items,
                  clientesById: clientesById,
                  pagosByOrdenId: pagosByOrden,
                  idioma: idiomaPago ?? PdfIdioma.es,
                );
              case EstadoKanban.enProceso:
                return PdfExportService.enProceso(
                  ordenes: items,
                  clientesById: clientesById,
                );
              case EstadoKanban.pendienteTrabajo:
                return PdfExportService.pendientesDeTrabajo(
                  ordenes: items,
                  clientesById: clientesById,
                );
              case EstadoKanban.porHacer:
              case EstadoKanban.listosParaEnviar:
              case EstadoKanban.esperandoAprobacion:
                return PdfExportService.pendientesDeTrabajo(
                  ordenes: items,
                  clientesById: clientesById,
                );
            }
          },
        ),
      ),
    );
  }

  Future<PdfIdioma?> _elegirIdiomaPdf(BuildContext context) {
    return showDialog<PdfIdioma>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Idioma del PDF'),
          content: const Text(
            'Elige el idioma para el reporte de facturas pendientes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(PdfIdioma.es),
              child: const Text('Español'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(PdfIdioma.en),
              child: const Text('English'),
            ),
          ],
        );
      },
    );
  }

  static String _timestampArchivo() {
    final d = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${dos(d.month)}${dos(d.day)}_${dos(d.hour)}${dos(d.minute)}';
  }
}

/// Celda "Cobrado". Verde si > 0.
class _CeldaCobrado extends StatelessWidget {
  const _CeldaCobrado({required this.orden, required this.cobrado});
  final OrdenTrabajo orden;
  final double cobrado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cobrado <= 0) {
      return Text('—',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppColors.onSurfaceVariant));
    }
    return Text(
      _fmt(cobrado),
      style: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF1C8175),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Celda "Restante" con badge "Pagado completo" cuando llega a 0.
class _CeldaRestante extends StatelessWidget {
  const _CeldaRestante({required this.orden, required this.cobrado});
  final OrdenTrabajo orden;
  final double cobrado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aprobado = orden.montoAprobado;
    if (aprobado == null) {
      return Text('—',
          style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic));
    }
    final restante = aprobado - cobrado;
    if (restante <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD4ECE8),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 14, color: Color(0xFF1C8175)),
            const SizedBox(width: 4),
            Text(
              'Pagado',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF1C8175),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      _fmt(restante),
      style: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFFAE7C12),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _fmt(double monto) {
  final entero = monto.round();
  final texto = entero.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '${AppConfig.currencySymbol}$texto';
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      texto.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _CeldaCliente extends StatelessWidget {
  const _CeldaCliente({required this.cliente});
  final Cliente? cliente;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cliente?.nombre ?? 'Cliente desconocido',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (cliente?.telefono != null && cliente!.telefono!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_rounded,
                    size: 12, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(cliente!.telefono!,
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _CeldaVehiculo extends StatelessWidget {
  const _CeldaVehiculo({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          orden.vehiculoResumen,
          style: theme.textTheme.bodyLarge,
        ),
        if (orden.vehiculoVin != null && orden.vehiculoVin!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'VIN ${orden.vehiculoVin}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Celda que muestra cuándo la orden entró al estado actual.
/// Usa [OrdenTrabajo.estadoUpdatedAt] y cae a [OrdenTrabajo.createdAt]
/// cuando la orden se creó directamente en el estado.
class _CeldaDesde extends StatelessWidget {
  const _CeldaDesde({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final fecha = orden.estadoUpdatedAt ?? orden.createdAt;
    final theme = Theme.of(context);

    if (fecha == null) {
      return Text(
        '—',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: AppColors.onSurfaceVariant),
      );
    }

    final d = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    final fechaStr =
        '${dos(d.day)}/${dos(d.month)}/${d.year}';
    final diff = DateTime.now().difference(fecha);
    final relativa = switch (diff.inDays) {
      0 => 'hoy',
      1 => 'ayer',
      final n when n < 7 => 'hace $n días',
      final n when n < 30 => 'hace ${(n / 7).floor()} sem',
      final n when n < 365 => 'hace ${(n / 30).floor()} mes',
      _ => 'hace ${(diff.inDays / 365).floor()} año',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fechaStr,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        Text(
          relativa,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CeldaMonto extends StatelessWidget {
  const _CeldaMonto({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (orden.montoAprobado == null) {
      return Text(
        'Sin registrar',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(
      orden.montoAprobadoFormateado,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BotonAccionTabla extends ConsumerWidget {
  const _BotonAccionTabla({required this.orden, required this.accion});
  final OrdenTrabajo orden;
  final AccionRapidaOrden accion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () => _ejecutarAccion(context, ref, orden, accion),
      icon: Icon(accion.icono, size: 18),
      label: Text(accion.labelCorta ?? accion.label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ════════════════════════ VISTA GRILLA (default) ════════════════════════

class _VistaGrilla extends StatelessWidget {
  const _VistaGrilla({
    required this.items,
    required this.icono,
    required this.accionRapida,
  });

  final List<OrdenTrabajo> items;
  final IconData icono;
  final AccionRapidaOrden? accionRapida;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dosColumnas = constraints.maxWidth >= 760;
        final padding = dosColumnas
            ? AppSpacing.marginDesktop
            : AppSpacing.marginMobile;
        final anchoContenido = (constraints.maxWidth - padding * 2)
            .clamp(0.0, 1100.0)
            .toDouble();
        final anchoItem = dosColumnas
            ? (anchoContenido - AppSpacing.gutter) / 2
            : anchoContenido;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Wrap(
                spacing: AppSpacing.gutter,
                runSpacing: 16,
                children: [
                  for (final o in items)
                    SizedBox(
                      width: anchoItem,
                      child: _OrdenTrabajoCard(
                        ordenTrabajo: o,
                        icono: icono,
                        accionRapida: accionRapida,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrdenTrabajoCard extends ConsumerWidget {
  const _OrdenTrabajoCard({
    required this.ordenTrabajo,
    required this.icono,
    required this.accionRapida,
  });

  final OrdenTrabajo ordenTrabajo;
  final IconData icono;
  final AccionRapidaOrden? accionRapida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(ordenTrabajo.estadoKanban);
    final cliente =
        ref.watch(clientesByIdProvider)[ordenTrabajo.clienteId];

    return SoftCard(
      onTap: () => mostrarDetalleOrdenTrabajo(context, ordenTrabajo.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: estilo.container,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(icono, color: estilo.color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EstadoPill(
                        estado: ordenTrabajo.estadoKanban, dense: true),
                    const SizedBox(height: 6),
                    Text(ordenTrabajo.vehiculoResumen,
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _Linea(
            icono: Icons.person_outline_rounded,
            texto: cliente?.nombre ?? 'Cliente desconocido',
          ),
          if (cliente?.telefono != null && cliente!.telefono!.isNotEmpty)
            _Linea(
              icono: Icons.phone_outlined,
              texto: cliente.telefono!,
            ),
          if (cliente?.direccion != null &&
              cliente!.direccion!.isNotEmpty)
            _Linea(
              icono: Icons.location_on_outlined,
              texto: cliente.direccion!,
            ),
          if (cliente?.email != null && cliente!.email!.isNotEmpty)
            _Linea(
              icono: Icons.email_outlined,
              texto: cliente.email!,
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: estilo.color,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monto aprobado',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.onPrimary),
                ),
                Text(
                  ordenTrabajo.montoAprobado != null
                      ? ordenTrabajo.montoAprobadoFormateado
                      : 'Sin registrar',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: AppColors.onPrimary),
                ),
              ],
            ),
          ),
          if (accionRapida != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _ejecutarAccion(
                  context, ref, ordenTrabajo, accionRapida!),
              icon: Icon(accionRapida!.icono, size: 18),
              label: Text(accionRapida!.label),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════ COMPARTIDOS ════════════════════════

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 46, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
