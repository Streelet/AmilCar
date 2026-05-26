import 'package:flutter/material.dart';

import '../models/orden_trabajo.dart';
import 'app_colors.dart';

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

/// Deriva un [ThemeData] del tema base de la app pero pintando los acentos
/// (botones primarios, focos de input, indicadores) con el color de la
/// [EstadoStyle] correspondiente.
///
/// Pensado para envolver una pestaña entera con `Theme(data: ..., child: ...)`,
/// de modo que el usuario sienta cada etapa con identidad cromática propia
/// sin tener que pintar widget por widget.
///
/// Mantiene el color global de error y del resto del esquema; solo cambia
/// la familia `primary*` y los button themes que pinten con primary.
ThemeData temaParaEstado(BuildContext context, EstadoKanban estado) {
  final base = Theme.of(context);
  final estilo = estiloDeEstado(estado);

  // El app_theme.dart fija backgroundColor: AppColors.primary directamente
  // en ElevatedButton (que se resuelve en build time). Para que los
  // botones de acción tomen el acento de la etapa, hay que sobreescribir
  // el button theme además del colorScheme.
  final elevatedButtonTema = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: estilo.color,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: AppColors.surfaceContainerHigh,
      disabledForegroundColor: AppColors.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: base.textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
  );

  // TextButton también lleva foreground primary por defecto en el tema
  // base; lo sustituimos por el acento del estado para que botones tipo
  // "Cambiar / Editar / Limpiar" salgan teñidos.
  final textButtonTema = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: estilo.color,
      textStyle: base.textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
  );

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: estilo.color,
      onPrimary: AppColors.onPrimary,
      primaryContainer: estilo.container,
      onPrimaryContainer: estilo.color,
    ),
    elevatedButtonTheme: elevatedButtonTema,
    textButtonTheme: textButtonTema,
  );
}
