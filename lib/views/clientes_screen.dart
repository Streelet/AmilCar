import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cliente.dart';
import '../providers/clientes_provider.dart';
import '../providers/ordenes_trabajo_provider.dart';
import '../theme/app_colors.dart';
import 'widgets/cliente_form_dialog.dart';
import 'widgets/soft_card.dart';

/// Directorio de clientes del taller.
///
/// Listado con buscador en vivo y FAB para crear nuevos. Al tocar una
/// tarjeta se abre el formulario en modo edición.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  String _busqueda = '';
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  List<Cliente> _filtrar(List<Cliente> todos) {
    if (_busqueda.trim().isEmpty) return todos;
    final q = _busqueda.toLowerCase();
    return todos.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          (c.telefono?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.direccion?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientesStreamProvider);
    final ordenes =
        ref.watch(ordenesTrabajoStreamProvider).valueOrNull ?? const [];

    // Conteo de órdenes activas por cliente (para mostrar en cada tarjeta).
    final ordenesPorCliente = <String, int>{};
    for (final o in ordenes) {
      if (o.archivado) continue;
      ordenesPorCliente[o.clienteId] =
          (ordenesPorCliente[o.clienteId] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormularioCliente(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 12),
            child: TextField(
              controller: _ctrlBusqueda,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, teléfono, email o dirección…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _ctrlBusqueda.clear();
                          setState(() => _busqueda = '');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const _MensajeVacio(
                  icono: Icons.cloud_off_rounded,
                  texto: 'No se pudo cargar el directorio.'),
              data: (todos) {
                final filtrados = _filtrar(todos);
                if (todos.isEmpty) {
                  return const _MensajeVacio(
                    icono: Icons.people_outline_rounded,
                    texto: 'Aún no hay clientes registrados.',
                  );
                }
                if (filtrados.isEmpty) {
                  return _MensajeVacio(
                    icono: Icons.search_off_rounded,
                    texto: 'Sin resultados para "$_busqueda".',
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final dosColumnas = constraints.maxWidth >= 760;
                    final anchoItem = dosColumnas
                        ? (constraints.maxWidth -
                                AppSpacing.marginMobile * 2 -
                                AppSpacing.gutter) /
                            2
                        : constraints.maxWidth - AppSpacing.marginMobile * 2;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.marginMobile,
                          0,
                          AppSpacing.marginMobile,
                          80),
                      child: Wrap(
                        spacing: AppSpacing.gutter,
                        runSpacing: 12,
                        children: [
                          for (final c in filtrados)
                            SizedBox(
                              width: anchoItem,
                              child: _ClienteTile(
                                cliente: c,
                                ordenesActivas:
                                    ordenesPorCliente[c.id] ?? 0,
                                onTap: () => mostrarFormularioCliente(
                                  context,
                                  clienteAEditar: c,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  const _ClienteTile({
    required this.cliente,
    required this.ordenesActivas,
    required this.onTap,
  });

  final Cliente cliente;
  final int ordenesActivas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryFixed,
            child: Text(
              cliente.iniciales,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cliente.nombre,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ordenesActivas > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius:
                              BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          '$ordenesActivas activa${ordenesActivas == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                  _LineaContacto(
                      icono: Icons.phone_rounded, texto: cliente.telefono!),
                if (cliente.email != null && cliente.email!.isNotEmpty)
                  _LineaContacto(
                      icono: Icons.email_outlined, texto: cliente.email!),
                if (cliente.direccion != null &&
                    cliente.direccion!.isNotEmpty)
                  _LineaContacto(
                      icono: Icons.location_on_outlined,
                      texto: cliente.direccion!),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LineaContacto extends StatelessWidget {
  const _LineaContacto({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icono, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeVacio extends StatelessWidget {
  const _MensajeVacio({required this.icono, required this.texto});
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
            Icon(icono, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(texto,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
