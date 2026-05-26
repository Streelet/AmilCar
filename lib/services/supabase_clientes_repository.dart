import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';
import 'clientes_repository.dart';

/// Implementación de [ClientesRepository] para el MODO SUPABASE.
///
/// Usa el Stream/WebSocket nativo de Supabase sobre la tabla `clientes`
/// para sincronizar el directorio en tiempo real entre la tablet del
/// asesor y la PC del admin.
class SupabaseClientesRepository implements ClientesRepository {
  static const String _tabla = 'clientes';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<Cliente>> watchClientes() {
    return _client
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .order('nombre')
        .map((rows) => rows
            .map(Cliente.fromJson)
            // Filtro defensivo: las políticas RLS ya excluyen los soft
            // deleted, pero el canal realtime puede re-emitir un UPDATE
            // de una fila recién borrada sin sacarla del cache local.
            .where((c) => c.deletedAt == null)
            .toList());
  }

  @override
  Future<void> upsertCliente(Cliente cliente) async {
    await _client.from(_tabla).upsert(cliente.toJson());
  }

  @override
  Future<void> softDeleteCliente(String id) async {
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
