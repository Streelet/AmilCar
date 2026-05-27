import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import '../utils/platform_info.dart';
import 'audit_repository.dart';

/// Implementación de [AuditRepository] que persiste en Supabase.
///
/// Tabla esperada: `public.audit_log` (ver `supabase/schema.sql`).
///
/// Política INSERT: cualquier usuario autenticado puede insertar su propio
/// registro (with check usuario_id = auth.uid() o usuario_id IS NULL).
/// Política SELECT: solo admin puede leer todos los registros.
class SupabaseAuditRepository implements AuditRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> registrar({
    required AuditAccion accion,
    String? entidad,
    String? entidadId,
    Map<String, dynamic>? datos,
    String? usuarioId,
    String? usuarioEmail,
  }) async {
    try {
      await _client.from('audit_log').insert({
        'usuario_id': usuarioId,
        'usuario_email': usuarioEmail,
        'accion': accion.codigo,
        'entidad': entidad,
        'entidad_id': entidadId,
        'datos': datos,
        'plataforma': currentPlatform(),
      });
    } catch (e) {
      // Los errores de log nunca deben romper la app.
      // Solo se muestran en modo debug para no contaminar release.
      debugPrint('[AUDIT] Error al registrar ($accion): $e');
    }
  }

  @override
  Stream<List<AuditEntry>> watchLogs({int limite = 300}) {
    return _client
        .from('audit_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limite)
        .map((rows) => rows.map(AuditEntry.fromJson).toList());
  }

  @override
  void dispose() {
    // Supabase gestiona el ciclo de vida del cliente internamente.
  }
}
