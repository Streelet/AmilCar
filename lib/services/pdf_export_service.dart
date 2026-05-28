import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../models/cliente.dart';
import '../models/orden_trabajo.dart';
import '../models/pago.dart';
import '../models/pdf_cotizacion.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PdfExportService
///
///  Genera reportes PDF profesionales de las listas de órdenes de trabajo.
///  Reportes soportados:
///   • Pendientes de Estimado (3 secciones por columna de Kanban)
///   • Pendientes de Trabajo  (columnas: cliente, vehículo, monto, contacto)
///   • En Proceso             (columnas: cliente, vehículo, monto, contacto)
///   • Pendientes de Pago     (columnas: cliente, vehículo, total, cobrado,
///                              restante, desde)
///
///  El layout es A4 vertical con encabezado, resumen, tabla auto-paginada
///  y pie con número de página.
/// ─────────────────────────────────────────────────────────────────────────

enum PdfIdioma { es, en }

class PdfExportService {
  // ── Paleta usada en el PDF (consistente con la app: grafito azulado) ──
  static final PdfColor _primario = PdfColor.fromInt(0xFF33373D);
  static final PdfColor _primarioSuave = PdfColor.fromInt(0xFFE2E6EA);
  static final PdfColor _gris = PdfColor.fromInt(0xFF6C737C);
  static final PdfColor _grisSuave = PdfColor.fromInt(0xFFF1F2F4);
  static final PdfColor _exito = PdfColor.fromInt(0xFF1C8175);
  static final PdfColor _alerta = PdfColor.fromInt(0xFFAE7C12);
  static final PdfColor _borde = PdfColor.fromInt(0xFFD7DCE3);
  static final PdfColor _texto = PdfColor.fromInt(0xFF1B1F25);

  /// Genera el PDF de **Pendientes de Trabajo**.
  /// Devuelve los bytes listos para descargar/compartir.
  static Future<Uint8List> pendientesDeTrabajo({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
  }) async {
    final doc = pw.Document(
      title: 'Pendientes de Trabajo',
      author: 'AmilCar Auto Service',
    );
    final logo = await _cargarLogo();
    final ordenadas = [...ordenes]
      ..sort((a, b) {
        final fa = a.estadoUpdatedAt ?? a.createdAt ?? DateTime(1970);
        final fb = b.estadoUpdatedAt ?? b.createdAt ?? DateTime(1970);
        return fa.compareTo(fb); // más antiguas primero (más urgentes)
      });

    final montoTotal = ordenadas
        .where((o) => o.montoAprobado != null)
        .fold<double>(0, (a, o) => a + o.montoAprobado!);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        header: (ctx) => _encabezado(
          logo: logo,
          titulo: 'Pendientes de Trabajo',
        ),
        footer: _pieDePagina,
        build: (ctx) => [
          _resumen(
            generadoEn: DateTime.now(),
            items: [
              ('Total de órdenes', '${ordenadas.length}'),
              ('Monto aprobado', _fmtMonto(montoTotal)),
            ],
          ),
          pw.SizedBox(height: 14),
          _tablaPendientesTrabajo(
            ordenes: ordenadas,
            clientesById: clientesById,
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Genera el PDF de **Pendientes de Pago**.
  /// Devuelve los bytes listos para descargar/compartir.
  static Future<Uint8List> pendientesDePago({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
    required Map<String, List<Pago>> pagosByOrdenId,
    PdfIdioma idioma = PdfIdioma.es,
  }) async {
    final es = idioma == PdfIdioma.es;
    final doc = pw.Document(
      title: es ? 'Facturas pendientes' : 'Pending invoices',
      author: 'AmilCar Auto Service',
    );
    final logo = await _cargarLogo();
    final ordenadas = [...ordenes]
      ..sort((a, b) {
        final fa = a.estadoUpdatedAt ?? a.createdAt ?? DateTime(1970);
        final fb = b.estadoUpdatedAt ?? b.createdAt ?? DateTime(1970);
        return fa.compareTo(fb); // más antiguas primero
      });

    // Cálculo de totales
    double totalAprobado = 0;
    double totalCobrado = 0;
    for (final o in ordenadas) {
      totalAprobado += o.montoAprobado ?? 0;
      final pagos = pagosByOrdenId[o.id] ?? const <Pago>[];
      for (final p in pagos.where((p) => !p.estaCancelado)) {
        totalCobrado += p.monto;
      }
    }
    final totalRestante = totalAprobado - totalCobrado;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        header: (ctx) => _encabezado(
          logo: logo,
          titulo: es ? 'Facturas pendientes' : 'Pending invoices',
        ),
        footer: _pieDePagina,
        build: (ctx) => [
          _resumen(
            generadoEn: DateTime.now(),
            titulo: es ? 'Resumen' : 'Summary',
            generadoLabel: es ? 'Generado' : 'Generated',
            items: [
              (es ? 'Facturas pendientes' : 'Pending invoices',
                  '${ordenadas.length}'),
              (es ? 'Total de facturas' : 'Total invoices',
                  _fmtMonto(totalAprobado)),
              (es ? 'Pagos recibidos' : 'Payments received',
                  _fmtMonto(totalCobrado)),
              (es ? 'Saldo pendiente' : 'Balance due',
                  _fmtMonto(totalRestante)),
            ],
          ),
          pw.SizedBox(height: 14),
          _tablaPendientesPago(
            ordenes: ordenadas,
            clientesById: clientesById,
            pagosByOrdenId: pagosByOrdenId,
            idioma: idioma,
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Genera el PDF de **En Proceso**.
  /// Devuelve los bytes listos para descargar/compartir.
  static Future<Uint8List> enProceso({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
  }) async {
    final doc = pw.Document(
      title: 'En Proceso',
      author: 'AmilCar Auto Service',
    );
    final logo = await _cargarLogo();
    final ordenadas = [...ordenes]
      ..sort((a, b) {
        final fa = a.estadoUpdatedAt ?? a.createdAt ?? DateTime(1970);
        final fb = b.estadoUpdatedAt ?? b.createdAt ?? DateTime(1970);
        return fa.compareTo(fb); // más antiguas primero
      });

    final montoTotal = ordenadas
        .where((o) => o.montoAprobado != null)
        .fold<double>(0, (a, o) => a + o.montoAprobado!);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        header: (ctx) => _encabezado(
          logo: logo,
          titulo: 'En Proceso',
        ),
        footer: _pieDePagina,
        build: (ctx) => [
          _resumen(
            generadoEn: DateTime.now(),
            items: [
              ('Total de órdenes', '${ordenadas.length}'),
              ('Monto aprobado', _fmtMonto(montoTotal)),
            ],
          ),
          pw.SizedBox(height: 14),
          _tablaPendientesTrabajo(
            ordenes: ordenadas,
            clientesById: clientesById,
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Genera el PDF de **Pendientes de Estimado**.
  /// Devuelve los bytes listos para descargar/compartir.
  static Future<Uint8List> pendientesDeEstimado({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
  }) async {
    final doc = pw.Document(
      title: 'Pendientes de Estimado',
      author: 'AmilCar Auto Service',
    );
    final logo = await _cargarLogo();

    final porHacer = ordenes
        .where((o) => o.estadoKanban == EstadoKanban.porHacer)
        .toList()
      ..sort(_compareAntiguedad);
    final listos = ordenes
        .where((o) => o.estadoKanban == EstadoKanban.listosParaEnviar)
        .toList()
      ..sort(_compareAntiguedad);
    final esperando = ordenes
        .where((o) => o.estadoKanban == EstadoKanban.esperandoAprobacion)
        .toList()
      ..sort(_compareAntiguedad);

    final conCotizacion = ordenes.where((o) => o.pdfsUrls.isNotEmpty).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        header: (ctx) => _encabezado(
          logo: logo,
          titulo: 'Pendientes de Estimado',
        ),
        footer: _pieDePagina,
        build: (ctx) => [
          _resumen(
            generadoEn: DateTime.now(),
            items: [
              ('Total de órdenes', '${ordenes.length}'),
              ('Por hacer', '${porHacer.length}'),
              ('Listos para enviar', '${listos.length}'),
              ('Esperando aprobación', '${esperando.length}'),
              ('Con cotización', '$conCotizacion'),
            ],
          ),
          pw.SizedBox(height: 12),
          _seccionTitulo('Por Hacer', porHacer.length),
          _tablaPendientesEstimado(
            ordenes: porHacer,
            clientesById: clientesById,
          ),
          pw.SizedBox(height: 12),
          _seccionTitulo('Listos para Enviar', listos.length),
          _tablaPendientesEstimado(
            ordenes: listos,
            clientesById: clientesById,
          ),
          pw.SizedBox(height: 12),
          _seccionTitulo('Esperando Aprobación', esperando.length),
          _tablaPendientesEstimado(
            ordenes: esperando,
            clientesById: clientesById,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Encabezado ────────────────────────────────────────────────────────

  static pw.Widget _encabezado({
    required pw.MemoryImage? logo,
    required String titulo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              height: 36,
              width: 36,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AMILCAR',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primario,
                    letterSpacing: 2,
                  ),
                ),
                pw.Text(
                  'Auto Service',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _gris,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            titulo.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _primario,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Resumen ───────────────────────────────────────────────────────────

  static pw.Widget _resumen({
    required DateTime generadoEn,
    required List<(String, String)> items,
    String titulo = 'Resumen',
    String generadoLabel = 'Generado',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grisSuave,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                titulo,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _primario,
                  letterSpacing: 0.6,
                ),
              ),
              pw.Text(
                '$generadoLabel: ${_fmtFechaHora(generadoEn)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _gris,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              for (final (label, valor) in items)
                _itemResumen(label: label, valor: valor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemResumen({
    required String label,
    required String valor,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: 9, color: _gris),
        ),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _texto,
          ),
        ),
      ],
    );
  }

  // ── Tablas ────────────────────────────────────────────────────────────

  static pw.Widget _tablaPendientesTrabajo({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
  }) {
    final headers = ['#', 'Cliente', 'Vehículo', 'Monto', 'Contacto', 'Desde'];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(2.4),
      2: const pw.FlexColumnWidth(2.4),
      3: const pw.FlexColumnWidth(1.4),
      4: const pw.FlexColumnWidth(1.6),
      5: const pw.FlexColumnWidth(1.4),
    };

    return _tablaBase(
      headers: headers,
      widths: widths,
      rows: [
        for (int i = 0; i < ordenes.length; i++)
          [
            '${i + 1}',
            clientesById[ordenes[i].clienteId]?.nombre ?? 'Cliente desconocido',
            ordenes[i].vehiculoResumen,
            ordenes[i].montoAprobado != null
                ? _fmtMonto(ordenes[i].montoAprobado!)
                : '-',
            clientesById[ordenes[i].clienteId]?.telefono ?? '-',
            _fmtFechaCorta(
                ordenes[i].estadoUpdatedAt ?? ordenes[i].createdAt),
          ],
      ],
      alineacionesPorColumna: const {
        0: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
    );
  }

  static pw.Widget _tablaPendientesPago({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
    required Map<String, List<Pago>> pagosByOrdenId,
    required PdfIdioma idioma,
  }) {
    final es = idioma == PdfIdioma.es;
    final headers = [
      '#',
      es ? 'Cliente' : 'Client',
      es ? 'Vehículo' : 'Vehicle',
      es ? 'Total' : 'Total',
      es ? 'Cobrado' : 'Paid',
      es ? 'Restante' : 'Balance',
      es ? 'Desde' : 'Since',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(2.2),
      2: const pw.FlexColumnWidth(2.2),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.2),
      5: const pw.FlexColumnWidth(1.3),
      6: const pw.FlexColumnWidth(1.3),
    };

    // Pre-calcula cobrado/restante por orden, y guarda si está pagado.
    final filas = <List<String>>[];
    final estilosRestante = <pw.TextStyle?>[];
    final clienteDesconocido = es ? 'Cliente desconocido' : 'Unknown client';
    final pagadoLabel = es ? 'Pagado' : 'Paid';
    for (int i = 0; i < ordenes.length; i++) {
      final o = ordenes[i];
      final aprobado = o.montoAprobado ?? 0;
      final pagos = pagosByOrdenId[o.id] ?? const <Pago>[];
      final cobrado = pagos
          .where((p) => !p.estaCancelado)
          .fold<double>(0, (a, p) => a + p.monto);
      final restante = aprobado - cobrado;

      filas.add([
        '${i + 1}',
        clientesById[o.clienteId]?.nombre ?? clienteDesconocido,
        o.vehiculoResumen,
        o.montoAprobado != null ? _fmtMonto(aprobado) : '-',
        cobrado > 0 ? _fmtMonto(cobrado) : '-',
        o.montoAprobado == null
            ? '-'
            : restante <= 0
                ? pagadoLabel
                : _fmtMonto(restante),
        _fmtFechaCorta(o.estadoUpdatedAt ?? o.createdAt),
      ]);

      estilosRestante.add(
        o.montoAprobado == null
            ? null
            : restante <= 0
                ? pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _exito,
                  )
                : pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _alerta,
                  ),
      );
    }

    return _tablaBase(
      headers: headers,
      widths: widths,
      rows: filas,
      alineacionesPorColumna: const {
        0: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
      },
      estilosPorCelda: (rowIndex, colIndex) {
        if (colIndex == 5) return estilosRestante[rowIndex];
        return null;
      },
    );
  }

  static pw.Widget _tablaPendientesEstimado({
    required List<OrdenTrabajo> ordenes,
    required Map<String, Cliente> clientesById,
  }) {
    final headers = [
      '#',
      'Cliente',
      'Vehículo',
      'Contacto',
      'Cots.',
      'Rango',
      'Desde',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(2.2),
      2: const pw.FlexColumnWidth(2.2),
      3: const pw.FlexColumnWidth(1.4),
      4: const pw.FlexColumnWidth(1.0),
      5: const pw.FlexColumnWidth(1.6),
      6: const pw.FlexColumnWidth(1.2),
    };

    return _tablaBase(
      headers: headers,
      widths: widths,
      rows: [
        for (int i = 0; i < ordenes.length; i++)
          [
            '${i + 1}',
            clientesById[ordenes[i].clienteId]?.nombre ?? 'Cliente desconocido',
            ordenes[i].vehiculoResumen,
            clientesById[ordenes[i].clienteId]?.telefono ?? '-',
            ordenes[i].pdfsUrls.isEmpty
                ? '-'
                : '${ordenes[i].pdfsUrls.length}',
            _fmtRangoCotizaciones(ordenes[i].pdfsUrls),
            _fmtFechaCorta(
                ordenes[i].estadoUpdatedAt ?? ordenes[i].createdAt),
          ],
      ],
      alineacionesPorColumna: const {
        0: pw.Alignment.centerRight,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
      },
    );
  }

  /// Tabla genérica con header pintado, filas alternadas y bordes sutiles.
  static pw.Widget _tablaBase({
    required List<String> headers,
    required Map<int, pw.TableColumnWidth> widths,
    required List<List<String>> rows,
    Map<int, pw.Alignment>? alineacionesPorColumna,
    pw.TextStyle? Function(int rowIndex, int colIndex)? estilosPorCelda,
  }) {
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder(
        horizontalInside:
            pw.BorderSide(color: _borde, width: 0.4),
        bottom: pw.BorderSide(color: _borde, width: 0.4),
      ),
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: _primario,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          children: [
            for (int i = 0; i < headers.length; i++)
              _celda(
                texto: headers[i].toUpperCase(),
                alignment:
                    alineacionesPorColumna?[i] ?? pw.Alignment.centerLeft,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.6,
                ),
                paddingVertical: 7,
              ),
          ],
        ),
        // Filas
        for (int r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? _grisSuave : PdfColors.white,
            ),
            children: [
              for (int c = 0; c < rows[r].length; c++)
                _celda(
                  texto: rows[r][c],
                  alignment: alineacionesPorColumna?[c] ??
                      pw.Alignment.centerLeft,
                  style: estilosPorCelda?.call(r, c) ??
                      pw.TextStyle(
                        fontSize: 9,
                        color: _texto,
                      ),
                  paddingVertical: 6,
                ),
            ],
          ),
        if (rows.isEmpty)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(14),
                child: pw.Text(
                  'Sin órdenes en esta sección.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _gris,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              for (int i = 1; i < headers.length; i++) pw.SizedBox(),
            ],
          ),
      ],
    );
  }

  static pw.Widget _celda({
    required String texto,
    required pw.Alignment alignment,
    required pw.TextStyle style,
    double paddingVertical = 6,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: paddingVertical,
      ),
      child: pw.Text(
        texto,
        style: style,
        textAlign: switch (alignment) {
          pw.Alignment.centerRight => pw.TextAlign.right,
          pw.Alignment.center => pw.TextAlign.center,
          _ => pw.TextAlign.left,
        },
      ),
    );
  }

  // ── Pie de página ─────────────────────────────────────────────────────

  static pw.Widget _pieDePagina(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borde, width: 0.4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'AmilCar Auto Service',
            style: pw.TextStyle(fontSize: 8, color: _gris),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _gris),
          ),
        ],
      ),
    );
  }

  // ── Helpers de formato ────────────────────────────────────────────────

  static String _fmtMonto(double monto) {
    final entero = monto.round();
    final texto = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${AppConfig.currencySymbol}$texto';
  }

  static String _fmtFechaCorta(DateTime? fecha) {
    if (fecha == null) return '-';
    final d = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  static String _fmtFechaHora(DateTime fecha) {
    final d = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  static int _compareAntiguedad(OrdenTrabajo a, OrdenTrabajo b) {
    final fa = a.estadoUpdatedAt ?? a.createdAt ?? DateTime(1970);
    final fb = b.estadoUpdatedAt ?? b.createdAt ?? DateTime(1970);
    return fa.compareTo(fb);
  }

  static String _fmtRangoCotizaciones(List<PdfCotizacion> cotizaciones) {
    if (cotizaciones.isEmpty) return '-';
    var min = cotizaciones.first.montoSugerido;
    var max = cotizaciones.first.montoSugerido;
    for (final c in cotizaciones.skip(1)) {
      if (c.montoSugerido < min) min = c.montoSugerido;
      if (c.montoSugerido > max) max = c.montoSugerido;
    }
    if (min == max) return _fmtMonto(min);
    return '${_fmtMonto(min)} - ${_fmtMonto(max)}';
  }

  static pw.Widget _seccionTitulo(String titulo, int total) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _primario,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _primarioSuave,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              '$total',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _primario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────

  /// Carga el logo desde los assets. Si falla, devuelve null y el header
  /// se renderiza sin imagen (el PDF sigue funcionando).
  static Future<pw.MemoryImage?> _cargarLogo() async {
    try {
      final data = await rootBundle.load('assets/branding/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
