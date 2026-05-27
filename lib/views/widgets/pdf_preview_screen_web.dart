// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pantalla de preview de PDF para WEB.
///
/// En vez de usar `PdfPreview` (que depende de pdf.js y a veces falla con
/// "Unable to display the document"), embebemos un `<iframe>` con un Blob
/// URL. El visor PDF nativo del navegador (Chrome / Edge / Firefox) se
/// encarga de renderizar — más rápido, más confiable, con sus propios
/// botones de zoom, búsqueda, descargar e imprimir.
///
/// El spinner permanece visible hasta que el `iframe` dispara `load`,
/// para evitar mostrar un área blanca mientras el navegador parsea el PDF.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.buildBytes,
  });

  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function() buildBytes;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _objectUrl;
  String? _viewType;
  Uint8List? _bytes;
  bool _iframeLoaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generar();
  }

  Future<void> _generar() async {
    try {
      final bytes = await widget.buildBytes();
      if (!mounted) return;

      // Crea un blob PDF y obtenemos una URL local.
      final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Registra una factory única para el HtmlElementView de este preview.
      final viewType =
          'pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
        // Cuando el navegador termine de parsear el PDF, oculta el spinner.
        iframe.onLoad.listen((_) {
          if (mounted) setState(() => _iframeLoaded = true);
        });
        return iframe;
      });

      setState(() {
        _bytes = bytes;
        _objectUrl = url;
        _viewType = viewType;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    // Libera memoria del blob.
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
    }
    super.dispose();
  }

  void _descargar() {
    final bytes = _bytes;
    if (bytes == null) return;
    final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', widget.nombreArchivo)
      ..click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text(widget.titulo),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Descargar',
            onPressed: _bytes == null ? null : _descargar,
          ),
        ],
      ),
      body: _error != null ? _vistaError() : _vistaPreview(),
    );
  }

  /// Stack: el iframe (cuando ya hay viewType) + spinner overlay encima
  /// hasta que el iframe haya cargado.
  Widget _vistaPreview() {
    return Stack(
      children: [
        if (_viewType != null)
          Positioned.fill(child: HtmlElementView(viewType: _viewType!)),
        if (!_iframeLoaded)
          const Positioned.fill(
            child: ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Generando reporte…'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vistaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'No se pudo generar el PDF',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('$_error', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
