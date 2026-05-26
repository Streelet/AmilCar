import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/orden_trabajo.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';

/// Abre el formulario de edición de los datos del vehículo de una orden.
/// Devuelve `true` si se guardó algún cambio.
///
/// Persiste vía `upsertOrdenTrabajo`, así que los demás campos de la orden
/// se preservan tal cual estaban (no se mandan al server otros valores).
Future<bool> mostrarFormularioVehiculo(
  BuildContext context,
  OrdenTrabajo orden,
) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VehiculoFormDialog(orden: orden),
  );
  return guardado ?? false;
}

class _VehiculoFormDialog extends ConsumerStatefulWidget {
  const _VehiculoFormDialog({required this.orden});
  final OrdenTrabajo orden;

  @override
  ConsumerState<_VehiculoFormDialog> createState() =>
      _VehiculoFormDialogState();
}

class _VehiculoFormDialogState extends ConsumerState<_VehiculoFormDialog> {
  late final TextEditingController _marca;
  late final TextEditingController _modelo;
  late final TextEditingController _anio;
  late final TextEditingController _vin;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final o = widget.orden;
    _marca = TextEditingController(text: o.vehiculoMarca ?? '');
    _modelo = TextEditingController(text: o.vehiculoModelo ?? '');
    _anio =
        TextEditingController(text: o.vehiculoAnio?.toString() ?? '');
    _vin = TextEditingController(text: o.vehiculoVin ?? '');
  }

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _vin.dispose();
    super.dispose();
  }

  String? _vacioComoNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);

    final anioParsed = int.tryParse(_anio.text.trim());
    final actualizada = widget.orden.copyWith(
      vehiculoMarca: _vacioComoNull(_marca.text),
      vehiculoModelo: _vacioComoNull(_modelo.text),
      vehiculoAnio: anioParsed,
      vehiculoVin: _vacioComoNull(_vin.text),
    );

    try {
      await ref
          .read(ordenesTrabajoControllerProvider)
          .agregarOrdenTrabajo(actualizada);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el vehículo: $e')),
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
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.directions_car_rounded,
                color: theme.colorScheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Editar vehículo',
                style: theme.textTheme.headlineMedium),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _marca,
                      enabled: !_guardando,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        hintText: 'Toyota',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modelo,
                      enabled: !_guardando,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        hintText: 'Hilux',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _anio,
                      enabled: !_guardando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        hintText: '2021',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _vin,
                      enabled: !_guardando,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'VIN',
                        hintText: 'MR0FB22G1M0123456',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      actions: [
        TextButton(
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
