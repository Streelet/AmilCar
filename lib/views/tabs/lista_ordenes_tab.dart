import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/orden_trabajo.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import '../widgets/estado_pill.dart';
import '../widgets/orden_trabajo_detail_modal.dart';
import '../widgets/soft_card.dart';

/// Pestaña genérica de listado para las fases posteriores a la fase
/// "Estimado" ("Pendientes de Trabajo", "En Proceso", "Pendiente de Pago").
///
/// Se sincroniza en tiempo real: cuando un trato se cierra en el Kanban, la
/// tarjeta aparece aquí automáticamente en ambos dispositivos.
class ListaOrdenesTrabajoTab extends ConsumerWidget {
  const ListaOrdenesTrabajoTab({
    super.key,
    required this.estado,
    required this.icono,
    required this.mensajeVacio,
  });

  final EstadoKanban estado;
  final IconData icono;
  final String mensajeVacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordenesTrabajoStreamProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => _Mensaje(
        icono: Icons.cloud_off_rounded,
        texto: 'Sin conexión. Revisa tu red e intenta de nuevo.',
      ),
      data: (todas) {
        final items = todas
            .where((o) => !o.archivado && o.estadoKanban == estado)
            .toList();

        if (items.isEmpty) {
          return _Mensaje(icono: icono, texto: mensajeVacio);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final dosColumnas = constraints.maxWidth >= 760;
            final padding = dosColumnas
                ? AppSpacing.marginDesktop
                : AppSpacing.marginMobile;
            // Ancho real del contenido (limitado a 1100 por el ConstrainedBox).
            final anchoContenido = (constraints.maxWidth - padding * 2)
                .clamp(0.0, 1100.0)
                .toDouble();
            final anchoItem = dosColumnas
                ? (anchoContenido - AppSpacing.gutter) / 2
                : anchoContenido;

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Wrap(
                    spacing: AppSpacing.gutter,
                    runSpacing: 16,
                    children: [
                      for (final o in items)
                        SizedBox(
                          width: anchoItem,
                          child: _OrdenTrabajoCard(
                              ordenTrabajo: o, icono: icono),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrdenTrabajoCard extends ConsumerWidget {
  const _OrdenTrabajoCard({required this.ordenTrabajo, required this.icono});
  final OrdenTrabajo ordenTrabajo;
  final IconData icono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(ordenTrabajo.estadoKanban);
    final cliente =
        ref.watch(clientesByIdProvider)[ordenTrabajo.clienteId];

    return SoftCard(
      onTap: () => mostrarDetalleOrdenTrabajo(context, ordenTrabajo.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: estilo.container,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(icono, color: estilo.color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EstadoPill(
                        estado: ordenTrabajo.estadoKanban, dense: true),
                    const SizedBox(height: 6),
                    Text(ordenTrabajo.vehiculoResumen,
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _Linea(
            icono: Icons.person_outline_rounded,
            texto: cliente?.nombre ?? 'Cliente desconocido',
          ),
          if (cliente?.telefono != null && cliente!.telefono!.isNotEmpty)
            _Linea(
              icono: Icons.phone_outlined,
              texto: cliente.telefono!,
            ),
          if (cliente?.direccion != null && cliente!.direccion!.isNotEmpty)
            _Linea(
              icono: Icons.location_on_outlined,
              texto: cliente.direccion!,
            ),
          if (cliente?.email != null && cliente!.email!.isNotEmpty)
            _Linea(
              icono: Icons.email_outlined,
              texto: cliente.email!,
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: estilo.color,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monto aprobado',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.onPrimary),
                ),
                Text(
                  ordenTrabajo.montoAprobado != null
                      ? ordenTrabajo.montoAprobadoFormateado
                      : 'Pendiente',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: AppColors.onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 46, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
