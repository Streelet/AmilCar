import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cliente.dart';
import '../../providers/clientes_provider.dart';
import '../../theme/app_colors.dart';
import 'cliente_form_dialog.dart';

/// Abre el selector de cliente como página full-screen. Devuelve el
/// [Cliente] elegido (existente o recién creado), o `null` si se cancela.
Future<Cliente?> mostrarSelectorCliente(BuildContext context) {
  return Navigator.of(context).push<Cliente>(
    MaterialPageRoute<Cliente>(
      fullscreenDialog: true,
      builder: (_) => const _ClientePickerScreen(),
    ),
  );
}

class _ClientePickerScreen extends ConsumerStatefulWidget {
  const _ClientePickerScreen();

  @override
  ConsumerState<_ClientePickerScreen> createState() =>
      _ClientePickerScreenState();
}

class _ClientePickerScreenState extends ConsumerState<_ClientePickerScreen> {
  String _busqueda = '';
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  Future<void> _crearNuevoCliente() async {
    final nuevo = await mostrarFormularioCliente(context);
    if (nuevo != null && mounted) {
      // Al crear desde el selector, se devuelve inmediatamente al flujo
      // de origen con el cliente recién creado pre-seleccionado.
      Navigator.of(context).pop(nuevo);
    }
  }

  List<Cliente> _filtrar(List<Cliente> todos) {
    if (_busqueda.trim().isEmpty) return todos;
    final q = _busqueda.toLowerCase();
    return todos.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          (c.telefono?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(clientesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Elegir cliente'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Buscador + botón nuevo cliente ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrlBusqueda,
                    onChanged: (v) => setState(() => _busqueda = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, teléfono o email…',
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _crearNuevoCliente,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Crear cliente nuevo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // ── Lista de clientes ─────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) =>
                  const _Mensaje(texto: 'No se pudo cargar el directorio.'),
              data: (todos) {
                final filtrados = _filtrar(todos);
                if (filtrados.isEmpty) {
                  return _Mensaje(
                    texto: _busqueda.trim().isEmpty
                        ? 'Aún no hay clientes. Crea el primero arriba.'
                        : 'Sin resultados para "$_busqueda".',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, i) {
                    final c = filtrados[i];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(c),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Text(
                          c.iniciales,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(c.nombre,
                          style: theme.textTheme.titleMedium),
                      subtitle: Text(
                        [c.telefono, c.email]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
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

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 42, color: AppColors.outline),
            const SizedBox(height: 10),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
