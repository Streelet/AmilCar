import '../config/app_config.dart';
import 'pdf_cotizacion.dart';

/// Estado de un [Estimado] dentro del flujo de negocio completo.
///
/// Los 3 primeros valores son las **columnas del Kanban** de la pestaña
/// "Pendientes de Estimado". Los demás corresponden a las otras pestañas
/// superiores del dashboard. El campo `estado_kanban` de Supabase guarda
/// el [dbValue].
enum EstadoKanban {
  // --- Pestaña 0: Pendientes de Estimado (Kanban de 3 columnas) ---
  porHacer('por_hacer', 'Por Hacer', 0),
  listosParaEnviar('listos_para_enviar', 'Listos para Enviar', 0),
  esperandoAprobacion('esperando_aprobacion', 'Esperando Aprobación', 0),

  // --- Pestañas siguientes ---
  pendienteTrabajo('pendiente_trabajo', 'Pendientes de Trabajo', 1),
  enProceso('en_proceso', 'En Proceso', 2),
  pendientePago('pendiente_pago', 'Pendiente de Pago', 3);

  const EstadoKanban(this.dbValue, this.label, this.tabIndex);

  /// Valor guardado en la columna `estado_kanban`.
  final String dbValue;

  /// Etiqueta legible.
  final String label;

  /// Pestaña superior del dashboard a la que pertenece este estado.
  final int tabIndex;

  /// `true` si es una de las 3 columnas del Kanban de "Pendientes de Estimado".
  bool get esColumnaEstimado => tabIndex == 0;

  static EstadoKanban fromDb(String? value) {
    return EstadoKanban.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => EstadoKanban.porHacer,
    );
  }

  /// Columnas del tablero Kanban, en orden de izquierda a derecha.
  static const List<EstadoKanban> columnasKanban = [
    EstadoKanban.porHacer,
    EstadoKanban.listosParaEnviar,
    EstadoKanban.esperandoAprobacion,
  ];
}

/// Modelo relacional principal: una orden de servicio / estimado.
///
/// Inmutable: las mutaciones (drag&drop, aprobación, archivado) se hacen con
/// [copyWith] y se persisten vía el repositorio correspondiente.
class Estimado {
  const Estimado({
    required this.id,
    required this.clienteNombre,
    this.telefono,
    this.direccion,
    this.vehiculoMarca,
    this.vehiculoModelo,
    this.vehiculoAnio,
    this.vehiculoVin,
    this.fotosUrls = const [],
    this.pdfsUrls = const [],
    this.montoAprobado,
    this.estadoKanban = EstadoKanban.porHacer,
    this.archivado = false,
    this.createdAt,
  });

  /// UUID.
  final String id;

  /// Nombre del cliente (requerido).
  final String clienteNombre;

  final String? telefono;

  /// Dirección / geolocalización del auxilio vial.
  final String? direccion;

  final String? vehiculoMarca;
  final String? vehiculoModelo;
  final int? vehiculoAnio;
  final String? vehiculoVin;

  /// Fotografías del vehículo.
  final List<String> fotosUrls;

  /// Cotizaciones agrupadas (título + url + monto sugerido).
  final List<PdfCotizacion> pdfsUrls;

  /// Monto que el cliente aprobó. Nulo hasta el cierre del trato.
  final double? montoAprobado;

  /// Estado dentro del flujo de negocio.
  final EstadoKanban estadoKanban;

  /// Si está archivado deja de mostrarse en el tablero activo.
  final bool archivado;

  final DateTime? createdAt;

  /// Descripción corta del vehículo para la tarjeta, ej. "Toyota Hilux 2021".
  String get vehiculoResumen {
    final partes = [
      vehiculoMarca,
      vehiculoModelo,
      vehiculoAnio?.toString(),
    ].where((p) => p != null && p.isNotEmpty).toList();
    return partes.isEmpty ? 'Vehículo sin especificar' : partes.join(' ');
  }

  /// Monto aprobado formateado, ej. "Q5,000". Vacío si aún no se aprueba.
  String get montoAprobadoFormateado {
    if (montoAprobado == null) return '';
    final entero = montoAprobado!.round();
    final texto = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${AppConfig.currencySymbol}$texto';
  }

  factory Estimado.fromJson(Map<String, dynamic> json) {
    return Estimado(
      id: json['id'] as String,
      clienteNombre: (json['cliente_nombre'] ?? '') as String,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      vehiculoMarca: json['vehiculo_marca'] as String?,
      vehiculoModelo: json['vehiculo_modelo'] as String?,
      vehiculoAnio: (json['vehiculo_anio'] as num?)?.toInt(),
      vehiculoVin: json['vehiculo_vin'] as String?,
      fotosUrls: _stringList(json['fotos_urls']),
      pdfsUrls: _pdfList(json['pdfs_urls']),
      montoAprobado: (json['monto_aprobado'] as num?)?.toDouble(),
      estadoKanban: EstadoKanban.fromDb(json['estado_kanban'] as String?),
      archivado: (json['archivado'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_nombre': clienteNombre,
        'telefono': telefono,
        'direccion': direccion,
        'vehiculo_marca': vehiculoMarca,
        'vehiculo_modelo': vehiculoModelo,
        'vehiculo_anio': vehiculoAnio,
        'vehiculo_vin': vehiculoVin,
        'fotos_urls': fotosUrls,
        'pdfs_urls': pdfsUrls.map((p) => p.toJson()).toList(),
        'monto_aprobado': montoAprobado,
        'estado_kanban': estadoKanban.dbValue,
        'archivado': archivado,
      };

  Estimado copyWith({
    String? id,
    String? clienteNombre,
    String? telefono,
    String? direccion,
    String? vehiculoMarca,
    String? vehiculoModelo,
    int? vehiculoAnio,
    String? vehiculoVin,
    List<String>? fotosUrls,
    List<PdfCotizacion>? pdfsUrls,
    double? montoAprobado,
    EstadoKanban? estadoKanban,
    bool? archivado,
    DateTime? createdAt,
  }) {
    return Estimado(
      id: id ?? this.id,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      vehiculoMarca: vehiculoMarca ?? this.vehiculoMarca,
      vehiculoModelo: vehiculoModelo ?? this.vehiculoModelo,
      vehiculoAnio: vehiculoAnio ?? this.vehiculoAnio,
      vehiculoVin: vehiculoVin ?? this.vehiculoVin,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      pdfsUrls: pdfsUrls ?? this.pdfsUrls,
      montoAprobado: montoAprobado ?? this.montoAprobado,
      estadoKanban: estadoKanban ?? this.estadoKanban,
      archivado: archivado ?? this.archivado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static List<PdfCotizacion> _pdfList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PdfCotizacion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
