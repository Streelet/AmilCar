import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_repository.dart';
import '../theme/app_colors.dart';
import 'widgets/soft_card.dart';

/// Fase 2 — Pantalla de inicio de sesión (Email + Contraseña).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _cargando = false;
  bool _ocultarPass = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _emailCtrl.text,
            password: _passCtrl.text,
          );
      // Si tiene éxito, _AuthGate redirige solo al MainDashboard.
    } on AuthFailure catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(() => _error = 'Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _prefill(String email, String password) {
    _emailCtrl.text = email;
    _passCtrl.text = password;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Encabezado(),
                  const SizedBox(height: 32),
                  SoftCard(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Iniciar sesión',
                              style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Accede para gestionar los estimados.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),

                          // --- Email ---
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !_cargando,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'tu@correo.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Ingresa tu correo.';
                              if (!t.contains('@') || !t.contains('.')) {
                                return 'Correo no válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // --- Contraseña ---
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _ocultarPass,
                            textInputAction: TextInputAction.done,
                            enabled: !_cargando,
                            onFieldSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              hintText: '••••••',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarPass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                    () => _ocultarPass = !_ocultarPass),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Ingresa tu contraseña.';
                              }
                              return null;
                            },
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _BannerError(mensaje: _error!),
                          ],

                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _cargando ? null : _entrar,
                            child: _cargando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // En modo Mockup mostramos las cuentas de prueba.
                  if (AppConfig.useMockData) ...[
                    const SizedBox(height: 20),
                    _PanelDemo(onSelect: _prefill, deshabilitado: _cargando),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: AppShadows.floating,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.car_repair_rounded,
              color: AppColors.onPrimary, size: 34),
        ),
        const SizedBox(height: 16),
        Text(AppConfig.appName, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'ERP · Mecánica Express Móvil e Internacional',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel visible solo en modo Mockup con las cuentas de prueba.
class _PanelDemo extends StatelessWidget {
  const _PanelDemo({required this.onSelect, required this.deshabilitado});

  final void Function(String email, String password) onSelect;
  final bool deshabilitado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: AppColors.surfaceContainerLow,
      shadows: const [],
      border: Border.all(color: AppColors.outlineVariant),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Modo Mockup activo',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sin internet. Toca una cuenta para autocompletar (clave: 123456).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: deshabilitado
                      ? null
                      : () => onSelect('admin@amilcar.com', '123456'),
                  icon: const Icon(Icons.computer_rounded, size: 18),
                  label: const Text('Admin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: deshabilitado
                      ? null
                      : () => onSelect('asesor@amilcar.com', '123456'),
                  icon: const Icon(Icons.handyman_rounded, size: 18),
                  label: const Text('Asesor'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
