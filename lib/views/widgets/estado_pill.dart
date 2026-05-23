import 'package:flutter/material.dart';

import '../../models/orden_trabajo.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';

/// Etiqueta de estado con forma de píldora.
///
/// Tinte de baja saturación con texto en el color del estado: identifica de
/// un vistazo a qué etapa del flujo pertenece una tarjeta.
class EstadoPill extends StatelessWidget {
  const EstadoPill({
    super.key,
    required this.estado,
    this.dense = false,
  });

  final EstadoKanban estado;

  /// Versión compacta para tarjetas pequeñas (Kanban).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeEstado(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: estilo.container,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        estado.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: estilo.color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
