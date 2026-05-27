import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';

/// Pantalla de preview de PDF para móvil y escritorio.
///
/// Usa `PdfPreview` del paquete `printing` que entrega visor + zoom +
/// imprimir + compartir integrados, render nativo (pdfium).
class PdfPreviewScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(titulo),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: PdfPreview(
        build: (_) => buildBytes(),
        pdfFileName: nombreArchivo,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: AppColors.primary,
          iconColor: AppColors.onPrimary,
          textStyle: TextStyle(color: AppColors.onPrimary),
        ),
        loadingWidget: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
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
    );
  }
}
