import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/estimado.dart';
import '../../providers/estimados_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import '../widgets/aprobacion_dialog.dart';
import '../widgets/kanban_card.dart';

/// Ancho mínimo de cada columna antes de pasar a scroll horizontal.
const double _anchoMinColumna = 300;

/// Ancho del "fantasma" que se ve mientras se arrastra una tarjeta.
const double _anchoFeedback = 280;

/// Pestaña "Pendientes de Estimado" (Fase 4).
///
/// Tablero Kanban de 3 columnas sincronizadas en tiempo real, con
/// Drag & Drop entre columnas y una zona para cerrar el trato.
class PendientesEstimadoTab extends ConsumerWidget {
  const PendientesEstimadoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimadosAsync = ref.watch(estimadosStreamProvider);

    return estimadosAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      // Resiliencia offline: si el stream falla, no se colapsa la app.
      error: (err, _) => _EstadoError(
        onReintentar: () => ref.invalidate(estimadosStreamProvider),
      ),
      data: (todos) {
        final delTablero = todos
            .where((e) => !e.archivado && e.estadoKanban.esColumnaEstimado)
            .toList();
        return _Tablero(estimados: delTablero);
      },
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero({required this.estimados});

  final List<Estimado> estimados;

  @override
  Widget build(BuildContext context) {
    const padH = AppSpacing.marginMobile - 6;
    const padV = 4.0;
    const padInferior = AppSpacing.marginMobile;
    final columnas = EstadoKanban.columnasKanban;

    return Column(
      children: [
        // Zona para cerrar el trato arrastrando una tarjeta fuera de
        // "Esperando Aprobación".
        const _ZonaCierreTrato(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final anchoDisponible = constraints.maxWidth - padH * 2;
              // Si caben las 3 columnas, se estiran para llenar todo el ancho.
              final estirar =
                  anchoDisponible >= _anchoMinColumna * columnas.length;

              final widgetsColumna = [
                for (final estado in columnas)
                  _KanbanColumn(
                    estado: estado,
                    items: estimados
                        .where((e) => e.estadoKanban == estado)
                        .toList(),
                  ),
              ];

              if (estirar) {
                // Aprovecha TODO el ancho horizontal disponible.
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      padH, padV, padH, padInferior),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in widgetsColumna) Expanded(child: c),
                    ],
                  ),
                );
              }

              // Pantalla angosta (tablet/móvil): scroll horizontal.
              final alto = (constraints.maxHeight - padV - padInferior)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                    padH, padV, padH, padInferior),
                child: SizedBox(
                  height: alto,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in widgetsColumna)
                        SizedBox(width: _anchoMinColumna, child: c),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Una columna del Kanban. Actúa como [DragTarget]: acepta tarjetas de
/// otras columnas y, tras una confirmación, dispara el cambio de estado.
class _KanbanColumn extends ConsumerWidget {
  const _KanbanColumn({required this.estado, required this.items});

  final EstadoKanban estado;
  final List<Estimado> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(estado);

    return DragTarget<Estimado>(
      onWillAcceptWithDetails: (details) =>
          details.data.estadoKanban != estado,
      onAcceptWithDetails: (details) async {
        final estimado = details.data;
        // Modal de confirmación para CADA movimiento del Kanban.
        final confirmado = await _confirmarMovimiento(context, estimado, estado);
        if (confirmado) {
          await ref.read(estimadosControllerProvider).moverA(estimado, estado);
        }
      },
      builder: (context, candidatos, _) {
        final resaltado = candidatos.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            // Cada columna luce un tinte propio del color de su estado, para
            // distinguirlas de un vistazo.
            color: resaltado ? estilo.container : estilo.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: resaltado
                  ? estilo.color
                  : estilo.color.withValues(alpha: 0.22),
              width: resaltado ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              // --- Cabecera: banda con el color del estado ---
              Container(
                decoration: BoxDecoration(
                  color: estilo.container,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.xl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 15, 13, 15),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: estilo.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        estado.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: estilo.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        '${items.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: estilo.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // --- Lista de tarjetas ---
              Expanded(
                child: items.isEmpty
                    ? _ColumnaVacia(resaltado: resaltado, estilo: estilo)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(11, 13, 11, 14),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 11),
                        itemBuilder: (context, i) =>
                            _TarjetaArrastrable(estimado: items[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Diálogo de confirmación que se muestra antes de mover una tarjeta.
Future<bool> _confirmarMovimiento(
  BuildContext context,
  Estimado estimado,
  EstadoKanban destino,
) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Mover tarjeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orden de ${estimado.clienteNombre}',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _ChipColumna(estado: estimado.estadoKanban)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.onSurfaceVariant),
                ),
                Expanded(
                  child: _ChipColumna(estado: destino, destacado: true),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            child: const Text('Mover'),
          ),
        ],
      );
    },
  );
  return resultado ?? false;
}

class _ChipColumna extends StatelessWidget {
  const _ChipColumna({required this.estado, this.destacado = false});

  final EstadoKanban estado;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: estilo.container,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border:
            destacado ? Border.all(color: estilo.color, width: 1.5) : null,
      ),
      child: Text(
        estado.label,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: estilo.color),
      ),
    );
  }
}

/// Envuelve una [KanbanCard] en un [Draggable] para el Drag & Drop.
/// Se usa [Draggable] (no LongPressDraggable) para que la tarjeta se arrastre
/// con un clic-y-mover directo, sin tener que mantener presionado.
class _TarjetaArrastrable extends StatelessWidget {
  const _TarjetaArrastrable({required this.estimado});

  final Estimado estimado;

  @override
  Widget build(BuildContext context) {
    final card = KanbanCard(estimado: estimado);

    return Draggable<Estimado>(
      data: estimado,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: _anchoFeedback,
          child: KanbanCard(estimado: estimado, arrastrando: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _ColumnaVacia extends StatelessWidget {
  const _ColumnaVacia({required this.resaltado, required this.estilo});
  final bool resaltado;
  final EstadoStyle estilo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resaltado ? Icons.move_to_inbox_rounded : Icons.inbox_outlined,
            color: resaltado ? estilo.color : AppColors.outline,
            size: 30,
          ),
          const SizedBox(height: 6),
          Text(
            resaltado ? 'Soltar aquí' : 'Sin tarjetas',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resaltado ? estilo.color : null,
                ),
          ),
        ],
      ),
    );
  }
}

/// Zona superior para CERRAR EL TRATO: al arrastrar aquí una tarjeta que está
/// en "Esperando Aprobación", se abre el diálogo de aprobación de monto.
class _ZonaCierreTrato extends ConsumerWidget {
  const _ZonaCierreTrato();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        12,
        AppSpacing.marginMobile,
        8,
      ),
      child: DragTarget<Estimado>(
        onWillAcceptWithDetails: (details) =>
            details.data.estadoKanban == EstadoKanban.esperandoAprobacion,
        onAcceptWithDetails: (details) {
          ejecutarCierreTrato(context, ref, details.data);
        },
        builder: (context, candidatos, _) {
          final activo = candidatos.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.primary
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: activo ? AppColors.primary : AppColors.outlineVariant,
                width: 1.5,
              ),
              boxShadow: activo ? AppShadows.floating : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.handshake_outlined,
                  size: 18,
                  color: activo ? AppColors.onPrimary : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    activo
                        ? 'Soltar para CERRAR TRATO'
                        : 'Arrastra una tarjeta de "Esperando Aprobación" '
                            'aquí para cerrar el trato',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          activo ? AppColors.onPrimary : AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Estado de error con opción de reintento (resiliencia de red).
class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Sin conexión con el servidor',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'No se pudo cargar el tablero. Revisa tu red e intenta de nuevo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
