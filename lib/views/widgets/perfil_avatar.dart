import 'package:flutter/material.dart';

import '../../models/perfil.dart';
import '../../theme/app_colors.dart';

/// Avatar circular del usuario. Renderiza la `foto_url` del perfil y, si no
/// existe o falla la carga (p. ej. sin red), muestra las iniciales.
class PerfilAvatar extends StatelessWidget {
  const PerfilAvatar({
    super.key,
    required this.perfil,
    this.size = 40,
    this.borde = true,
  });

  final Perfil perfil;
  final double size;
  final bool borde;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer,
        border: borde
            ? Border.all(color: AppColors.surfaceContainerLowest, width: 2)
            : null,
      ),
      child: tieneFoto
          ? Image.network(
              perfil.fotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Iniciales(perfil: perfil),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _Iniciales(perfil: perfil);
              },
            )
          : _Iniciales(perfil: perfil),
    );
  }
}

class _Iniciales extends StatelessWidget {
  const _Iniciales({required this.perfil});
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryContainer,
      child: Center(
        child: Text(
          perfil.iniciales,
          style: const TextStyle(
            color: AppColors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
