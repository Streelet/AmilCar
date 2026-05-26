import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/orden_trabajo.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/filtros_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import '../widgets/aprobacion_dialog.dart';
import '../widgets/barra_filtros.dart';
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
    final ordenesAsync = ref.watch(ordenesTrabajoStreamProvider);

    return ordenesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      // Resiliencia offline: si el stream falla, no se colapsa la app.
      error: (err, _) => _EstadoError(
        onReintentar: () => ref.invalidate(ordenesTrabajoStreamProvider),
      ),
      data: (todos) {
        final filtroCliente = ref.watch(filtroClienteIdProvider);
        final filtroRango = ref.watch(filtroRangoFechasProvider);

        final delTablero = todos.where((o) {
          if (o.archivado) return false;
          if (!o.estadoKanban.esColumnaEstimado) return false;
          if (filtroCliente != null && o.clienteId != filtroCliente) {
            return false;
          }
          if (filtroRango != null) {
            final f = o.createdAt;
            if (f == null) return false;
            // El rango es inclusivo. Se compara contra el día completo
            // (de medianoche a 23:59:59) sin tener que normalizar la hora.
            final desde = filtroRango.start;
            final hasta = filtroRango.end.add(const Duration(days: 1));
            if (f.isBefore(desde) || !f.isBefore(hasta)) return false;
          }
          return true;
        }).toList();

        return _Tablero(ordenesTrabajo: delTablero);
      },
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero({required this.ordenesTrabajo});

  final List<OrdenTrabajo> ordenesTrabajo;

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
        // Barra compacta de filtros (cliente + rango de fechas).
        const BarraFiltros(),
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
                    items: ordenesTrabajo
                        .where((o) => o.estadoKanban == estado)
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
  final List<OrdenTrabajo> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(estado);

    return DragTarget<OrdenTrabajo>(
      onWillAcceptWithDetails: (details) =>
          details.data.estadoKanban != estado,
      onAcceptWithDetails: (details) async {
        final ordenTrabajo = details.data;
        // Modal de confirmación para CADA movimiento del Kanban.
        final confirmado =
            await _confirmarMovimiento(context, ref, ordenTrabajo, estado);
        if (confirmado) {
          await ref
              .read(ordenesTrabajoControllerProvider)
              .moverA(ordenTrabajo, estado);
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
                            _TarjetaArrastrable(ordenTrabajo: items[i]),
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
  WidgetRef ref,
  OrdenTrabajo ordenTrabajo,
  EstadoKanban destino,
) async {
  final cliente = ref.read(clientesByIdProvider)[ordenTrabajo.clienteId];
  final nombreCliente = cliente?.nombre ?? 'Cliente desconocido';

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
            Text('Orden de $nombreCliente',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _ChipColumna(estado: ordenTrabajo.estadoKanban)),
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

/// Envuelve una [KanbanCard] en un [LongPressDraggable] para el Drag & Drop.
///
/// Hay que mantener presionada la tarjeta un instante antes de poder moverla:
/// así un toque simple abre el detalle y no se arrastra por accidente al
/// desplazarse por la columna. Al activarse, la tarjeta flotante tiembla
/// levemente para señalar que ya está "levantada" y lista para mover.
class _TarjetaArrastrable extends StatelessWidget {
  const _TarjetaArrastrable({required this.ordenTrabajo});

  final OrdenTrabajo ordenTrabajo;

  @override
  Widget build(BuildContext context) {
    final card = KanbanCard(ordenTrabajo: ordenTrabajo);

    return LongPressDraggable<OrdenTrabajo>(
      data: ordenTrabajo,
      delay: const Duration(milliseconds: 300),
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: _CartaTemblorosa(
          child: SizedBox(
            width: _anchoFeedback,
            child: KanbanCard(
                ordenTrabajo: ordenTrabajo, arrastrando: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

/// Aplica un temblor sutil y continuo a su hijo. Se usa en la tarjeta
/// flotante mientras se arrastra, para comunicar de un vistazo que la
/// tarjeta está activa y se puede mover.
class _CartaTemblorosa extends StatefulWidget {
  const _CartaTemblorosa({required this.child});

  final Widget child;

  @override
  State<_CartaTemblorosa> createState() => _CartaTemblorosaState();
}

class _CartaTemblorosaState extends State<_CartaTemblorosa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _angulo;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);
    _angulo = Tween<double>(begin: -0.025, end: 0.025).animate(
      CurvedAnimation(parent: _controlador, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angulo,
      builder: (context, child) =>
          Transform.rotate(angle: _angulo.value, child: child),
      child: widget.child,
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
      child: DragTarget<OrdenTrabajo>(
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

// _BarraFiltros y _PillFiltro se movieron a lib/views/widgets/barra_filtros.dart
// para compartirlos con las tablas (Pendientes de Trabajo, En Proceso, Por Cobrar).
