/// ─────────────────────────────────────────────────────────────────────────
///  Modelo de auditoría
///
///  Registra cada acción relevante que un usuario realiza en la aplicación:
///  login, cambios de estado, pagos, archivos… El campo [datos] es un mapa
///  libre para guardar contexto adicional (nombre del vehículo, montos, etc.).
/// ─────────────────────────────────────────────────────────────────────────

/// Categorías de acciones auditables.
enum AuditAccion {
  // ── Auth ──────────────────────────────────────────────────────────────
  login('login', 'Inicio de sesión', AuditCategoria.auth),
  logout('logout', 'Cierre de sesión', AuditCategoria.auth),

  // ── Órdenes de trabajo ────────────────────────────────────────────────
  crearOrden('crear_orden', 'Nueva orden', AuditCategoria.ordenes),
  editarOrden('editar_orden', 'Orden editada', AuditCategoria.ordenes),
  moverOrden('mover_orden', 'Estado cambiado', AuditCategoria.ordenes),
  archivarOrden('archivar_orden', 'Orden archivada', AuditCategoria.ordenes),
  restaurarOrden(
      'restaurar_orden', 'Orden restaurada', AuditCategoria.ordenes),
  eliminarOrden('eliminar_orden', 'Orden eliminada', AuditCategoria.ordenes),

  // ── Clientes ──────────────────────────────────────────────────────────
  crearCliente('crear_cliente', 'Cliente creado', AuditCategoria.clientes),
  editarCliente('editar_cliente', 'Cliente editado', AuditCategoria.clientes),
  eliminarCliente(
      'eliminar_cliente', 'Cliente eliminado', AuditCategoria.clientes),

  // ── Pagos ─────────────────────────────────────────────────────────────
  registrarPago(
      'registrar_pago', 'Pago registrado', AuditCategoria.pagos),
  editarPago('editar_pago', 'Pago editado', AuditCategoria.pagos),
  cancelarPago('cancelar_pago', 'Pago cancelado', AuditCategoria.pagos),

  // ── Archivos ──────────────────────────────────────────────────────────
  subirFoto('subir_foto', 'Foto subida', AuditCategoria.archivos),
  subirPdf('subir_pdf', 'PDF subido', AuditCategoria.archivos);

  const AuditAccion(this.codigo, this.label, this.categoria);

  /// Valor guardado en la columna `accion` de `audit_log`.
  final String codigo;

  /// Texto legible para mostrar en la UI.
  final String label;

  /// Agrupación para los filtros de la pantalla de actividad.
  final AuditCategoria categoria;

  static AuditAccion? fromCodigo(String? codigo) {
    if (codigo == null) return null;
    for (final v in values) {
      if (v.codigo == codigo) return v;
    }
    return null;
  }
}

/// Agrupación de acciones para filtros y chips de color en la UI.
enum AuditCategoria {
  auth('Auth'),
  ordenes('Órdenes'),
  clientes('Clientes'),
  pagos('Pagos'),
  archivos('Archivos');

  const AuditCategoria(this.label);
  final String label;
}

/// Una entrada del registro de auditoría.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.createdAt,
    this.usuarioId,
    this.usuarioEmail,
    required this.accion,
    this.entidad,
    this.entidadId,
    this.datos,
    this.plataforma,
  });

  final String id;
  final DateTime createdAt;

  /// UUID del usuario autenticado. Puede ser nulo para acciones anónimas.
  final String? usuarioId;
  final String? usuarioEmail;

  final AuditAccion accion;

  /// Nombre de la tabla relacionada: `'orden_trabajo'`, `'cliente'`, `'pago'`.
  final String? entidad;

  /// UUID de la fila afectada.
  final String? entidadId;

  /// Contexto adicional en formato libre (vehículo, montos, destino, etc.).
  final Map<String, dynamic>? datos;

  /// Plataforma desde la que se realizó la acción: android, ios, web, windows…
  final String? plataforma;

  // ── Helpers de presentación ──────────────────────────────────────────

  /// Fecha formateada: "26/05/2026 14:32".
  String get fechaFormateada {
    final d = createdAt.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  /// Descripción corta del [datos] para mostrar en tabla.
  /// Omite claves con valores nulos o vacíos.
  String get datosResumen {
    if (datos == null || datos!.isEmpty) return '—';
    return datos!.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');
  }

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      usuarioId: json['usuario_id'] as String?,
      usuarioEmail: json['usuario_email'] as String?,
      accion: AuditAccion.fromCodigo(json['accion'] as String?) ??
          AuditAccion.login,
      entidad: json['entidad'] as String?,
      entidadId: json['entidad_id'] as String?,
      datos: json['datos'] != null
          ? Map<String, dynamic>.from(json['datos'] as Map)
          : null,
      plataforma: json['plataforma'] as String?,
    );
  }
}
