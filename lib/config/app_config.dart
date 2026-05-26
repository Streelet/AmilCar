/// Configuración global de la aplicación.
///
/// ─────────────────────────────────────────────────────────────────────────
///  BANDERA DE CONTROL: Modo Mockup vs Supabase
/// ─────────────────────────────────────────────────────────────────────────
/// Es el ÚNICO interruptor que hay que tocar para alternar entre:
///
///   • true  -> MODO MOCKUP   : datos ficticios locales, 0% internet.
///                              Login simulado, Kanban, drag&drop, PDFs y
///                              diálogo de aprobación 100% funcionales.
///
///   • false -> MODO SUPABASE : consume la base de datos real vía streams
///                              (realtime / WebSockets) y autenticación real.
///
/// La capa de repositorios (ver lib/services/) está totalmente desacoplada:
/// los providers de Riverpod leen esta bandera y entregan la implementación
/// correcta sin que las vistas se enteren. Cambiar el valor y reiniciar la
/// app es suficiente para pasar de mock a producción.
class AppConfig {
  const AppConfig._();

  /// Interruptor maestro. El MVP viene en modo Mockup por defecto.
  static const bool useMockData = false;

  /// Nombre comercial mostrado en la interfaz.
  static const String appName = 'AmilCar';

  /// Símbolo de moneda usado en presupuestos (dólar estadounidense).
  static const String currencySymbol = r'$';
}
