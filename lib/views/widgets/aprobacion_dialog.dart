import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/estimado.dart';
import '../../models/pdf_cotizacion.dart';
import '../../providers/estimados_provider.dart';
import '../../theme/app_colors.dart';

/// Diálogo de Cierre de Trato Remoto (Fase 5).
///
/// Examina el JSON de cotizaciones (`pdfs_urls`) y pregunta cuál presupuesto
/// aprobó el cliente en el lugar. Devuelve la [PdfCotizacion] elegida, o
/// `null` si se cancela. El monto de esa opción se inyectará en
/// `monto_aprobado`.
Future<PdfCotizacion?> mostrarDialogoAprobacion(
  BuildContext context,
  Estimado estimado,
) {
  return showDialog<PdfCotizacion>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AprobacionDialog(estimado: estimado),
  );
}

/// Ejecuta el Cierre de Trato Remoto completo: abre el diálogo de aprobación,
/// inyecta el monto elegido en `monto_aprobado` y mueve el estimado a
/// "Pendientes de Trabajo". Devuelve `true` si el trato se cerró.
Future<bool> ejecutarCierreTrato(
  BuildContext context,
  WidgetRef ref,
  Estimado estimado,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final opcion = await mostrarDialogoAprobacion(context, estimado);
  if (opcion == null) return false;

  await ref.read(estimadosControllerProvider).aprobarTrato(
        estimado: estimado,
        opcionElegida: opcion,
      );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Trato cerrado por ${opcion.montoFormateado}. '
        'Movido a "Pendientes de Trabajo".',
      ),
    ),
  );
  return true;
}

class _AprobacionDialog extends StatefulWidget {
  const _AprobacionDialog({required this.estimado});
  final Estimado estimado;

  @override
  State<_AprobacionDialog> createState() => _AprobacionDialogState();
}

class _AprobacionDialogState extends State<_AprobacionDialog> {
  int? _seleccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opciones = widget.estimado.pdfsUrls;

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
            child: Text('Cerrar trato', style: theme.textTheme.headlineMedium),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Qué presupuesto aprobó el cliente en el lugar?',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.estimado.clienteNombre,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 16),
              if (opciones.isEmpty)
                const _SinCotizaciones()
              else
                for (int i = 0; i < opciones.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OpcionCotizacion(
                      cotizacion: opciones[i],
                      seleccionada: _seleccion == i,
                      onTap: () => setState(() => _seleccion = i),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_seleccion == null || opciones.isEmpty)
              ? null
              : () => Navigator.of(context).pop(opciones[_seleccion!]),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text('Confirmar aprobación'),
        ),
      ],
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
                    Text(cotizacion.titulo, style: theme.textTheme.titleMedium),
                    Text('Cotización en PDF',
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

class _SinCotizaciones extends StatelessWidget {
  const _SinCotizaciones();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este estimado no tiene cotizaciones cargadas. '
              'Agrega al menos una antes de cerrar el trato.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
