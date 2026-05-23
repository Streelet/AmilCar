import '../config/app_config.dart';

/// Una cotización individual dentro de una [OrdenTrabajo].
///
/// En Supabase se guarda como objeto JSON dentro del arreglo `pdfs_urls`,
/// agrupando: título, url del PDF y monto sugerido.
class PdfCotizacion {
  const PdfCotizacion({
    required this.titulo,
    required this.url,
    required this.montoSugerido,
  });

  /// Etiqueta visible, ej. "OEM" o "Aftermarket".
  final String titulo;

  /// Ruta/URL del PDF de la cotización (Supabase Storage o externa).
  final String url;

  /// Precio sugerido de esta opción.
  final double montoSugerido;

  /// Precio formateado para la UI, ej. "Q5,000".
  String get montoFormateado {
    final entero = montoSugerido.round();
    final texto = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${AppConfig.currencySymbol}$texto';
  }

  factory PdfCotizacion.fromJson(Map<String, dynamic> json) {
    return PdfCotizacion(
      titulo: (json['titulo'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      montoSugerido: (json['monto_sugerido'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'url': url,
        'monto_sugerido': montoSugerido,
      };

  PdfCotizacion copyWith({
    String? titulo,
    String? url,
    double? montoSugerido,
  }) {
    return PdfCotizacion(
      titulo: titulo ?? this.titulo,
      url: url ?? this.url,
      montoSugerido: montoSugerido ?? this.montoSugerido,
    );
  }
}
