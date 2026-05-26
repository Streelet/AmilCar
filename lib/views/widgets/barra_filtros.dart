import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/clientes_provider.dart';
import '../../providers/filtros_provider.dart';
import '../../theme/app_colors.dart';
import 'cliente_picker.dart';

/// Barra horizontal con los filtros globales de órdenes (cliente + rango
/// de fechas). Cada filtro es una "pill" que abre su picker; cuando está
/// activa muestra el valor + X para limpiar. Si hay al menos uno activo,
/// aparece "Limpiar todo" al final.
///
/// El estado es global ([filtroClienteIdProvider], [filtroRangoFechasProvider]),
/// así que la misma barra usada en cualquier pestaña refleja y modifica el
/// mismo filtro — un click filtra el pipeline entero.
class BarraFiltros extends ConsumerWidget {
  const BarraFiltros({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtroClienteId = ref.watch(filtroClienteIdProvider);
    final filtroRango = ref.watch(filtroRangoFechasProvider);
    final clientesById = ref.watch(clientesByIdProvider);
    final clienteFiltrado =
        filtroClienteId == null ? null : clientesById[filtroClienteId];
    final hayActivos = ref.watch(hayFiltrosActivosProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PillFiltro(
              icono: Icons.person_outline_rounded,
              activo: clienteFiltrado != null,
              etiqueta: clienteFiltrado?.nombre ?? 'Cliente',
              onTap: () async {
                final elegido = await mostrarSelectorCliente(context);
                if (elegido != null) {
                  ref.read(filtroClienteIdProvider.notifier).state =
                      elegido.id;
                }
              },
              onLimpiar: clienteFiltrado == null
                  ? null
                  : () => ref
                      .read(filtroClienteIdProvider.notifier)
                      .state = null,
            ),
            const SizedBox(width: 8),
            _PillFiltro(
              icono: Icons.event_outlined,
              activo: filtroRango != null,
              etiqueta: filtroRango == null
                  ? 'Fecha'
                  : '${_d(filtroRango.start)} → ${_d(filtroRango.end)}',
              onTap: () async {
                final ahora = DateTime.now();
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(ahora.year - 3),
                  lastDate: DateTime(ahora.year + 1),
                  initialDateRange: filtroRango,
                  helpText: 'Filtrar por fecha de creación',
                  saveText: 'Aplicar',
                );
                if (rango != null) {
                  ref.read(filtroRangoFechasProvider.notifier).state =
                      rango;
                }
              },
              onLimpiar: filtroRango == null
                  ? null
                  : () => ref
                      .read(filtroRangoFechasProvider.notifier)
                      .state = null,
            ),
            if (hayActivos) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  ref.read(filtroClienteIdProvider.notifier).state = null;
                  ref.read(filtroRangoFechasProvider.notifier).state = null;
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _d(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}';
  }
}

/// Pill de un filtro individual. Inactivo: outlined neutro. Activo: chip
/// relleno con valor + X para limpiar.
class _PillFiltro extends StatelessWidget {
  const _PillFiltro({
    required this.icono,
    required this.activo,
    required this.etiqueta,
    required this.onTap,
    required this.onLimpiar,
  });

  final IconData icono;
  final bool activo;
  final String etiqueta;
  final VoidCallback onTap;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: activo
          ? theme.colorScheme.primaryContainer
          : AppColors.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(
          color:
              activo ? theme.colorScheme.primary : AppColors.outlineVariant,
          width: activo ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 6, activo ? 4 : 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono,
                  size: 14,
                  color: activo
                      ? theme.colorScheme.onPrimaryContainer
                      : AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: activo
                        ? theme.colorScheme.onPrimaryContainer
                        : AppColors.onSurface,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (activo && onLimpiar != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  onTap: onLimpiar,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 14,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
