/// Forma en que se recibió un pago. Valor obligatorio en cada [Pago].
///
/// Al elegir [otro], la UI exige que el usuario describa manualmente la
/// forma de pago (campo `metodo_pago_otro` en la BD).
enum MetodoPago {
  efectivo('efectivo', 'Efectivo'),
  cheque('cheque', 'Cheque'),
  tarjetaCredito('tarjeta_credito', 'Tarjeta de Crédito'),
  tarjetaDebito('tarjeta_debito', 'Tarjeta de Débito'),
  zelle('zelle', 'Zelle'),
  otro('otro', 'Otro');

  const MetodoPago(this.dbValue, this.label);

  /// Valor guardado en la columna `metodo_pago` (snake_case).
  final String dbValue;

  /// Etiqueta legible para mostrar en la UI.
  final String label;

  static MetodoPago fromDb(String? value) {
    return MetodoPago.values.firstWhere(
      (m) => m.dbValue == value,
      orElse: () => MetodoPago.efectivo,
    );
  }

  /// `true` cuando el valor real se especifica en `metodo_pago_otro`.
  bool get esOtro => this == MetodoPago.otro;
}
