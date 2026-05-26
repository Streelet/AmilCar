import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pago.dart';
import 'pagos_repository.dart';

/// Implementación de [PagosRepository] para el MODO SUPABASE.
///
/// Las políticas RLS filtran soft-deleted; aquí no hace falta filtrar
/// nada extra. El stream realtime se actualiza solo al hacer
/// `update deleted_at = now()`.
class SupabasePagosRepository implements PagosRepository {
  static const String _tabla = 'pagos';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<Pago>> watchPagos() {
    return _client
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .order('fecha', ascending: false)
        .map((rows) => rows
            .map(Pago.fromJson)
            // Filtro defensivo: las políticas RLS ya excluyen los soft
            // deleted en el SELECT inicial, pero el canal realtime puede
            // re-emitir un UPDATE de una fila que pasó a estar borrada
            // sin "des-suscribirla" del lado del cliente. Filtrar acá
            // garantiza que la UI nunca vea un soft-deleted.
            .where((p) => p.deletedAt == null)
            .toList());
  }

  @override
  Future<void> upsertPago(Pago pago) async {
    await _client.from(_tabla).upsert(pago.toJson());
  }

  @override
  Future<void> cancelarPago(String id, String motivo) async {
    await _client.from(_tabla).update({
      'cancelado_at': DateTime.now().toUtc().toIso8601String(),
      'motivo_cancelacion': motivo,
    }).eq('id', id);
  }

  @override
  Future<void> softDeletePago(String id) async {
    await _client
        .from(_tabla)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  void dispose() {
    // El SDK de Supabase administra el ciclo de vida del canal realtime.
  }
}
