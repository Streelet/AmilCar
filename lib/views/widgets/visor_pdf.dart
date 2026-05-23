import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Fondo oscuro del visor, cómodo para leer documentos.
const Color _fondoVisor = Color(0xFF2A2B2F);

/// Origen de un PDF a mostrar en el visor.
class PdfRef {
  const PdfRef({required this.titulo, required this.url, this.bytes});

  /// Etiqueta visible (título de la cotización).
  final String titulo;

  /// URL http del PDF, o nombre de archivo (datos de demostración).
  final String url;

  /// Bytes del PDF, si se subió en esta sesión.
  final Uint8List? bytes;
}

/// Abre el visor de PDF a pantalla completa, con zoom y desplazamiento.
Future<void> mostrarVisorPdf(BuildContext context, PdfRef pdf) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _VisorPdf(pdf: pdf),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _VisorPdf extends StatelessWidget {
  const _VisorPdf({required this.pdf});

  final PdfRef pdf;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoVisor,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior: volver + título.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      pdf.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white70, size: 22),
                ],
              ),
            ),
            Expanded(child: _visor()),
          ],
        ),
      ),
    );
  }

  Widget _visor() {
    final params = PdfViewerParams(
      backgroundColor: _fondoVisor,
      loadingBannerBuilder: (context, downloaded, total) => const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.6),
        ),
      ),
      errorBannerBuilder: (context, error, stackTrace, documentRef) =>
          const _ErrorPdf(),
    );

    // PDF subido en esta sesión: se muestra de verdad desde memoria.
    if (pdf.bytes != null) {
      return PdfViewer.data(pdf.bytes!, sourceName: pdf.url, params: params);
    }
    // PDF real alojado en la nube (modo Supabase).
    if (pdf.url.startsWith('http')) {
      return PdfViewer.uri(Uri.parse(pdf.url), params: params);
    }
    // Datos de demostración: PDF de ejemplo incluido en la app.
    return PdfViewer.asset('assets/sample/estimado_demo.pdf', params: params);
  }
}

class _ErrorPdf extends StatelessWidget {
  const _ErrorPdf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white.withValues(alpha: 0.7), size: 52),
            const SizedBox(height: 14),
            const Text(
              'No se pudo abrir el PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Revisa tu conexión e inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
