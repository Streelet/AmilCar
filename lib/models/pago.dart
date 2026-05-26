import '../config/app_config.dart';
import 'metodo_pago.dart';
import 'nota.dart';

/// Un pago / anticipo registrado contra una [OrdenTrabajo].
///
/// Entidad normalizada: cada orden puede tener N pagos. La suma de
/// `monto` contra `OrdenTrabajo.montoAprobado` da el "restante" a cobrar.
///
/// Cada pago lleva un [metodoPago] obligatorio. Si vale [MetodoPago.otro],
/// el detalle queda en [metodoPagoOtro] (texto libre).
///
/// Las [notas] reutilizan el modelo [Nota] (texto + fecha) para mantener
/// el patrón consistente con el resto del dominio.
class Pago {
  const Pago({
    required this.id,
    required this.ordenId,
    required this.monto,
    required this.fecha,
    required this.metodoPago,
    this.metodoPagoOtro,
    this.notas = const [],
    this.createdAt,
    this.deletedAt,
    this.canceladoAt,
    this.motivoCancelacion,
  });

  final String id;
  final String ordenId;
  final double monto;
  final DateTime fecha;

  /// Forma de pago (efectivo, cheque, tarjetas, zelle u "otro").
  final MetodoPago metodoPago;

  /// Detalle libre cuando [metodoPago] == [MetodoPago.otro]. Null en
  /// cualquier otro caso.
  final String? metodoPagoOtro;

  final List<Nota> notas;
  final DateTime? createdAt;

  /// Marca de soft delete (oculta la fila). Usada sólo por SQL admin —
  /// la UI usa `canceladoAt` en su lugar para preservar el historial.
  final DateTime? deletedAt;

  /// Marca de cancelación: la fila sigue visible en la UI pero tachada,
  /// y NO cuenta para el saldo. `null` = pago activo.
  final DateTime? canceladoAt;

  /// Razón por la cual se canceló el pago. Obligatoria cuando
  /// [canceladoAt] tiene valor.
  final String? motivoCancelacion;

  /// `true` si el pago fue cancelado (no debe contar para totales).
  bool get estaCancelado => canceladoAt != null;

  /// Etiqueta a mostrar: el label del método; si es "Otro" muestra
  /// el detalle libre (ej. "Otro · Transferencia BAC").
  String get metodoPagoLabel {
    if (metodoPago == MetodoPago.otro) {
      final detalle = metodoPagoOtro?.trim();
      if (detalle != null && detalle.isNotEmpty) {
        return 'Otro · $detalle';
      }
      return 'Otro';
    }
    return metodoPago.label;
  }

  /// Monto formateado, ej. "$1,200".
  String get montoFormateado {
    final entero = monto.round();
    final texto = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${AppConfig.currencySymbol}$texto';
  }

  /// Fecha legible corta, ej. "21/05/2026".
  String get fechaFormateada {
    final d = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      id: json['id'] as String,
      ordenId: json['orden_id'] as String,
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
      metodoPago: MetodoPago.fromDb(json['metodo_pago'] as String?),
      metodoPagoOtro: json['metodo_pago_otro'] as String?,
      notas: _notaList(json['notas']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      canceladoAt: json['cancelado_at'] != null
          ? DateTime.tryParse(json['cancelado_at'].toString())
          : null,
      motivoCancelacion: json['motivo_cancelacion'] as String?,
    );
  }

  /// Nota: `deleted_at`, `cancelado_at` y `motivo_cancelacion` NO se
  /// incluyen en toJson. Soft delete y cancelación se aplican vía
  /// operaciones dedicadas del repositorio.
  Map<String, dynamic> toJson() => {
        'id': id,
        'orden_id': ordenId,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'metodo_pago': metodoPago.dbValue,
        'metodo_pago_otro': metodoPago == MetodoPago.otro
            ? (metodoPagoOtro?.trim().isEmpty ?? true
                ? null
                : metodoPagoOtro!.trim())
            : null,
        'notas': notas.map((n) => n.toJson()).toList(),
      };

  Pago copyWith({
    String? id,
    String? ordenId,
    double? monto,
    DateTime? fecha,
    MetodoPago? metodoPago,
    String? metodoPagoOtro,
    List<Nota>? notas,
    DateTime? createdAt,
    DateTime? deletedAt,
    DateTime? canceladoAt,
    String? motivoCancelacion,
  }) {
    return Pago(
      id: id ?? this.id,
      ordenId: ordenId ?? this.ordenId,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      metodoPago: metodoPago ?? this.metodoPago,
      metodoPagoOtro: metodoPagoOtro ?? this.metodoPagoOtro,
      notas: notas ?? this.notas,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      canceladoAt: canceladoAt ?? this.canceladoAt,
      motivoCancelacion: motivoCancelacion ?? this.motivoCancelacion,
    );
  }

  static List<Nota> _notaList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Nota.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
