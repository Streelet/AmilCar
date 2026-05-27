import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audit_entry.dart';
import '../../providers/audit_provider.dart';
import '../../theme/app_colors.dart';

/// Pantalla de auditoría: muestra las últimas acciones de todos los usuarios.
///
/// Solo accesible para rol `admin` (el [UserAvatarMenu] no muestra el botón
/// para asesores, y las RLS de Supabase limitan el SELECT a admins también).
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  AuditCategoria? _filtroCategoria;
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _busquedaCtrl.addListener(() {
      setState(() => _busqueda = _busquedaCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Actividad del sistema'),
        titleTextStyle: theme.textTheme.titleLarge,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barra de búsqueda + filtros ──────────────────────────────
          _BarraFiltros(
            busquedaCtrl: _busquedaCtrl,
            filtroCategoria: _filtroCategoria,
            onCategoriaChanged: (cat) =>
                setState(() => _filtroCategoria = cat),
          ),
          // ── Contenido ────────────────────────────────────────────────
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('No se pudo cargar la actividad.',
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text('$e',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.outline)),
                  ],
                ),
              ),
              data: (entries) {
                final filtradas = _aplicarFiltros(entries);
                if (filtradas.isEmpty) {
                  return Center(
                    child: Text(
                      entries.isEmpty
                          ? 'Sin actividad registrada aún.'
                          : 'No hay resultados para los filtros aplicados.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppColors.outline),
                    ),
                  );
                }
                return _TablaActividad(entries: filtradas);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AuditEntry> _aplicarFiltros(List<AuditEntry> all) {
    return all.where((e) {
      if (_filtroCategoria != null &&
          e.accion.categoria != _filtroCategoria) {
        return false;
      }
      if (_busqueda.isNotEmpty) {
        final usuario = (e.usuarioEmail ?? '').toLowerCase();
        final accion = e.accion.label.toLowerCase();
        final entidad = (e.entidad ?? '').toLowerCase();
        final datos = e.datosResumen.toLowerCase();
        if (!usuario.contains(_busqueda) &&
            !accion.contains(_busqueda) &&
            !entidad.contains(_busqueda) &&
            !datos.contains(_busqueda)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de filtros
// ─────────────────────────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.busquedaCtrl,
    required this.filtroCategoria,
    required this.onCategoriaChanged,
  });

  final TextEditingController busquedaCtrl;
  final AuditCategoria? filtroCategoria;
  final ValueChanged<AuditCategoria?> onCategoriaChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de búsqueda
          TextField(
            controller: busquedaCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por usuario, acción, detalle…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: busquedaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: busquedaCtrl.clear,
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          // Chips de categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChipFiltro(
                  label: 'Todo',
                  seleccionado: filtroCategoria == null,
                  onTap: () => onCategoriaChanged(null),
                ),
                for (final cat in AuditCategoria.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _ChipFiltro(
                      label: cat.label,
                      seleccionado: filtroCategoria == cat,
                      color: _colorCategoria(cat),
                      onTap: () => onCategoriaChanged(
                          filtroCategoria == cat ? null : cat),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.label,
    required this.seleccionado,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool seleccionado;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado
              ? effectiveColor.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: seleccionado
                ? effectiveColor
                : AppColors.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                seleccionado ? FontWeight.w600 : FontWeight.normal,
            color: seleccionado ? effectiveColor : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tabla de actividad
// ─────────────────────────────────────────────────────────────────────────────

class _TablaActividad extends StatelessWidget {
  const _TablaActividad({required this.entries});
  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceContainerLowest,
                ),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 64,
                columnSpacing: 20,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Usuario')),
                  DataColumn(label: Text('Acción')),
                  DataColumn(label: Text('Entidad')),
                  DataColumn(label: Text('Detalles')),
                  DataColumn(label: Text('Plataforma')),
                ],
                rows: [
                  for (final e in entries)
                    DataRow(cells: [
                      // Fecha
                      DataCell(
                        Text(
                          e.fechaFormateada,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Usuario
                      DataCell(
                        Text(
                          e.usuarioEmail ?? '—',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Acción (chip con color)
                      DataCell(
                        _ChipAccion(accion: e.accion),
                      ),
                      // Entidad + ID corto
                      DataCell(
                        e.entidad == null
                            ? const Text('—')
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.entidad!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500),
                                  ),
                                  if (e.entidadId != null)
                                    Text(
                                      e.entidadId!.length > 8
                                          ? '${e.entidadId!.substring(0, 8)}…'
                                          : e.entidadId!,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: AppColors.outline),
                                    ),
                                ],
                              ),
                      ),
                      // Detalles
                      DataCell(
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 260),
                          child: Text(
                            e.datosResumen,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Plataforma
                      DataCell(
                        _BadgePlataforma(plataforma: e.plataforma),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets de detalle
// ─────────────────────────────────────────────────────────────────────────────

class _ChipAccion extends StatelessWidget {
  const _ChipAccion({required this.accion});
  final AuditAccion accion;

  @override
  Widget build(BuildContext context) {
    final color = _colorCategoria(accion.categoria);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        accion.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _BadgePlataforma extends StatelessWidget {
  const _BadgePlataforma({required this.plataforma});
  final String? plataforma;

  @override
  Widget build(BuildContext context) {
    if (plataforma == null) return const Text('—');
    final (icono, label) = switch (plataforma) {
      'android' => (Icons.android_rounded, 'Android'),
      'ios' => (Icons.phone_iphone_rounded, 'iOS'),
      'web' => (Icons.language_rounded, 'Web'),
      'windows' => (Icons.desktop_windows_rounded, 'Windows'),
      'macos' => (Icons.laptop_mac_rounded, 'macOS'),
      'linux' => (Icons.computer_rounded, 'Linux'),
      _ => (Icons.device_unknown_rounded, plataforma!),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Colores por categoría
// ─────────────────────────────────────────────────────────────────────────────

Color _colorCategoria(AuditCategoria cat) => switch (cat) {
      AuditCategoria.auth => const Color(0xFF4A90D9),
      AuditCategoria.ordenes => const Color(0xFF7B52AB),
      AuditCategoria.clientes => const Color(0xFF2E9E6F),
      AuditCategoria.pagos => const Color(0xFF1A9E8C),
      AuditCategoria.archivos => const Color(0xFFE07B39),
    };
