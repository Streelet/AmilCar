import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/auth_repository.dart';
import '../services/clientes_repository.dart';
import '../services/mock_auth_repository.dart';
import '../services/mock_clientes_repository.dart';
import '../services/mock_ordenes_trabajo_repository.dart';
import '../services/mock_pagos_repository.dart';
import '../services/mock_storage_repository.dart';
import '../services/ordenes_trabajo_repository.dart';
import '../services/pagos_repository.dart';
import '../services/storage_repository.dart';
import '../services/supabase_auth_repository.dart';
import '../services/supabase_clientes_repository.dart';
import '../services/supabase_ordenes_trabajo_repository.dart';
import '../services/supabase_pagos_repository.dart';
import '../services/supabase_storage_repository.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PUNTO ÚNICO DE INTERCAMBIO Mockup <-> Supabase
/// ─────────────────────────────────────────────────────────────────────────
/// Estos providers leen `AppConfig.useMockData` y entregan la implementación
/// correcta. Las vistas dependen solo de las interfaces abstractas, así que
/// cambiar la bandera (y reiniciar) basta para pasar de datos ficticios a la
/// base de datos real — sin tocar una sola línea de UI.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConfig.useMockData
      ? MockAuthRepository()
      : SupabaseAuthRepository();
});

final clientesRepositoryProvider = Provider<ClientesRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockClientesRepository()
      : SupabaseClientesRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final ordenesTrabajoRepositoryProvider =
    Provider<OrdenesTrabajoRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockOrdenesTrabajoRepository()
      : SupabaseOrdenesTrabajoRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final pagosRepositoryProvider = Provider<PagosRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockPagosRepository()
      : SupabasePagosRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Storage de archivos (fotos / PDFs de cotización).
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return AppConfig.useMockData
      ? MockStorageRepository()
      : SupabaseStorageRepository();
});
