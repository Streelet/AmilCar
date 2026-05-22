import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/auth_repository.dart';
import '../services/estimados_repository.dart';
import '../services/mock_auth_repository.dart';
import '../services/mock_estimados_repository.dart';
import '../services/supabase_auth_repository.dart';
import '../services/supabase_estimados_repository.dart';

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

/// Repositorio de estimados activo.
final estimadosRepositoryProvider = Provider<EstimadosRepository>((ref) {
  final repo = AppConfig.useMockData
      ? MockEstimadosRepository()
      : SupabaseEstimadosRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
