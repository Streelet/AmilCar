import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pantalla mostrada mientras la app restaura la sesión persistida.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo de la marca centrado. El JPG tiene fondo blanco que
            // se funde con el background off-white de la app sin marco
            // visible.
            Image.asset(
              'assets/branding/logo.png',
              width: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
