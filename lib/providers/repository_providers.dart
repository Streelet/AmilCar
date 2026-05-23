import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/auth_repository.dart';
import '../services/clientes_repository.dart';
import '../services/mock_auth_repository.dart';
import '../services/mock_clientes_repository.dart';
import '../services/mock_ordenes_trabajo_repository.dart';
import '../services/ordenes_trabajo_repository.dart';
import '../services/supabase_auth_repository.dart';
import '../services/supabase_clientes_repository.dart';
import '../services/supabase_ordenes_trabajo_repository.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PUNTO ÚNICO DE INTERCAMBIO Mockup <-> Supabase
/// ─────────────────────────────────────────────────────────────────────────
/// Estos providers leen `AppConfig.useMockData` y entregan la implementación
/// correcta. Las vistas dependen solo de las interfaces abstractas, así que
/// cambiar la bandera (y reiniciar) basta para pasar de datos ficticios a la
/// base de datos real — sin tocar una sola línea de UI.

/// Repositorio de autenticación activo.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConfig.useMockData
      ? MockAuthRepository()
      : SupabaseAuthRepository();
});

/// Repositorio del directorio de clientes activo.
final clientesRepositoryProvider = Provider<ClientesRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockClientesRepository()
      : SupabaseClientesRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Repositorio de órdenes de trabajo activo.
final ordenesTrabajoRepositoryProvider =
    Provider<OrdenesTrabajoRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockOrdenesTrabajoRepository()
      : SupabaseOrdenesTrabajoRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
