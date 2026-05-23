/// Una nota libre dentro de una [OrdenTrabajo].
///
/// Sirve para registrar detalles del trabajo: observaciones del cliente,
/// recordatorios, pendientes, etc. En Supabase se guarda como objeto JSON
/// dentro del arreglo `notas`.
class Nota {
  const Nota({required this.texto, required this.fecha});

  /// Contenido de la nota.
  final String texto;

  /// Momento en que se creó la nota.
  final DateTime fecha;

  /// Fecha legible para la UI, ej. "21/05/2026 14:30".
  String get fechaFormateada {
    final d = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} '
        '${dos(d.hour)}:${dos(d.minute)}';
  }

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      texto: (json['texto'] ?? '') as String,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'texto': texto,
        'fecha': fecha.toIso8601String(),
      };

  Nota copyWith({String? texto, DateTime? fecha}) {
    return Nota(
      texto: texto ?? this.texto,
      fecha: fecha ?? this.fecha,
    );
  }
}
