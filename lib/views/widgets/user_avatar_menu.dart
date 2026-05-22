import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/perfil.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../profile_screen.dart';
import 'perfil_avatar.dart';

/// Menú de usuario del AppBar (Fase 3).
///
/// Avatar circular en la esquina superior derecha que, al pulsarse, despliega
/// un modal con "Ver Perfil" y "Cerrar Sesión".
class UserAvatarMenu extends ConsumerWidget {
  const UserAvatarMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentPerfilProvider);
    if (perfil == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      offset: const Offset(0, 54),
      color: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      position: PopupMenuPosition.under,
      onSelected: (valor) => _onSelected(context, ref, valor),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: _CabeceraPerfil(perfil: perfil),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'perfil',
          child: _OpcionMenu(
            icono: Icons.person_outline_rounded,
            texto: 'Ver Perfil',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: _OpcionMenu(
            icono: Icons.logout_rounded,
            texto: 'Cerrar Sesión',
            destructivo: true,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: PerfilAvatar(perfil: perfil, size: 40),
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String valor,
  ) async {
    if (valor == 'perfil') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    if (valor == 'logout') {
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
        // Tras cerrar sesión, _AuthGate redirige solo al Login.
        await ref.read(authControllerProvider.notifier).signOut();
      }
    }
  }
}

class _CabeceraPerfil extends StatelessWidget {
  const _CabeceraPerfil({required this.perfil});
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          PerfilAvatar(perfil: perfil, size: 44, borde: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  perfil.nombre,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  perfil.rol.label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  const _OpcionMenu({
    required this.icono,
    required this.texto,
    this.destructivo = false,
  });

  final IconData icono;
  final String texto;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final color = destructivo ? AppColors.error : AppColors.onSurface;
    return Row(
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          texto,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
