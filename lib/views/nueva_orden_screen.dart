import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/cliente.dart';
import '../models/orden_trabajo.dart';
import '../providers/ordenes_trabajo_provider.dart';
import '../theme/app_colors.dart';
import '../theme/estado_style.dart';
import 'widgets/cliente_picker.dart';

/// Abre la pantalla de creación de una nueva orden de trabajo.
Future<void> abrirNuevaOrdenTrabajo(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const NuevaOrdenScreen(),
    ),
  );
}

class NuevaOrdenScreen extends ConsumerStatefulWidget {
  const NuevaOrdenScreen({super.key});

  @override
  ConsumerState<NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends ConsumerState<NuevaOrdenScreen> {
  Cliente? _cliente;
  EstadoKanban _estado = EstadoKanban.porHacer;
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _vin = TextEditingController();
  final _monto = TextEditingController();
  bool _guardando = false;

  /// Las fases pre-aprobación (Por Hacer / Listos para Enviar / Esperando
  /// Aprobación) NO requieren monto: la cifra se acuerda al cerrar el
  /// trato. Las fases post-aprobación SÍ.
  bool get _requiereMonto {
    switch (_estado) {
      case EstadoKanban.pendienteTrabajo:
      case EstadoKanban.enProceso:
      case EstadoKanban.pendientePago:
        return true;
      case EstadoKanban.porHacer:
      case EstadoKanban.listosParaEnviar:
      case EstadoKanban.esperandoAprobacion:
        return false;
    }
  }

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _vin.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente() async {
    final elegido = await mostrarSelectorCliente(context);
    if (elegido != null && mounted) {
      setState(() => _cliente = elegido);
    }
  }

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _crear() async {
    if (_cliente == null) {
      _aviso('Elige un cliente antes de crear la orden.');
      return;
    }

    double? monto;
    if (_requiereMonto) {
      final parsed =
          double.tryParse(_monto.text.replaceAll(',', '').trim());
      if (parsed == null || parsed <= 0) {
        _aviso('Ingresá un monto aprobado válido para esta etapa.');
        return;
      }
      monto = parsed;
    }

    setState(() => _guardando = true);

    final nueva = OrdenTrabajo(
      id: const Uuid().v4(),
      clienteId: _cliente!.id,
      vehiculoMarca: _texto(_marca),
      vehiculoModelo: _texto(_modelo),
      vehiculoAnio: int.tryParse(_anio.text.trim()),
      vehiculoVin: _texto(_vin),
      estadoKanban: _estado,
      montoAprobado: monto,
      createdAt: DateTime.now(),
    );

    try {
      await ref
          .read(ordenesTrabajoControllerProvider)
          .agregarOrdenTrabajo(nueva);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Orden de ${_cliente!.nombre} creada en "${_estado.label}".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo crear la orden: $e');
    }
  }

  String? _texto(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = estiloDeEstado(_estado);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nueva orden de trabajo'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancelar',
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Etapa inicial ────────────────────────────────────
                _tituloSeccion(theme, 'Etapa inicial'),
                const SizedBox(height: 10),
                DropdownButtonFormField<EstadoKanban>(
                  initialValue: _estado,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    for (final e in EstadoKanban.values)
                      DropdownMenuItem<EstadoKanban>(
                        value: e,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: estiloDeEstado(e).color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(e.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: _guardando
                      ? null
                      : (v) {
                          if (v != null) setState(() => _estado = v);
                        },
                ),

                const SizedBox(height: 22),

                // ── Cliente ─────────────────────────────────────────
                _tituloSeccion(theme, 'Cliente'),
                const SizedBox(height: 10),
                _ChipCliente(
                  cliente: _cliente,
                  onElegir: _guardando ? null : _elegirCliente,
                  onLimpiar: _guardando
                      ? null
                      : () => setState(() => _cliente = null),
                ),

                // ── Monto aprobado (sólo si la etapa lo requiere) ───
                if (_requiereMonto) ...[
                  const SizedBox(height: 22),
                  _tituloSeccion(theme, 'Monto aprobado *'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _monto,
                    enabled: !_guardando,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      hintText: '0',
                      prefixText: '${AppConfig.currencySymbol} ',
                      helperText:
                          'Cifra que el cliente acordó pagar por el trabajo.',
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // ── Vehículo (opcional, en cualquier etapa) ─────────
                _tituloSeccion(theme, 'Vehículo (opcional)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _marca,
                        enabled: !_guardando,
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

                const SizedBox(height: 24),

                // ── Aviso contextual ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: estilo.container,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                        color: estilo.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: estilo.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La orden se crea en "${_estado.label}". '
                          'Fotos, cotizaciones, notas y pagos se agregan '
                          'después desde el detalle.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Crear ────────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _crear,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _guardando ? 'Creando…' : 'Crear orden',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tituloSeccion(ThemeData theme, String texto) {
    return Text(
      texto.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary),
    );
  }
}

/// Tarjeta que muestra el cliente elegido, o invita a elegirlo si está vacío.
class _ChipCliente extends StatelessWidget {
  const _ChipCliente({
    required this.cliente,
    required this.onElegir,
    required this.onLimpiar,
  });

  final Cliente? cliente;
  final VoidCallback? onElegir;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (cliente == null) {
      return OutlinedButton.icon(
        onPressed: onElegir,
        icon: const Icon(Icons.person_search_rounded, size: 18),
        label: const Text('Elegir cliente'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return Material(
      color: AppColors.primaryFixed,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onElegir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 18,
                child: Text(
                  cliente!.iniciales,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente!.nombre,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        )),
                    if ((cliente!.telefono?.isNotEmpty ?? false) ||
                        (cliente!.email?.isNotEmpty ?? false))
                      Text(
                        [cliente!.telefono, cliente!.email]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar selección',
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.onPrimaryContainer),
                onPressed: onLimpiar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
