import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/orden_trabajo.dart';
import '../../models/pdf_cotizacion.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../theme/app_colors.dart';

/// Resultado del diálogo de monto. Si [monto] es null, la orden se mueve
/// sin tocar `monto_aprobado` (solo cuando el diálogo permite esa opción).
class ResultadoMontoDialog {
  const ResultadoMontoDialog({this.monto});
  final double? monto;
}

// ════════════════════════ ORQUESTADORES PÚBLICOS ════════════════════════

/// Cierre de Trato Remoto (Esperando Aprobación → Pendientes de Trabajo).
///
/// El cliente aprobó un presupuesto en el lugar; el flujo pregunta cuál
/// fue ese presupuesto (o un monto manual), y registra esa cifra al
/// mover. Si la orden no tiene Estimados cargados, también permite mover
/// sin monto.
Future<bool> ejecutarCierreTrato(
  BuildContext context,
  WidgetRef ref,
  OrdenTrabajo ordenTrabajo,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final resultado = await _mostrarDialogoMonto(
    context,
    orden: ordenTrabajo,
    titulo: 'Cerrar trato',
    descripcion: ordenTrabajo.pdfsUrls.isEmpty
        ? 'Esta orden no tiene Estimados cargados.'
        : '¿Qué presupuesto aprobó el cliente en el lugar?',
    botonConfirmar: 'Confirmar',
    permitirSinMonto: true,
    preferirManualPorDefecto: false,
  );
  if (resultado == null) return false;

  await ref.read(ordenesTrabajoControllerProvider).aprobarTrato(
        ordenTrabajo: ordenTrabajo,
        montoAprobado: resultado.monto,
      );

  final mensaje = resultado.monto == null
      ? 'Movido a "Pendientes de Trabajo" sin registrar monto.'
      : 'Trato cerrado por ${_formatMonto(resultado.monto!)}. '
          'Movido a "Pendientes de Trabajo".';
  messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  return true;
}

/// Cierre del trabajo (En Proceso → Pendiente de Pago).
///
/// Se pregunta cuánto debe cobrarse al cliente. El campo de monto manual
/// queda pre-seleccionado y pre-rellenado con el `monto_aprobado` previo
/// (si existía), pero el usuario puede sobrescribirlo o, si la orden tiene
/// Estimados cargados, elegir el monto de uno como atajo.
Future<bool> ejecutarMoverAPendientePago(
  BuildContext context,
  WidgetRef ref,
  OrdenTrabajo ordenTrabajo,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final resultado = await _mostrarDialogoMonto(
    context,
    orden: ordenTrabajo,
    titulo: 'Mover a Por Cobrar',
    descripcion: '¿Cuánto debe pagar el cliente por este trabajo?',
    botonConfirmar: 'Mover a Por Cobrar',
    permitirSinMonto: false,
    preferirManualPorDefecto: true,
    montoInicialManual: ordenTrabajo.montoAprobado,
  );
  if (resultado == null || resultado.monto == null) return false;

  await ref.read(ordenesTrabajoControllerProvider).moverConMonto(
        ordenTrabajo: ordenTrabajo,
        monto: resultado.monto!,
        destino: EstadoKanban.pendientePago,
      );

  messenger.showSnackBar(SnackBar(
    content: Text(
      'Movido a Pendiente de Pago. A cobrar: ${_formatMonto(resultado.monto!)}',
    ),
  ));
  return true;
}

// ════════════════════════ INTERNOS ════════════════════════

String _formatMonto(double monto) {
  final entero = monto.round();
  final texto = entero.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '${AppConfig.currencySymbol}$texto';
}

/// Helper genérico que abre el diálogo parametrizado.
Future<ResultadoMontoDialog?> _mostrarDialogoMonto(
  BuildContext context, {
  required OrdenTrabajo orden,
  required String titulo,
  required String descripcion,
  required String botonConfirmar,
  required bool permitirSinMonto,
  required bool preferirManualPorDefecto,
  double? montoInicialManual,
}) {
  return showDialog<ResultadoMontoDialog>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MontoDialog(
      orden: orden,
      titulo: titulo,
      descripcion: descripcion,
      botonConfirmar: botonConfirmar,
      permitirSinMonto: permitirSinMonto,
      preferirManualPorDefecto: preferirManualPorDefecto,
      montoInicialManual: montoInicialManual,
    ),
  );
}

/// Diálogo de monto reutilizable. Se adapta según los parámetros:
///  - [preferirManualPorDefecto]: si true, el campo manual se muestra
///    arriba (con autofocus) y las opciones de Estimados PDF aparecen
///    debajo como atajo. Si false, las opciones van primero (UX original
///    de Cierre de Trato).
///  - [permitirSinMonto]: agrega un botón "Mover sin monto" que devuelve
///    un resultado con monto null.
///  - [montoInicialManual]: pre-rellena el TextField (útil al heredar el
///    `monto_aprobado` previo).
class _MontoDialog extends ConsumerStatefulWidget {
  const _MontoDialog({
    required this.orden,
    required this.titulo,
    required this.descripcion,
    required this.botonConfirmar,
    required this.permitirSinMonto,
    required this.preferirManualPorDefecto,
    this.montoInicialManual,
  });

  final OrdenTrabajo orden;
  final String titulo;
  final String descripcion;
  final String botonConfirmar;
  final bool permitirSinMonto;
  final bool preferirManualPorDefecto;
  final double? montoInicialManual;

  @override
  ConsumerState<_MontoDialog> createState() => _MontoDialogState();
}

class _MontoDialogState extends ConsumerState<_MontoDialog> {
  /// Índice de la cotización elegida; null si no hay selección.
  int? _seleccion;
  late final TextEditingController _montoCtrl;

  @override
  void initState() {
    super.initState();
    final inicial = widget.montoInicialManual;
    _montoCtrl = TextEditingController(
      text: inicial == null ? '' : inicial.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  bool get _hayMontoManualValido {
    final t = _montoCtrl.text.trim();
    if (t.isEmpty) return false;
    final parsed = double.tryParse(t.replaceAll(',', ''));
    return parsed != null && parsed > 0;
  }

  bool get _puedeConfirmar =>
      _seleccion != null || _hayMontoManualValido;

  void _confirmar() {
    double? monto;
    if (_seleccion != null) {
      monto = widget.orden.pdfsUrls[_seleccion!].montoSugerido;
    } else if (_hayMontoManualValido) {
      monto = double.parse(_montoCtrl.text.replaceAll(',', ''));
    }
    Navigator.of(context).pop(ResultadoMontoDialog(monto: monto));
  }

  void _moverSinMonto() {
    Navigator.of(context).pop(const ResultadoMontoDialog());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opciones = widget.orden.pdfsUrls;
    final cliente =
        ref.watch(clientesByIdProvider)[widget.orden.clienteId];
    final nombreCliente = cliente?.nombre ?? 'Cliente desconocido';

    // El campo manual y la lista de opciones se ordenan según el modo.
    final manualWidget = _BloqueMontoManual(
      controller: _montoCtrl,
      autofocus: widget.preferirManualPorDefecto,
      helperText: opciones.isEmpty
          ? (widget.permitirSinMonto
              ? 'Ingresá un monto, o usá "Mover sin monto".'
              : 'Ingresá el monto.')
          : (widget.preferirManualPorDefecto
              ? 'Sugerido. Podés ajustarlo o elegir un Estimado abajo.'
              : 'Override del monto sugerido por las cotizaciones.'),
      onChanged: () => setState(() => _seleccion = null),
    );

    final opcionesWidget = opciones.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < opciones.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OpcionCotizacion(
                    cotizacion: opciones[i],
                    seleccionada: _seleccion == i,
                    onTap: () => setState(() {
                      _seleccion = i;
                      _montoCtrl.clear();
                    }),
                  ),
                ),
            ],
          );

    final separador = (opcionesWidget == null)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('o',
                      style: theme.textTheme.labelMedium),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
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
            child: const Icon(Icons.handshake_outlined,
                color: AppColors.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.titulo,
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
              Text(widget.descripcion, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(nombreCliente, style: theme.textTheme.labelMedium),
              const SizedBox(height: 16),
              // Orden invertido según preferirManualPorDefecto.
              if (widget.preferirManualPorDefecto) ...[
                manualWidget,
                if (opcionesWidget != null) ...[
                  separador,
                  opcionesWidget,
                ],
              ] else ...[
                if (opcionesWidget != null) ...[
                  opcionesWidget,
                  separador,
                ],
                manualWidget,
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (widget.permitirSinMonto)
          TextButton(
            onPressed: _moverSinMonto,
            child: const Text('Mover sin monto'),
          ),
        ElevatedButton(
          onPressed: _puedeConfirmar ? _confirmar : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(widget.botonConfirmar),
        ),
      ],
    );
  }
}

class _BloqueMontoManual extends StatelessWidget {
  const _BloqueMontoManual({
    required this.controller,
    required this.autofocus,
    required this.helperText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String helperText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: 'Monto manual',
        hintText: '0',
        prefixText: '${AppConfig.currencySymbol} ',
        helperText: helperText,
      ),
    );
  }
}

/// Una opción de presupuesto seleccionable dentro del diálogo.
class _OpcionCotizacion extends StatelessWidget {
  const _OpcionCotizacion({
    required this.cotizacion,
    required this.seleccionada,
    required this.onTap,
  });

  final PdfCotizacion cotizacion;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: seleccionada
                ? AppColors.primaryFixed
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: seleccionada
                  ? AppColors.primary
                  : AppColors.outlineVariant,
              width: seleccionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                seleccionada
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: seleccionada
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cotizacion.titulo,
                        style: theme.textTheme.titleMedium),
                    Text('Estimado en PDF',
                        style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              Text(
                cotizacion.montoFormateado,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
