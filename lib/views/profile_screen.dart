import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/perfil.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'widgets/perfil_avatar.dart';
import 'widgets/soft_card.dart';

/// Pantalla "Ver Perfil" abierta desde el menú de usuario.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentPerfilProvider);
    final theme = Theme.of(context);

    if (perfil == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: PerfilAvatar(perfil: perfil, size: 104, borde: false),
                ),
                const SizedBox(height: 16),
                Text(
                  perfil.nombre,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Center(child: _ChipRol(rol: perfil.rol)),
                const SizedBox(height: 28),
                SoftCard(
                  child: Column(
                    children: [
                      _Fila(
                        icono: Icons.badge_outlined,
                        etiqueta: 'Nombre',
                        valor: perfil.nombre,
                      ),
                      const Divider(height: 28),
                      _Fila(
                        icono: Icons.mail_outline_rounded,
                        etiqueta: 'Correo',
                        valor: perfil.email ?? 'No disponible',
                      ),
                      const Divider(height: 28),
                      _Fila(
                        icono: Icons.shield_outlined,
                        etiqueta: 'Rol',
                        valor: perfil.rol.label,
                      ),
                      const Divider(height: 28),
                      _Fila(
                        icono: Icons.tag_rounded,
                        etiqueta: 'ID de usuario',
                        valor: perfil.id,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _cerrarSesion(context, ref),
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.error, size: 20),
                  label: const Text('Cerrar Sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      // Cierra la pantalla de perfil; _AuthGate llevará al Login.
      if (navigator.canPop()) navigator.pop();
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _ChipRol extends StatelessWidget {
  const _ChipRol({required this.rol});
  final UserRole rol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rol.isAdmin ? Icons.computer_rounded : Icons.handyman_rounded,
            size: 15,
            color: AppColors.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            rol.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(valor, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
