import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estimado.dart';
import 'estimados_repository.dart';

/// Implementación de [EstimadosRepository] para el MODO SUPABASE.
///
/// Usa Streams/WebSockets nativos de Supabase (`.stream()`) para sincronizar
/// el tablero en tiempo real entre la tablet del asesor y la PC del admin.
class SupabaseEstimadosRepository implements EstimadosRepository {
  static const String _tabla = 'estimados';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<Estimado>> watchEstimados() {
    return _client
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(Estimado.fromJson).toList());
  }

  @override
  Future<void> updateEstado(String id, EstadoKanban nuevoEstado) async {
    await _client
        .from(_tabla)
        .update({'estado_kanban': nuevoEstado.dbValue}).eq('id', id);
  }

  @override
  Future<void> aprobarEstimado({
    required String id,
    required double montoAprobado,
    required EstadoKanban nuevoEstado,
  }) async {
    await _client.from(_tabla).update({
      'monto_aprobado': montoAprobado,
      'estado_kanban': nuevoEstado.dbValue,
    }).eq('id', id);
  }

  @override
  Future<void> setArchivado(String id, bool archivado) async {
    await _client
        .from(_tabla)
        .update({'archivado': archivado}).eq('id', id);
  }

  @override
  Future<void> upsertEstimado(Estimado estimado) async {
    await _client.from(_tabla).upsert(estimado.toJson());
  }

  @override
  void dispose() {
    // El SDK de Supabase administra el ciclo de vida del canal realtime.
  }
}
