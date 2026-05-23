/// Rol del usuario dentro del sistema. Modula accesos e interfaz en vivo.
///
/// - [admin]  : gestiona órdenes / finanzas a distancia desde la PC.
/// - [asesor] : técnico en campo (otro país) atendiendo vehículos con tablet.
enum UserRole {
  admin('admin', 'Administrador'),
  asesor('asesor', 'Asesor de campo');

  const UserRole(this.dbValue, this.label);

  /// Valor exacto almacenado en la columna `rol` de la tabla `perfiles`.
  final String dbValue;

  /// Etiqueta legible para la interfaz.
  final String label;

  static UserRole fromDb(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.dbValue == value,
      orElse: () => UserRole.asesor, // por defecto, el rol con menos accesos
    );
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isAsesor => this == UserRole.asesor;
}

/// Perfil del usuario autenticado. Se obtiene de la tabla relacional
/// `perfiles` tras un login correcto y se guarda en el estado global.
class Perfil {
  const Perfil({
    required this.id,
    required this.rol,
    required this.nombre,
    this.email,
    this.fotoUrl,
  });

  /// UUID del usuario (coincide con `auth.users.id` de Supabase).
  final String id;

  /// Rol que controla accesos e interfaz.
  final UserRole rol;

  /// Nombre para mostrar.
  final String nombre;

  /// Correo del usuario (informativo, para la pantalla de perfil).
  final String? email;

  /// URL opcional de la foto de perfil para el avatar circular.
  final String? fotoUrl;

  /// Iniciales de respaldo cuando no hay [fotoUrl].
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      rol: UserRole.fromDb(json['rol'] as String?),
      nombre: (json['nombre'] ?? 'Sin nombre') as String,
      email: json['email'] as String?,
      fotoUrl: json['foto_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rol': rol.dbValue,
        'nombre': nombre,
        'email': email,
        'foto_url': fotoUrl,
      };

  Perfil copyWith({
    String? id,
    UserRole? rol,
    String? nombre,
    String? email,
    String? fotoUrl,
  }) {
    return Perfil(
      id: id ?? this.id,
      rol: rol ?? this.rol,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}
