import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/orden_trabajo.dart';
import '../../providers/clientes_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import 'orden_trabajo_detail_modal.dart';
import 'soft_card.dart';

/// Tarjeta minimalista de la orden de trabajo en el Kanban.
///
/// Estética limpia: el nombre del cliente como título y el teléfono en una
/// etiqueta tipo píldora. No repite el estado —ya lo indica la cabecera de
/// la columna—; conserva el color de la etapa a través del tinte de la
/// etiqueta. El resto de la información vive en el modal de detalle.
///
/// La información del cliente se resuelve por `clienteId` contra el
/// directorio reactivo ([clientesByIdProvider]).
class KanbanCard extends ConsumerWidget {
  const KanbanCard({
    super.key,
    required this.ordenTrabajo,
    this.arrastrando = false,
  });

  final OrdenTrabajo ordenTrabajo;

  /// `true` cuando se dibuja como "fantasma" flotante durante el arrastre.
  final bool arrastrando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(ordenTrabajo.estadoKanban);

    final cliente = ref.watch(clientesByIdProvider)[ordenTrabajo.clienteId];
    final nombre = cliente?.nombre ?? 'Cliente desconocido';
    final tel = cliente?.telefono;
    final telefono =
        (tel != null && tel.isNotEmpty) ? tel : 'Sin teléfono';

    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(15, 15, 13, 16),
      onTap: arrastrando
          ? null
          : () => mostrarDetalleOrdenTrabajo(context, ordenTrabajo.id),
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
                  nombre,
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
          // Vehículo, solo si hay datos registrados.
          if (ordenTrabajo.tieneVehiculo) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(Icons.directions_car_rounded,
                    size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ordenTrabajo.vehiculoResumen,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Fila inferior: teléfono (tinte del estado) + fecha relativa
          // muy pequeña a la derecha, como pista de antigüedad sin abrir
          // el detalle.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: estilo.container,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 13, color: estilo.color),
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
              ),
              if (ordenTrabajo.fechaRelativa.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  ordenTrabajo.fechaRelativa,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
