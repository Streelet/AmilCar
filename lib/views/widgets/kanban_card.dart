import 'package:flutter/material.dart';

import '../../models/estimado.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import 'estimado_detail_modal.dart';
import 'soft_card.dart';

/// Tarjeta minimalista del estimado.
///
/// Estética limpia: el nombre del cliente como título y el teléfono en una
/// etiqueta tipo píldora. No repite el estado —ya lo indica la cabecera de
/// la columna—; conserva el color de la etapa a través del tinte de la
/// etiqueta. El resto de la información vive en el modal de detalle.
class KanbanCard extends StatelessWidget {
  const KanbanCard({
    super.key,
    required this.estimado,
    this.arrastrando = false,
  });

  final Estimado estimado;

  /// `true` cuando se dibuja como "fantasma" flotante durante el arrastre.
  final bool arrastrando;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(estimado.estadoKanban);
    final telefono = (estimado.telefono != null && estimado.telefono!.isNotEmpty)
        ? estimado.telefono!
        : 'Sin teléfono';

    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(15, 15, 13, 16),
      onTap: arrastrando
          ? null
          : () => mostrarDetalleEstimado(context, estimado.id),
      shadows: arrastrando ? AppShadows.floating : AppShadows.card,
      border: arrastrando
          ? Border.all(color: AppColors.primary, width: 1.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cliente — título de la tarjeta — y acceso al detalle.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  estimado.clienteNombre,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.open_in_full_rounded,
                    size: 13, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Etiqueta con el teléfono. Tinte del estado para conservar la
          // identidad de color de la columna; número en tono oscuro de alto
          // contraste para que se lea con claridad.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: estilo.container,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 13, color: estilo.color),
                  const SizedBox(width: 6),
                  Text(
                    telefono,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
