import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/cliente.dart';
import '../../models/nota.dart';
import '../../models/orden_trabajo.dart';
import '../../models/pago.dart';
import '../../models/pdf_cotizacion.dart';
import '../../models/perfil.dart';
import '../../models/audit_entry.dart';
import '../../providers/audit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clientes_provider.dart';
import '../../providers/ordenes_trabajo_provider.dart';
import '../../providers/pagos_provider.dart';
import '../../providers/repository_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import 'aprobacion_dialog.dart';
import 'cliente_picker.dart';
import 'pago_form_dialog.dart';
import 'vehiculo_form_dialog.dart';
import 'visor_imagenes.dart';
import 'visor_pdf.dart';

/// Abre el modal de detalle de la orden de trabajo.
///
/// El fondo (dashboard) queda difuminado (blur) mientras el modal está
/// abierto. Toda la información — vehículo, fotos, cotizaciones, subida de
/// PDFs y acciones — vive aquí.
Future<void> mostrarDetalleOrdenTrabajo(BuildContext context, String ordenTrabajoId) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'Detalle de la orden de trabajo',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _ModalDetalle(ordenTrabajoId: ordenTrabajoId),
    transitionBuilder: (context, anim, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Capa de pantalla completa: fondo difuminado (toca para cerrar) + tarjeta.
class _ModalDetalle extends StatelessWidget {
  const _ModalDetalle({required this.ordenTrabajoId});
  final String ordenTrabajoId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
        Center(child: _TarjetaDetalle(ordenTrabajoId: ordenTrabajoId)),
      ],
    );
  }
}

class _TarjetaDetalle extends ConsumerStatefulWidget {
  const _TarjetaDetalle({required this.ordenTrabajoId});
  final String ordenTrabajoId;

  @override
  ConsumerState<_TarjetaDetalle> createState() => _TarjetaDetalleState();
}

class _TarjetaDetalleState extends ConsumerState<_TarjetaDetalle> {
  bool _formCotizAbierto = false;
  bool _ocupado = false;
  String? _pdfNombre;

  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _notaCtrl = TextEditingController();

  /// Bytes de las fotos elegidas en esta sesión, para mostrarlas de verdad.
  final Map<String, Uint8List> _fotosLocales = {};

  /// Bytes de los PDF elegidos en esta sesión, para mostrarlos de verdad.
  final Map<String, Uint8List> _pdfsLocales = {};

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordenesTrabajo =
        ref.watch(ordenesTrabajoStreamProvider).valueOrNull ??
            const <OrdenTrabajo>[];
    final perfil = ref.watch(currentPerfilProvider);
    final ordenTrabajo = ordenesTrabajo
        .cast<OrdenTrabajo?>()
        .firstWhere((o) => o!.id == widget.ordenTrabajoId,
            orElse: () => null);
    final cliente = ordenTrabajo != null
        ? ref.watch(clientesByIdProvider)[ordenTrabajo.clienteId]
        : null;

    // Tema derivado: el modal toma el color de acento del estado actual
    // de la orden, así el usuario siente la etapa de un vistazo (botones,
    // banners, focos de input toman ese color).
    final tema = ordenTrabajo == null
        ? Theme.of(context)
        : temaParaEstado(context, ordenTrabajo.estadoKanban);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, escala, child) =>
          Transform.scale(scale: escala, child: child),
      child: Theme(
        data: tema,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 860,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: Material(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              clipBehavior: Clip.antiAlias,
              child: ordenTrabajo == null
                  ? _noDisponible()
                  : _tarjeta(ordenTrabajo, cliente, perfil),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Estructura ─────────────────────────

  Widget _tarjeta(OrdenTrabajo ordenTrabajo, Cliente? cliente, Perfil? perfil) {
    final acciones = _footer(ordenTrabajo, cliente, perfil);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(ordenTrabajo, perfil),
        Flexible(
          child: LayoutBuilder(
            builder: (_, box) {
              final wide = box.maxWidth > 580;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: wide
                    ? _cuerpoDosCol(ordenTrabajo, cliente, perfil)
                    : _cuerpoUnaCol(ordenTrabajo, cliente, perfil),
              );
            },
          ),
        ),
        if (acciones != null) acciones,
      ],
    );
  }

  /// Layout de una columna (portrait / pantalla estrecha).
  Widget _cuerpoUnaCol(OrdenTrabajo ordenTrabajo, Cliente? cliente, Perfil? perfil) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionCliente(ordenTrabajo, cliente),
        const SizedBox(height: 18),
        _seccionVehiculo(ordenTrabajo),
        const SizedBox(height: 18),
        _seccionNotas(ordenTrabajo),
        const SizedBox(height: 18),
        _seccionFotos(ordenTrabajo),
        const SizedBox(height: 18),
        _seccionCotizaciones(ordenTrabajo, perfil),
        if (ordenTrabajo.montoAprobado != null) ...[
          const SizedBox(height: 18),
          _bannerMonto(ordenTrabajo),
        ],
        const SizedBox(height: 18),
        _seccionPagos(ordenTrabajo),
      ],
    );
  }

  /// Layout de dos columnas (landscape / modal ancho).
  ///
  /// Izquierda: datos del cliente, vehículo y notas.
  /// Derecha: fotografías, cotizaciones (Estimados PDF) y monto aprobado.
  Widget _cuerpoDosCol(OrdenTrabajo ordenTrabajo, Cliente? cliente, Perfil? perfil) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Columna izquierda ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seccionCliente(ordenTrabajo, cliente),
                const SizedBox(height: 18),
                _seccionVehiculo(ordenTrabajo),
                const SizedBox(height: 18),
                _seccionNotas(ordenTrabajo),
              ],
            ),
          ),
          // ── Divisor vertical ──────────────────────────────────────
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            color: AppColors.surfaceContainerHigh,
          ),
          // ── Columna derecha ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seccionFotos(ordenTrabajo),
                const SizedBox(height: 18),
                _seccionCotizaciones(ordenTrabajo, perfil),
                if (ordenTrabajo.montoAprobado != null) ...[
                  const SizedBox(height: 18),
                  _bannerMonto(ordenTrabajo),
                ],
                const SizedBox(height: 18),
                _seccionPagos(ordenTrabajo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(OrdenTrabajo ordenTrabajo, Perfil? perfil) {
    final theme = Theme.of(context);
    final esAdmin = perfil?.rol.isAdmin ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 4, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ordenTrabajo.vehiculoResumen,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                _ChipEstado(estado: ordenTrabajo.estadoKanban),
              ],
            ),
          ),
          // Menú de acciones destructivas (solo admin). Apartado del flujo
          // principal — archivar/cerrar trato siguen siendo botones en el
          // footer; aquí solo Eliminar para no tentar al borrado accidental.
          if (esAdmin)
            PopupMenuButton<String>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'eliminar') _eliminarOrden(ordenTrabajo);
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'eliminar',
                  enabled: !_ocupado,
                  child: Row(
                    children: const [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Eliminar orden',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarOrden(OrdenTrabajo orden) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cliente = ref.read(clientesByIdProvider)[orden.clienteId];
    final nombre = cliente?.nombre ?? 'el cliente';
    final pagosDeOrden =
        ref.read(pagosByOrdenIdProvider)[orden.id] ?? const <Pago>[];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar orden'),
        content: Text(
          '¿Eliminar la orden de $nombre? Esta acción oculta la orden de '
          'todas las vistas (incluido el tablero de archivadas). '
          '${pagosDeOrden.isEmpty ? '' : 'Tiene ${pagosDeOrden.length} pago${pagosDeOrden.length == 1 ? '' : 's'} registrado${pagosDeOrden.length == 1 ? '' : 's'} que también quedará${pagosDeOrden.length == 1 ? '' : 'n'} oculto${pagosDeOrden.length == 1 ? '' : 's'}. '}'
          'Recuperable por SQL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _ocupado = true);
    try {
      await ref
          .read(ordenesTrabajoControllerProvider)
          .eliminarOrdenTrabajo(orden);
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(content: Text('Orden de $nombre eliminada.')),
      );
    } catch (e) {
      if (mounted) setState(() => _ocupado = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la orden: $e')),
      );
    }
  }

  // ───────────────────────── Secciones ─────────────────────────

  Widget _seccionCliente(OrdenTrabajo orden, Cliente? cliente) {
    return _seccion(
      'Cliente',
      Column(
        children: [
          _filaDato(Icons.person_outline_rounded, 'Nombre',
              cliente?.nombre ?? 'Cliente desconocido'),
          _filaDato(Icons.phone_outlined, 'Teléfono',
              cliente?.telefono ?? 'No registrado'),
          _filaDato(Icons.location_on_outlined, 'Dirección',
              cliente?.direccion ?? 'No registrada'),
          _filaDato(Icons.email_outlined, 'Email',
              cliente?.email ?? 'No registrado'),
        ],
      ),
      trailing: TextButton.icon(
        onPressed: _ocupado ? null : () => _cambiarCliente(orden),
        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
        label: const Text('Cambiar'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _seccionVehiculo(OrdenTrabajo e) {
    return _seccion(
      'Vehículo',
      Column(
        children: [
          _filaDato(Icons.directions_car_outlined, 'Modelo', e.vehiculoResumen),
          _filaDato(Icons.confirmation_number_outlined, 'VIN',
              e.vehiculoVin ?? 'No registrado'),
        ],
      ),
      trailing: TextButton.icon(
        onPressed: _ocupado ? null : () => _editarVehiculo(e),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Editar'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Future<void> _editarVehiculo(OrdenTrabajo orden) async {
    setState(() => _ocupado = true);
    await mostrarFormularioVehiculo(context, orden);
    if (mounted) setState(() => _ocupado = false);
  }

  Widget _seccionFotos(OrdenTrabajo e) {
    final fotos = [
      for (final n in e.fotosUrls) FotoRef(nombre: n, bytes: _fotosLocales[n]),
    ];
    return _seccion(
      'Fotografías (${e.fotosUrls.length})',
      SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: e.fotosUrls.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            if (i == e.fotosUrls.length) {
              return _TileAgregar(
                etiqueta: 'Agregar\nfoto',
                onTap: _ocupado ? null : () => _pickFoto(e),
              );
            }
            return _TileFoto(
              nombre: e.fotosUrls[i],
              bytes: _fotosLocales[e.fotosUrls[i]],
              onTap: () => mostrarVisorImagenes(
                context,
                fotos: fotos,
                indiceInicial: i,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _seccionCotizaciones(OrdenTrabajo e, Perfil? perfil) {
    final theme = Theme.of(context);
    final esAdmin = perfil?.rol.isAdmin ?? false;

    return _seccion(
      'Estimados en PDF (${e.pdfsUrls.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e.pdfsUrls.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Aún no hay Estimados cargados.',
                  style: theme.textTheme.bodyMedium),
            ),
          for (int i = 0; i < e.pdfsUrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FilaCotizacion(
                cotizacion: e.pdfsUrls[i],
                onAbrir: () => mostrarVisorPdf(
                  context,
                  PdfRef(
                    titulo: e.pdfsUrls[i].titulo,
                    url: e.pdfsUrls[i].url,
                    bytes: _pdfsLocales[e.pdfsUrls[i].url],
                  ),
                ),
                onEliminar:
                    esAdmin && !_ocupado ? () => _quitarCotizacion(e, i) : null,
              ),
            ),
          const SizedBox(height: 4),
          if (_formCotizAbierto)
            _FormCotizacion(
              tituloCtrl: _tituloCtrl,
              montoCtrl: _montoCtrl,
              pdfNombre: _pdfNombre,
              ocupado: _ocupado,
              onElegirPdf: _pickPdf,
              onCancelar: _cerrarForm,
              onAgregar: () => _agregarCotizacion(e),
            )
          else
            OutlinedButton.icon(
              onPressed:
                  _ocupado ? null : () => setState(() => _formCotizAbierto = true),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Subir Estimado PDF'),
            ),
        ],
      ),
    );
  }

  Widget _seccionNotas(OrdenTrabajo e) {
    final theme = Theme.of(context);
    return _seccion(
      'Notas (${e.notas.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e.notas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Aún no hay notas. Agrega detalles del trabajo abajo.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (int i = 0; i < e.notas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FilaNota(
                nota: e.notas[i],
                ocupado: _ocupado,
                onEliminar: _ocupado ? null : () => _quitarNota(e, i),
                onEditar: _ocupado ? null : (t) => _editarNota(e, i, t),
              ),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _notaCtrl,
            enabled: !_ocupado,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Escribe una nota sobre este trabajo…',
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _ocupado ? null : () => _agregarNota(e),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Agregar nota'),
          ),
        ],
      ),
    );
  }

  Widget _bannerMonto(OrdenTrabajo e) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: estiloDeEstado(e.estadoKanban).color,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: AppColors.onPrimary, size: 20),
          const SizedBox(width: 10),
          Text('Monto aprobado',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.onPrimary)),
          const Spacer(),
          Text(e.montoAprobadoFormateado,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: AppColors.onPrimary)),
        ],
      ),
    );
  }

  Widget _seccionPagos(OrdenTrabajo orden) {
    final theme = Theme.of(context);
    final pagos =
        ref.watch(pagosByOrdenIdProvider)[orden.id] ?? const <Pago>[];
    // Los cancelados NO suman al saldo (siguen visibles, pero tachados).
    final totalCobrado = pagos
        .where((p) => !p.estaCancelado)
        .fold<double>(0, (acc, p) => acc + p.monto);
    final aprobado = orden.montoAprobado;
    final restante = aprobado == null ? null : aprobado - totalCobrado;
    final pagadoCompleto =
        aprobado != null && restante != null && restante <= 0;

    return _seccion(
      'Pagos (${pagos.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resumen
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pagadoCompleto
                  ? const Color(0xFFD4ECE8)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: pagadoCompleto
                    ? const Color(0xFF1C8175)
                    : AppColors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pagadoCompleto
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: pagadoCompleto
                      ? const Color(0xFF1C8175)
                      : AppColors.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pagadoCompleto
                            ? 'Pagado completo'
                            : aprobado == null
                                ? 'Cobrado: ${_fmt(totalCobrado)}'
                                : 'Cobrado ${_fmt(totalCobrado)} '
                                    'de ${_fmt(aprobado)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: pagadoCompleto
                              ? const Color(0xFF1C8175)
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (aprobado != null && !pagadoCompleto)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Restante: ${_fmt(restante!.clamp(0, double.infinity).toDouble())}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Listado de pagos
          if (pagos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Aún no se registraron pagos para esta orden.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final p in pagos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FilaPago(
                  pago: p,
                  ocupado: _ocupado,
                  onEditar: () => _editarPago(orden, p),
                  onEliminar: () => _eliminarPago(p),
                ),
              ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed:
                _ocupado ? null : () => _registrarPago(orden, restante),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Registrar pago'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }

  /// Formato breve de monto reusable dentro del modal.
  String _fmt(double monto) {
    final entero = monto.round();
    final texto = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${AppConfig.currencySymbol}$texto';
  }

  Future<void> _registrarPago(OrdenTrabajo orden, double? restante) async {
    final restanteValor = restante ?? 0;
    await mostrarFormularioPago(
      context,
      orden: orden,
      restante: restanteValor < 0 ? 0 : restanteValor,
    );
  }

  Future<void> _editarPago(OrdenTrabajo orden, Pago pago) async {
    await mostrarFormularioPago(
      context,
      orden: orden,
      restante: 0, // no aplica en edición; el monto viene del pago
      pagoAEditar: pago,
    );
  }

  Future<void> _eliminarPago(Pago pago) async {
    if (pago.estaCancelado) return; // ya cancelado, no se vuelve a tocar
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmarCancelarPagoDialog(pago: pago),
    );
    if (motivo == null) return; // canceló el diálogo
    setState(() => _ocupado = true);
    await ref.read(pagosControllerProvider).cancelarPago(pago, motivo);
    if (mounted) setState(() => _ocupado = false);
  }

  Widget? _footer(OrdenTrabajo e, Cliente? cliente, Perfil? perfil) {
    final esAdmin = perfil?.rol.isAdmin ?? false;
    final esEsperando =
        e.estadoKanban == EstadoKanban.esperandoAprobacion;

    final botones = <Widget>[];

    if (esAdmin) {
      botones.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _ocupado
                ? null
                : () => e.archivado ? _restaurar(e) : _archivar(e, cliente),
            icon: Icon(
              e.archivado
                  ? Icons.unarchive_outlined
                  : Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text(e.archivado ? 'Restaurar' : 'Archivar'),
          ),
        ),
      );
    }

    if (esEsperando) {
      if (botones.isNotEmpty) botones.add(const SizedBox(width: 12));
      botones.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _ocupado ? null : () => _cerrarTrato(e),
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: const Text('Cerrar Trato'),
          ),
        ),
      );
    }

    if (botones.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(children: botones),
    );
  }

  Widget _noDisponible() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 44, color: AppColors.outline),
          const SizedBox(height: 12),
          Text('Esta orden ya no está disponible',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Helpers de UI ─────────────────────────

  Widget _seccion(String titulo, Widget hijo, {Widget? trailing}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titulo.toUpperCase(),
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 10),
        hijo,
      ],
    );
  }

  Widget _filaDato(IconData icono, String etiqueta, String valor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: theme.textTheme.labelMedium),
                const SizedBox(height: 1),
                Text(valor, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Acciones ─────────────────────────

  void _cerrarForm() {
    _tituloCtrl.clear();
    _montoCtrl.clear();
    setState(() {
      _pdfNombre = null;
      _formCotizAbierto = false;
    });
  }

  Future<void> _pickPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (!mounted || res == null || res.files.isEmpty) return;
      final archivo = res.files.first;
      // Se guardan los bytes para poder mostrar el PDF de verdad en el visor.
      if (archivo.bytes != null) {
        _pdfsLocales[archivo.name] = archivo.bytes!;
      }
      setState(() => _pdfNombre = archivo.name);
    } catch (_) {
      _aviso('No se pudo abrir el selector de archivos.');
    }
  }

  Future<void> _pickFoto(OrdenTrabajo e) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted || res == null || res.files.isEmpty) return;
      final archivo = res.files.first;
      if (archivo.bytes == null) {
        _aviso('No se pudieron leer los bytes del archivo.');
        return;
      }
      setState(() => _ocupado = true);
      // Cachear bytes localmente: el visor full-screen los puede consumir
      // mientras la red termina de subir, dándole al usuario respuesta
      // visual inmediata.
      _fotosLocales[archivo.name] = archivo.bytes!;
      // Subida a Storage. En mock devuelve el filename; en Supabase
      // devuelve la URL pública del bucket.
      final url = await ref
          .read(storageRepositoryProvider)
          .subirFoto(
            bytes: archivo.bytes!,
            nombreArchivo: archivo.name,
            ordenId: e.id,
          );
      await ref
          .read(ordenesTrabajoControllerProvider)
          .agregarFoto(e, url);
      // Reasocia los bytes locales a la URL nueva, así el visor de la
      // sesión los muestra al instante (sin esperar la descarga).
      _fotosLocales[url] = archivo.bytes!;
      // Auditoría (fire-and-forget).
      ref.read(auditLoggerProvider).log(
        accion: AuditAccion.subirFoto,
        entidad: 'orden_trabajo',
        entidadId: e.id,
        datos: {'archivo': archivo.name},
      );
      if (mounted) setState(() => _ocupado = false);
    } catch (err) {
      if (mounted) setState(() => _ocupado = false);
      _aviso('No se pudo subir la foto: $err');
    }
  }

  Future<void> _agregarCotizacion(OrdenTrabajo e) async {
    final titulo = _tituloCtrl.text.trim();
    final monto = double.tryParse(
        _montoCtrl.text.replaceAll(',', '').replaceAll(' ', '').trim());

    if (titulo.isEmpty) {
      _aviso('Escribe un título para el Estimado (ej. OEM).');
      return;
    }
    if (monto == null || monto <= 0) {
      _aviso('Escribe un monto válido mayor a 0.');
      return;
    }

    setState(() => _ocupado = true);
    try {
      // Si el usuario seleccionó un PDF, lo subimos AHORA (no en
      // `_pickPdf`) — así si después cancela el formulario, no quedan
      // archivos huérfanos en Storage. La URL resultante (mock = filename,
      // Supabase = url pública del bucket) es la que persiste en la BD.
      String urlPdf;
      if (_pdfNombre != null && _pdfsLocales[_pdfNombre!] != null) {
        // Usamos el título del estimado como nombre del archivo para que
        // sea legible en Supabase Storage (ej. "OEM.pdf", "Alternativo.pdf")
        // en lugar del nombre original del archivo descargado del disco.
        urlPdf = await ref.read(storageRepositoryProvider).subirPdf(
              bytes: _pdfsLocales[_pdfNombre!]!,
              nombreArchivo: '$titulo.pdf',
              ordenId: e.id,
            );
        // Reasocia bytes a la URL nueva para que el visor PDF integrado
        // los muestre al instante en la misma sesión sin descarga extra.
        _pdfsLocales[urlPdf] = _pdfsLocales[_pdfNombre!]!;
      } else {
        // Sin PDF adjunto: usamos un placeholder. El visor caerá al
        // sample PDF demo (rama final del `visor_pdf.dart`).
        urlPdf =
            'cotizacion_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      final cotizacion = PdfCotizacion(
        titulo: titulo,
        url: urlPdf,
        montoSugerido: monto,
      );
      await ref
          .read(ordenesTrabajoControllerProvider)
          .agregarCotizacion(e, cotizacion);
      // Auditoría (fire-and-forget).
      ref.read(auditLoggerProvider).log(
        accion: AuditAccion.subirPdf,
        entidad: 'orden_trabajo',
        entidadId: e.id,
        datos: {'titulo': titulo, 'monto': monto},
      );
      if (!mounted) return;
      setState(() => _ocupado = false);
      _cerrarForm();
      _aviso('Estimado "$titulo" agregado.');
    } catch (err) {
      if (mounted) setState(() => _ocupado = false);
      _aviso('No se pudo guardar el Estimado: $err');
    }
  }

  Future<void> _quitarCotizacion(OrdenTrabajo e, int indice) async {
    setState(() => _ocupado = true);
    await ref.read(ordenesTrabajoControllerProvider).quitarCotizacion(e, indice);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _agregarNota(OrdenTrabajo e) async {
    final texto = _notaCtrl.text.trim();
    if (texto.isEmpty) {
      _aviso('Escribe el contenido de la nota.');
      return;
    }
    setState(() => _ocupado = true);
    await ref.read(ordenesTrabajoControllerProvider).agregarNota(
          e,
          Nota(texto: texto, fecha: DateTime.now()),
        );
    if (!mounted) return;
    _notaCtrl.clear();
    setState(() => _ocupado = false);
  }

  Future<void> _quitarNota(OrdenTrabajo e, int indice) async {
    setState(() => _ocupado = true);
    await ref.read(ordenesTrabajoControllerProvider).quitarNota(e, indice);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _editarNota(OrdenTrabajo e, int indice, String nuevoTexto) async {
    if (nuevoTexto.trim().isEmpty) return;
    setState(() => _ocupado = true);
    await ref
        .read(ordenesTrabajoControllerProvider)
        .editarNota(e, indice, nuevoTexto.trim());
    if (mounted) setState(() => _ocupado = false);
  }

  /// Abre el selector para reasignar la orden a otro cliente del directorio.
  /// Pide confirmación antes de aplicar el cambio.
  Future<void> _cambiarCliente(OrdenTrabajo orden) async {
    final messenger = ScaffoldMessenger.of(context);
    final nuevoCliente = await mostrarSelectorCliente(context);
    if (nuevoCliente == null) return;
    if (nuevoCliente.id == orden.clienteId) {
      _aviso('Ese cliente ya estaba asignado a esta orden.');
      return;
    }
    if (!mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reasignar orden'),
        content: Text(
          '¿Cambiar el cliente de esta orden a "${nuevoCliente.nombre}"? '
          'Esta acción reescribe la información de contacto que se mostrará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reasignar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _ocupado = true);
    await ref
        .read(ordenesTrabajoControllerProvider)
        .cambiarCliente(orden, nuevoCliente.id);
    if (mounted) setState(() => _ocupado = false);
    messenger.showSnackBar(
      SnackBar(content: Text('Orden reasignada a ${nuevoCliente.nombre}.')),
    );
  }

  Future<void> _archivar(OrdenTrabajo e, Cliente? cliente) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final nombre = cliente?.nombre ?? 'el cliente';
    setState(() => _ocupado = true);
    await ref.read(ordenesTrabajoControllerProvider).archivar(e);
    navigator.maybePop();
    messenger.showSnackBar(
      SnackBar(content: Text('Orden de $nombre archivada.')),
    );
  }

  Future<void> _restaurar(OrdenTrabajo e) async {
    setState(() => _ocupado = true);
    await ref.read(ordenesTrabajoControllerProvider).restaurar(e);
    if (mounted) setState(() => _ocupado = false);
    _aviso('Orden restaurada al tablero.');
  }

  Future<void> _cerrarTrato(OrdenTrabajo e) async {
    final navigator = Navigator.of(context);
    final cerrado = await ejecutarCierreTrato(context, ref, e);
    if (cerrado) navigator.maybePop();
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

// ═══════════════════════ Sub-widgets ═══════════════════════

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});
  final EstadoKanban estado;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: estilo.container,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: estilo.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            estado.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: estilo.color),
          ),
        ],
      ),
    );
  }
}

class _TileFoto extends StatelessWidget {
  const _TileFoto({required this.nombre, this.bytes, this.onTap});
  final String nombre;
  final Uint8List? bytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: 84,
        height: 88,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _imagen(),
            // Indicador de que la foto se puede ampliar.
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.zoom_in_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagen() {
    // Foto recién elegida en esta sesión: se muestra de verdad.
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover, width: 84, height: 88);
    }
    // URL real, o nombre de archivo usado como semilla de una fotografía.
    return Image.network(
      resolverUrlFoto(nombre, tamano: 240),
      fit: BoxFit.cover,
      width: 84,
      height: 88,
      errorBuilder: (_, __, ___) => const _PlaceholderFoto(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _PlaceholderFoto(),
    );
  }
}

class _PlaceholderFoto extends StatelessWidget {
  const _PlaceholderFoto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_outlined,
          color: AppColors.onSurfaceVariant, size: 26),
    );
  }
}

class _TileAgregar extends StatelessWidget {
  const _TileAgregar({required this.etiqueta, required this.onTap});
  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: 84,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded,
                color: AppColors.primary, size: 24),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaCotizacion extends StatelessWidget {
  const _FilaCotizacion({
    required this.cotizacion,
    this.onAbrir,
    this.onEliminar,
  });
  final PdfCotizacion cotizacion;

  /// Abre el PDF en el visor integrado.
  final VoidCallback? onAbrir;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.primaryFixed,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 18, color: AppColors.onPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cotizacion.titulo,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(cotizacion.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.onPrimaryContainer)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(cotizacion.montoFormateado,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.onPrimaryContainer)),
              if (onEliminar != null)
                IconButton(
                  tooltip: 'Quitar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.onPrimaryContainer),
                  onPressed: onEliminar,
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.onPrimaryContainer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaNota extends StatefulWidget {
  const _FilaNota({
    required this.nota,
    required this.ocupado,
    this.onEliminar,
    this.onEditar,
  });

  final Nota nota;
  final bool ocupado;
  final VoidCallback? onEliminar;

  /// Llamado con el nuevo texto cuando el usuario guarda la edición.
  final void Function(String nuevoTexto)? onEditar;

  @override
  State<_FilaNota> createState() => _FilaNotaState();
}

class _FilaNotaState extends State<_FilaNota> {
  bool _editando = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.nota.texto);
  }

  @override
  void didUpdateWidget(_FilaNota oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza si la nota fue actualizada externamente mientras no editamos.
    if (!_editando && oldWidget.nota.texto != widget.nota.texto) {
      _ctrl.text = widget.nota.texto;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.fromLTRB(12, _editando ? 12 : 10, 6, _editando ? 12 : 10),
      decoration: BoxDecoration(
        color: _editando
            ? AppColors.primaryFixed
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: _editando ? AppColors.primary : AppColors.outlineVariant,
          width: _editando ? 1.5 : 1,
        ),
      ),
      child: _editando ? _modoEdicion() : _modoVista(),
    );
  }

  Widget _modoVista() {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.sticky_note_2_outlined,
              size: 16, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.nota.texto, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(widget.nota.fechaFormateada,
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        // Botón editar
        if (widget.onEditar != null)
          IconButton(
            tooltip: 'Editar nota',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined,
                size: 17, color: AppColors.onSurfaceVariant),
            onPressed: widget.ocupado
                ? null
                : () {
                    _ctrl.text = widget.nota.texto;
                    setState(() => _editando = true);
                  },
          ),
        // Botón eliminar
        if (widget.onEliminar != null)
          IconButton(
            tooltip: 'Eliminar nota',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
            onPressed: widget.onEliminar,
          ),
      ],
    );
  }

  Widget _modoEdicion() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Editando nota',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Escribe el contenido de la nota…',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _editando = false),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final texto = _ctrl.text.trim();
                  if (texto.isNotEmpty) {
                    widget.onEditar?.call(texto);
                    setState(() => _editando = false);
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormCotizacion extends StatelessWidget {
  const _FormCotizacion({
    required this.tituloCtrl,
    required this.montoCtrl,
    required this.pdfNombre,
    required this.ocupado,
    required this.onElegirPdf,
    required this.onCancelar,
    required this.onAgregar,
  });

  final TextEditingController tituloCtrl;
  final TextEditingController montoCtrl;
  final String? pdfNombre;
  final bool ocupado;
  final VoidCallback onElegirPdf;
  final VoidCallback onCancelar;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nuevo Estimado', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: tituloCtrl,
            enabled: !ocupado,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ej. OEM, Aftermarket…',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: montoCtrl,
            enabled: !ocupado,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto sugerido',
              prefixText: '${AppConfig.currencySymbol} ',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: ocupado ? null : onElegirPdf,
            icon: Icon(
              pdfNombre == null
                  ? Icons.attach_file_rounded
                  : Icons.check_circle_rounded,
              size: 18,
              color: pdfNombre == null ? null : AppColors.primary,
            ),
            label: Text(
              pdfNombre ?? 'Seleccionar archivo PDF',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: ocupado ? null : onCancelar,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: ocupado ? null : onAgregar,
                  child: ocupado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('Agregar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de un pago registrado. Si está cancelado, se renderiza tachado
/// y con un badge "CANCELADO" + motivo, sin botones de editar/cancelar.
class _FilaPago extends StatelessWidget {
  const _FilaPago({
    required this.pago,
    required this.ocupado,
    required this.onEditar,
    required this.onEliminar,
  });

  final Pago pago;
  final bool ocupado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelado = pago.estaCancelado;
    final nota = pago.notas.isEmpty ? null : pago.notas.first.texto;

    final colorTexto = cancelado
        ? AppColors.onSurfaceVariant
        : theme.colorScheme.primary;
    final colorTextoSec =
        cancelado ? AppColors.onSurfaceVariant : AppColors.onSurface;
    final tachado = cancelado ? TextDecoration.lineThrough : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: cancelado
            ? AppColors.surfaceContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: cancelado
              ? AppColors.outlineVariant
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              cancelado
                  ? Icons.cancel_outlined
                  : Icons.payments_outlined,
              size: 18,
              color: cancelado ? AppColors.error : colorTexto,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pago.montoFormateado,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorTexto,
                          fontWeight: FontWeight.w700,
                          decoration: tachado,
                          decorationColor: AppColors.error,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                    Text(
                      pago.fechaFormateada,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorTextoSec,
                        decoration: tachado,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Chip "CANCELADO" en rojo
                      if (cancelado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadii.full),
                          ),
                          child: Text(
                            'CANCELADO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      // Chip de método de pago
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cancelado
                              ? AppColors.surfaceContainerLow
                              : theme.colorScheme.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          pago.metodoPagoLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cancelado
                                ? AppColors.onSurfaceVariant
                                : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            decoration: tachado,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (nota != null && nota.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      nota,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorTextoSec,
                        decoration: tachado,
                      ),
                    ),
                  ),
                // Motivo de cancelación (solo si está cancelado)
                if (cancelado &&
                    (pago.motivoCancelacion?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Motivo: ${pago.motivoCancelacion!.trim()}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Acciones solo cuando NO está cancelado
          if (!cancelado) ...[
            IconButton(
              tooltip: 'Editar pago',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined,
                  size: 17, color: AppColors.onSurfaceVariant),
              onPressed: ocupado ? null : onEditar,
            ),
            IconButton(
              tooltip: 'Cancelar pago',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.onSurfaceVariant),
              onPressed: ocupado ? null : onEliminar,
            ),
          ] else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Diálogo de cancelación de pago. Devuelve el motivo (String) si el
/// usuario confirma, o `null` si vuelve atrás.
///
/// Doble fricción anti-accidente: (1) hay que escribir un motivo no
/// vacío; (2) hay que tipear la palabra "cancelar". Solo entonces se
/// habilita el botón rojo.
class _ConfirmarCancelarPagoDialog extends StatefulWidget {
  const _ConfirmarCancelarPagoDialog({required this.pago});
  final Pago pago;

  @override
  State<_ConfirmarCancelarPagoDialog> createState() =>
      _ConfirmarCancelarPagoDialogState();
}

class _ConfirmarCancelarPagoDialogState
    extends State<_ConfirmarCancelarPagoDialog> {
  final _motivo = TextEditingController();
  final _confirmacion = TextEditingController();
  static const String _palabra = 'cancelar';

  @override
  void dispose() {
    _motivo.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _motivoOk => _motivo.text.trim().isNotEmpty;
  bool get _confirmacionOk =>
      _confirmacion.text.trim().toLowerCase() == _palabra;
  bool get _puedeConfirmar => _motivoOk && _confirmacionOk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pago = widget.pago;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Cancelar pago',
                style: theme.textTheme.headlineMedium),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El pago de ${pago.montoFormateado} (${pago.metodoPagoLabel}) '
                'del ${pago.fechaFormateada} dejará de contar para el saldo. '
                'Sigue visible en el historial, pero tachado. La orden '
                'recupera "Restante" si estaba pagada completa.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _motivo,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación *',
                  hintText: 'Ej. Cliente desistió, transferencia rebotó…',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Para confirmar, escribí "$_palabra" abajo:',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmacion,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _palabra,
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Atrás'),
        ),
        ElevatedButton(
          onPressed: _puedeConfirmar
              ? () => Navigator.of(context).pop(_motivo.text.trim())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            disabledBackgroundColor:
                AppColors.error.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.onError,
          ),
          child: const Text('Cancelar pago'),
        ),
      ],
    );
  }
}
