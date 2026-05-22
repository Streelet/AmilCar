import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/estimado.dart';
import '../../providers/estimados_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import '../widgets/estado_pill.dart';
import '../widgets/estimado_detail_modal.dart';
import '../widgets/soft_card.dart';

/// Pestaña genérica de listado para los estados posteriores al estimado
/// ("Pendientes de Trabajo", "En Proceso", "Pendiente de Pago").
///
/// Se sincroniza en tiempo real: cuando un trato se cierra en el Kanban, la
/// tarjeta aparece aquí automáticamente en ambos dispositivos.
class ListaEstimadosTab extends ConsumerWidget {
  const ListaEstimadosTab({
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
    final async = ref.watch(estimadosStreamProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => _Mensaje(
        icono: Icons.cloud_off_rounded,
        texto: 'Sin conexión. Revisa tu red e intenta de nuevo.',
      ),
      data: (todos) {
        final items = todos
            .where((e) => !e.archivado && e.estadoKanban == estado)
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
                      for (final e in items)
                        SizedBox(
                          width: anchoItem,
                          child: _EstimadoCard(estimado: e, icono: icono),
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

class _EstimadoCard extends StatelessWidget {
  const _EstimadoCard({required this.estimado, required this.icono});
  final Estimado estimado;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(estimado.estadoKanban);

    return SoftCard(
      onTap: () => mostrarDetalleEstimado(context, estimado.id),
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
                    EstadoPill(estado: estimado.estadoKanban, dense: true),
                    const SizedBox(height: 6),
                    Text(estimado.vehiculoResumen,
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
            texto: estimado.clienteNombre,
          ),
          if (estimado.telefono != null && estimado.telefono!.isNotEmpty)
            _Linea(
              icono: Icons.phone_outlined,
              texto: estimado.telefono!,
            ),
          if (estimado.direccion != null && estimado.direccion!.isNotEmpty)
            _Linea(
              icono: Icons.location_on_outlined,
              texto: estimado.direccion!,
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
                  estimado.montoAprobado != null
                      ? estimado.montoAprobadoFormateado
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
