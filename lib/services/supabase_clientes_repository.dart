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
        .map((rows) => rows.map(Cliente.fromJson).toList());
  }

  @override
  Future<void> upsertCliente(Cliente cliente) async {
    await _client.from(_tabla).upsert(cliente.toJson());
  }

  @override
  void dispose() {
    // El SDK de Supabase administra el ciclo de vida del canal realtime.
  }
}
