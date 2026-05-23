import 'package:flutter/material.dart';

import '../models/orden_trabajo.dart';

/// Identidad de color por estado del flujo de trabajo.
///
/// Da a cada etapa del Kanban (y de las demás pestañas) una identidad de
/// color propia, para que el estado de cada orden —y cada columna del
/// tablero— se reconozca de un vistazo.
class EstadoStyle {
  const EstadoStyle({
    required this.color,
    required this.container,
    required this.surface,
  });

  /// Acento principal: texto, íconos, puntos y bordes.
  final Color color;

  /// Fondo suave de baja saturación para chips, badges, avatares y la
  /// cabecera de la columna.
  final Color container;

  /// Tinte muy tenue para el fondo del cuerpo de la columna. Mantiene la
  /// identidad de color sin competir con las tarjetas blancas.
  final Color surface;
}

/// Devuelve la paleta del estado indicado.
EstadoStyle estiloDeEstado(EstadoKanban estado) {
  switch (estado) {
    case EstadoKanban.porHacer:
      return const EstadoStyle(
        color: Color(0xFF4F6280), // azul pizarra
        container: Color(0xFFE5E9F1),
        surface: Color(0xFFF1F4F9),
      );
    case EstadoKanban.listosParaEnviar:
      return const EstadoStyle(
        color: Color(0xFF6E5191), // violeta
        container: Color(0xFFEBE4F2),
        surface: Color(0xFFF4F0FA),
      );
    case EstadoKanban.esperandoAprobacion:
      return const EstadoStyle(
        color: Color(0xFFAE7C12), // ámbar
        container: Color(0xFFF6EBD0),
        surface: Color(0xFFFBF4E2),
      );
    case EstadoKanban.pendienteTrabajo:
      return const EstadoStyle(
        color: Color(0xFF1C8175), // verde azulado
        container: Color(0xFFD4ECE8),
        surface: Color(0xFFEAF6F4),
      );
    case EstadoKanban.enProceso:
      return const EstadoStyle(
        color: Color(0xFF2C66A8), // azul
        container: Color(0xFFDAE6F3),
        surface: Color(0xFFEBF2FA),
      );
    case EstadoKanban.pendientePago:
      return const EstadoStyle(
        color: Color(0xFF3B8A4A), // verde
        container: Color(0xFFDAEDDD),
        surface: Color(0xFFEBF6ED),
      );
  }
}
