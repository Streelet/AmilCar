import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inicialización del cliente de Supabase (Fase 1).
///
/// Las credenciales se leen de forma segura desde `.env` con flutter_dotenv,
/// nunca se incrustan en el código fuente.
///
/// El SDK `supabase_flutter` persiste la sesión automáticamente en
/// almacenamiento local, de modo que el técnico siga autenticado aunque la
/// app se cierre o pierda cobertura de red en la calle.
class SupabaseConfig {
  const SupabaseConfig._();

  /// Solo se invoca cuando `AppConfig.useMockData == false`.
  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty || url.contains('placeholder')) {
      throw StateError(
        'Faltan credenciales reales de Supabase en .env. '
        'Completa SUPABASE_URL y SUPABASE_ANON_KEY, o deja '
        'AppConfig.useMockData en true para trabajar en modo Mockup.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // Persistencia de sesión + refresco automático del token: la app no
      // colapsa si el técnico pierde la red móvil temporalmente. El canal
      // realtime se reconecta solo al recuperar conectividad.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
  }
}
