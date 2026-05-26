import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../models/metodo_pago.dart';
import '../../models/nota.dart';
import '../../models/orden_trabajo.dart';
import '../../models/pago.dart';
import '../../providers/pagos_provider.dart';
import '../../theme/app_colors.dart';

/// Abre el formulario de pago (alta o edición). Devuelve el [Pago] guardado,
/// o `null` si se canceló.
///
/// - [orden] aporta el `ordenId` y permite pre-rellenar el monto con el
///   restante por cobrar (cuando es alta).
/// - [pagoAEditar] si viene, modo edición (preserva id y createdAt).
/// - [restante] se usa como valor sugerido para nuevos pagos.
Future<Pago?> mostrarFormularioPago(
  BuildContext context, {
  required OrdenTrabajo orden,
  required double restante,
  Pago? pagoAEditar,
}) {
  return showDialog<Pago>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PagoFormDialog(
      orden: orden,
      restante: restante,
      pagoAEditar: pagoAEditar,
    ),
  );
}

class _PagoFormDialog extends ConsumerStatefulWidget {
  const _PagoFormDialog({
    required this.orden,
    required this.restante,
    this.pagoAEditar,
  });

  final OrdenTrabajo orden;
  final double restante;
  final Pago? pagoAEditar;

  @override
  ConsumerState<_PagoFormDialog> createState() => _PagoFormDialogState();
}

class _PagoFormDialogState extends ConsumerState<_PagoFormDialog> {
  late final TextEditingController _monto;
  late final TextEditingController _nota;
  late final TextEditingController _otroDetalle;
  late DateTime _fecha;
  late MetodoPago _metodo;
  bool _guardando = false;
  final _formKey = GlobalKey<FormState>();

  bool get _esEdicion => widget.pagoAEditar != null;

  @override
  void initState() {
    super.initState();
    final editar = widget.pagoAEditar;
    if (editar != null) {
      _monto = TextEditingController(text: editar.monto.toStringAsFixed(0));
      _nota = TextEditingController(
        text: editar.notas.isNotEmpty ? editar.notas.first.texto : '',
      );
      _otroDetalle =
          TextEditingController(text: editar.metodoPagoOtro ?? '');
      _fecha = editar.fecha;
      _metodo = editar.metodoPago;
    } else {
      // Alta: sugerir el restante. Si está pagado completo (0 o negativo),
      // dejamos vacío.
      _monto = TextEditingController(
        text: widget.restante > 0
            ? widget.restante.toStringAsFixed(0)
            : '',
      );
      _nota = TextEditingController();
      _otroDetalle = TextEditingController();
      _fecha = DateTime.now();
      _metodo = MetodoPago.efectivo;
    }
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    _otroDetalle.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 2),
      lastDate: DateTime(ahora.year + 1),
      helpText: 'Fecha del pago',
    );
    if (elegida != null) {
      setState(() => _fecha = DateTime(
            elegida.year,
            elegida.month,
            elegida.day,
            _fecha.hour,
            _fecha.minute,
          ));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final monto = double.parse(_monto.text.replaceAll(',', '').trim());
    final textoNota = _nota.text.trim();

    // Se construye explícitamente — no por copyWith — para poder
    // FORZAR metodoPagoOtro = null cuando el método NO es "Otro"
    // (copyWith con null no limpia, preservaría el valor previo).
    final original = widget.pagoAEditar;
    final pago = Pago(
      id: original?.id ?? const Uuid().v4(),
      ordenId: widget.orden.id,
      monto: monto,
      fecha: _fecha,
      metodoPago: _metodo,
      metodoPagoOtro: _metodo == MetodoPago.otro
          ? _otroDetalle.text.trim()
          : null,
      notas: () {
        if (_esEdicion && original!.notas.isNotEmpty) {
          if (textoNota.isEmpty) return original.notas.sublist(1);
          final nueva = original.notas.first
              .copyWith(texto: textoNota, fecha: DateTime.now());
          return [nueva, ...original.notas.sublist(1)];
        }
        if (textoNota.isEmpty) return const <Nota>[];
        return [Nota(texto: textoNota, fecha: DateTime.now())];
      }(),
      createdAt: original?.createdAt,
      deletedAt: original?.deletedAt,
    );

    try {
      await ref
          .read(pagosControllerProvider)
          .registrarOEditarPago(pago);
      if (!mounted) return;
      Navigator.of(context).pop(pago);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el pago: $e')),
      );
    }
  }

  String _fechaLabel() {
    final d = _fecha.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year}';
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
            child: const Icon(Icons.payments_outlined,
                color: AppColors.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _esEdicion ? 'Editar pago' : 'Registrar pago',
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
                if (!_esEdicion && widget.restante > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Restante por cobrar: '
                      '${AppConfig.currencySymbol}${widget.restante.round()}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _monto,
                  autofocus: true,
                  enabled: !_guardando,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Monto *',
                    hintText: '0',
                    prefixText: '${AppConfig.currencySymbol} ',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Ingresá un monto.';
                    final parsed = double.tryParse(t.replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) {
                      return 'Monto inválido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _guardando ? null : _elegirFecha,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha del pago',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(_fechaLabel(),
                        style: theme.textTheme.bodyLarge),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<MetodoPago>(
                  initialValue: _metodo,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago *',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final m in MetodoPago.values)
                      DropdownMenuItem<MetodoPago>(
                        value: m,
                        child: Text(m.label),
                      ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (v) {
                          if (v != null) setState(() => _metodo = v);
                        },
                ),
                if (_metodo == MetodoPago.otro) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otroDetalle,
                    enabled: !_guardando,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Especificá el método *',
                      hintText:
                          'Ej. Transferencia BAC, criptomoneda, vale…',
                    ),
                    validator: (v) {
                      if (_metodo != MetodoPago.otro) return null;
                      if ((v ?? '').trim().isEmpty) {
                        return 'Indicá cómo fue el pago.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nota,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText:
                        'Ej. Cliente entregó al recibir, confirmación 4422-XX…',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      actions: [
        TextButton(
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(),
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
              : Text(_esEdicion ? 'Guardar cambios' : 'Registrar pago'),
        ),
      ],
    );
  }
}
