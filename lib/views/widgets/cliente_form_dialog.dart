import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/cliente.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';

/// Abre el formulario de cliente (alta o edición). Devuelve el [Cliente]
/// guardado, o `null` si se canceló.
///
/// Si [clienteAEditar] es null → modo alta (genera UUID v4 nuevo).
/// Si trae valor → modo edición (preserva el id original).
Future<Cliente?> mostrarFormularioCliente(
  BuildContext context, {
  Cliente? clienteAEditar,
}) {
  return showDialog<Cliente>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClienteFormDialog(clienteAEditar: clienteAEditar),
  );
}

class _ClienteFormDialog extends ConsumerStatefulWidget {
  const _ClienteFormDialog({this.clienteAEditar});
  final Cliente? clienteAEditar;

  @override
  ConsumerState<_ClienteFormDialog> createState() =>
      _ClienteFormDialogState();
}

class _ClienteFormDialogState extends ConsumerState<_ClienteFormDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  late final TextEditingController _email;
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  bool get _esEdicion => widget.clienteAEditar != null;

  @override
  void initState() {
    super.initState();
    final c = widget.clienteAEditar;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _direccion = TextEditingController(text: c?.direccion ?? '');
    _email = TextEditingController(text: c?.email ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cliente = (widget.clienteAEditar ??
            Cliente(id: const Uuid().v4(), nombre: ''))
        .copyWith(
      nombre: _nombre.text.trim(),
      telefono: _vacioComoNull(_telefono.text),
      direccion: _vacioComoNull(_direccion.text),
      email: _vacioComoNull(_email.text),
    );

    try {
      await ref
          .read(clientesControllerProvider)
          .upsertCliente(cliente, esNuevo: !_esEdicion);
      if (!mounted) return;
      Navigator.of(context).pop(cliente);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cliente: $e')),
      );
    }
  }

  String? _vacioComoNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _eliminar() async {
    final cliente = widget.clienteAEditar!;
    final messenger = ScaffoldMessenger.of(context);

    // Cuenta de órdenes que referenciarán a este cliente huérfano si se
    // borra. Se cuenta todo (activas + archivadas) para que el aviso sea
    // honesto sobre las consecuencias.
    final todas =
        ref.read(ordenesTrabajoStreamProvider).valueOrNull ?? const [];
    final referencias = todas.where((o) => o.clienteId == cliente.id).length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          referencias == 0
              ? '¿Eliminar a "${cliente.nombre}"? Esta acción es soft '
                  'delete: la fila queda en la BD para auditoría pero no '
                  'se ve más desde la app.'
              : '¿Eliminar a "${cliente.nombre}"? Hay $referencias '
                  'orden${referencias == 1 ? '' : 'es'} de trabajo que '
                  'lo referencian y mostrarán "Cliente desconocido". '
                  'Recuperable por SQL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(clientesControllerProvider)
          .eliminarCliente(cliente.id, nombre: cliente.nombre);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Cliente "${cliente.nombre}" eliminado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el cliente: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded,
                color: AppColors.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
              style: theme.textTheme.headlineMedium,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  enabled: !_guardando,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. María González',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  enabled: !_guardando,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+502 5512 8834',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _direccion,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Zona 10, 5a Avenida',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: !_guardando,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'cliente@correo.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final t = v.trim();
                    if (!t.contains('@') || !t.contains('.')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      // Las acciones del AlertDialog usan internamente un OverflowBar
      // (no un Row), donde `Spacer` no puede vivir. Metemos toda la fila
      // en un único Row para poder usar Spacer y separar visualmente el
      // "Eliminar" (izquierda) del par Cancelar/Guardar (derecha).
      actions: [
        Row(
          children: [
            if (_esEdicion)
              TextButton.icon(
                onPressed: _guardando ? null : _eliminar,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed:
                  _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(_esEdicion ? 'Guardar' : 'Crear cliente'),
            ),
          ],
        ),
      ],
    );
  }
}
