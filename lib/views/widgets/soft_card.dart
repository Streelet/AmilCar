import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Contenedor base del DESIGN.md: superficie blanca, esquinas de 24px y
/// sombra ambiental muy suave (Nivel 1). Nunca usa bordes duros ni bevels.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color = AppColors.surfaceContainerLowest,
    this.radius = AppRadii.xl,
    this.shadows = AppShadows.card,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final List<BoxShadow> shadows;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final contenido = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: border,
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );

    return contenido;
  }
}
