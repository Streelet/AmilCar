import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cliente.dart';
import '../models/orden_trabajo.dart';
import '../providers/auth_provider.dart';
import '../providers/clientes_provider.dart';
import '../providers/ordenes_trabajo_provider.dart';
import '../theme/app_colors.dart';
import 'widgets/estado_pill.dart';
import 'widgets/orden_trabajo_detail_modal.dart';

/// Pantalla de Recuperación (Fase 5).
///
/// Lista las órdenes archivadas en una tabla con scroll horizontal cuando
/// haga falta. La restauración es una acción de gestión exclusiva del
/// rol 'admin'; al asesor se le muestra la tabla sin la columna de
/// acción.
class ArchivedScreen extends ConsumerWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivados = ref.watch(ordenesTrabajoArchivadasProvider);
    final perfil = ref.watch(currentPerfilProvider);
    final esAdmin = perfil?.rol.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Órdenes Archivadas')),
      body: archivados.isEmpty
          ? const _Vacio()
          : _TablaArchivados(items: archivados, esAdmin: esAdmin),
    );
  }
}

class _TablaArchivados extends ConsumerWidget {
  const _TablaArchivados({required this.items, required this.esAdmin});

  final List<OrdenTrabajo> items;
  final bool esAdmin;

  Future<void> _restaurar(
    BuildContext context,
    WidgetRef ref,
    OrdenTrabajo orden,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final cliente = ref.read(clientesByIdProvider)[orden.clienteId];
    final nombre = cliente?.nombre ?? 'el cliente';
    await ref.read(ordenesTrabajoControllerProvider).restaurar(orden);
    messenger.showSnackBar(
      SnackBar(content: Text('Orden de $nombre restaurada al tablero.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clientesById = ref.watch(clientesByIdProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    '${items.length} orden${items.length == 1 ? '' : 'es'} archivada${items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 48,
                          dataRowMinHeight: 70,
                          dataRowMaxHeight: 88,
                          headingRowColor: WidgetStateProperty.all(
                              AppColors.surfaceContainerLow),
                          dividerThickness: 0.6,
                          columnSpacing: 28,
                          horizontalMargin: 20,
                          columns: [
                            const DataColumn(label: _HeaderText('Cliente')),
                            const DataColumn(
                                label: _HeaderText('Vehículo')),
                            const DataColumn(label: _HeaderText('Estado')),
                            const DataColumn(
                                label: _HeaderText('Monto'),
                                numeric: true),
                            if (esAdmin)
                              const DataColumn(
                                  label: _HeaderText('Acción')),
                          ],
                          rows: [
                            for (final o in items)
                              DataRow(
                                onSelectChanged: (_) =>
                                    mostrarDetalleOrdenTrabajo(
                                        context, o.id),
                                cells: [
                                  DataCell(_CeldaCliente(
                                      cliente:
                                          clientesById[o.clienteId])),
                                  DataCell(_CeldaVehiculo(orden: o)),
                                  DataCell(EstadoPill(
                                      estado: o.estadoKanban, dense: true)),
                                  DataCell(_CeldaMonto(orden: o)),
                                  if (esAdmin)
                                    DataCell(
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _restaurar(context, ref, o),
                                        icon: const Icon(
                                            Icons.unarchive_outlined,
                                            size: 18),
                                        label: const Text('Restaurar'),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14),
                                          textStyle: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (!esAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 16, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Solo un administrador puede restaurar órdenes archivadas.',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      texto.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _CeldaCliente extends StatelessWidget {
  const _CeldaCliente({required this.cliente});
  final Cliente? cliente;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cliente?.nombre ?? 'Cliente desconocido',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (cliente?.telefono != null && cliente!.telefono!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_rounded,
                    size: 12, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(cliente!.telefono!,
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _CeldaVehiculo extends StatelessWidget {
  const _CeldaVehiculo({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(orden.vehiculoResumen, style: theme.textTheme.bodyLarge),
        if (orden.vehiculoVin != null && orden.vehiculoVin!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'VIN ${orden.vehiculoVin}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _CeldaMonto extends StatelessWidget {
  const _CeldaMonto({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (orden.montoAprobado == null) {
      return Text(
        'Sin registrar',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(
      orden.montoAprobadoFormateado,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Sin órdenes archivadas',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Las órdenes que archives aparecerán aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
