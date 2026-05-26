/// Cliente del taller. Entidad normalizada: un mismo cliente puede aparecer
/// referenciado por múltiples [OrdenTrabajo]s a través de `clienteId`.
///
/// Solo guarda información de contacto. El vehículo NO vive aquí: cada
/// orden registra el auto sobre el que se trabajó esa vez.
class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.telefono,
    this.direccion,
    this.email,
    this.createdAt,
    this.deletedAt,
  });

  /// UUID. En Supabase coincide con `clientes.id`.
  final String id;

  /// Nombre para mostrar (requerido).
  final String nombre;

  final String? telefono;
  final String? direccion;
  final String? email;

  final DateTime? createdAt;

  /// Marca de soft delete. `null` = activo. Cuando tiene valor, el cliente
  /// queda oculto de todas las queries (RLS lo filtra en Supabase; los
  /// repos lo filtran en mock).
  final DateTime? deletedAt;

  /// Iniciales de respaldo cuando no haya foto de cliente (avatar fallback).
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as String,
      nombre: (json['nombre'] ?? '') as String,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
    );
  }

  /// Nota: `deleted_at` NO se incluye en toJson. El soft delete se aplica
  /// vía una operación dedicada del repositorio que sólo actualiza esa
  /// columna; un upsert con la fila completa no debe re-activar/desactivar
  /// el cliente por accidente.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'direccion': direccion,
        'email': email,
      };

  Cliente copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? direccion,
    String? email,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
