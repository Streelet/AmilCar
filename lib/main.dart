import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'views/login_screen.dart';
import 'views/main_dashboard.dart';
import 'views/widgets/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fase 1: cargar credenciales de forma segura desde .env.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // En modo Mockup el .env es opcional; se ignora si falta.
  }

  // Supabase solo se inicializa en modo producción. En modo Mockup la app
  // arranca 100% offline, sin tocar internet.
  if (!AppConfig.useMockData) {
    await SupabaseConfig.initialize();
  }

  runApp(const ProviderScope(child: AmilCarApp()));
}

class AmilCarApp extends StatelessWidget {
  const AmilCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según el estado de autenticación global.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    final Widget pantalla;
    if (auth.checking) {
      pantalla = const SplashScreen();
    } else if (auth.isAuthenticated) {
      pantalla = const MainDashboard();
    } else {
      pantalla = const LoginScreen();
    }

    // Transición suave entre login y dashboard.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      child: Container(
        key: ValueKey(pantalla.runtimeType),
        color: AppColors.background,
        child: pantalla,
      ),
    );
  }
}
