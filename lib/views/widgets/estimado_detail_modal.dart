import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/estimado.dart';
import '../../models/pdf_cotizacion.dart';
import '../../models/perfil.dart';
import '../../providers/auth_provider.dart';
import '../../providers/estimados_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/estado_style.dart';
import 'aprobacion_dialog.dart';

/// Abre el modal de detalle del estimado.
///
/// El fondo (dashboard) queda difuminado (blur) mientras el modal está
/// abierto. Toda la información — vehículo, fotos, cotizaciones, subida de
/// PDFs y acciones — vive aquí.
Future<void> mostrarDetalleEstimado(BuildContext context, String estimadoId) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'Detalle del estimado',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _ModalDetalle(estimadoId: estimadoId),
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
  const _ModalDetalle({required this.estimadoId});
  final String estimadoId;

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
        Center(child: _TarjetaDetalle(estimadoId: estimadoId)),
      ],
    );
  }
}

class _TarjetaDetalle extends ConsumerStatefulWidget {
  const _TarjetaDetalle({required this.estimadoId});
  final String estimadoId;

  @override
  ConsumerState<_TarjetaDetalle> createState() => _TarjetaDetalleState();
}

class _TarjetaDetalleState extends ConsumerState<_TarjetaDetalle> {
  bool _formCotizAbierto = false;
  bool _ocupado = false;
  String? _pdfNombre;

  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();

  /// Bytes de las fotos elegidas en esta sesión, para mostrarlas de verdad.
  final Map<String, Uint8List> _fotosLocales = {};

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimados =
        ref.watch(estimadosStreamProvider).valueOrNull ?? const <Estimado>[];
    final perfil = ref.watch(currentPerfilProvider);
    final estimado = estimados
        .cast<Estimado?>()
        .firstWhere((e) => e!.id == widget.estimadoId, orElse: () => null);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, escala, child) =>
          Transform.scale(scale: escala, child: child),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 540,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            clipBehavior: Clip.antiAlias,
            child: estimado == null
                ? _noDisponible()
                : _tarjeta(estimado, perfil),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Estructura ─────────────────────────

  Widget _tarjeta(Estimado estimado, Perfil? perfil) {
    final acciones = _footer(estimado, perfil);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(estimado),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seccionCliente(estimado),
                const SizedBox(height: 18),
                _seccionVehiculo(estimado),
                const SizedBox(height: 18),
                _seccionFotos(estimado),
                const SizedBox(height: 18),
                _seccionCotizaciones(estimado, perfil),
                if (estimado.montoAprobado != null) ...[
                  const SizedBox(height: 18),
                  _bannerMonto(estimado),
                ],
              ],
            ),
          ),
        ),
        if (acciones != null) acciones,
      ],
    );
  }

  Widget _header(Estimado estimado) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
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
                Text(estimado.vehiculoResumen,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                _ChipEstado(estado: estimado.estadoKanban),
              ],
            ),
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

  // ───────────────────────── Secciones ─────────────────────────

  Widget _seccionCliente(Estimado e) {
    return _seccion(
      'Cliente',
      Column(
        children: [
          _filaDato(Icons.person_outline_rounded, 'Nombre', e.clienteNombre),
          _filaDato(Icons.phone_outlined, 'Teléfono',
              e.telefono ?? 'No registrado'),
          _filaDato(Icons.location_on_outlined, 'Dirección / auxilio vial',
              e.direccion ?? 'No registrada'),
        ],
      ),
    );
  }

  Widget _seccionVehiculo(Estimado e) {
    return _seccion(
      'Vehículo',
      Column(
        children: [
          _filaDato(Icons.directions_car_outlined, 'Modelo', e.vehiculoResumen),
          _filaDato(Icons.confirmation_number_outlined, 'VIN',
              e.vehiculoVin ?? 'No registrado'),
        ],
      ),
    );
  }

  Widget _seccionFotos(Estimado e) {
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
            );
          },
        ),
      ),
    );
  }

  Widget _seccionCotizaciones(Estimado e, Perfil? perfil) {
    final theme = Theme.of(context);
    final esAdmin = perfil?.rol.isAdmin ?? false;

    return _seccion(
      'Cotizaciones en PDF (${e.pdfsUrls.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e.pdfsUrls.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Aún no hay cotizaciones cargadas.',
                  style: theme.textTheme.bodyMedium),
            ),
          for (int i = 0; i < e.pdfsUrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FilaCotizacion(
                cotizacion: e.pdfsUrls[i],
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
              label: const Text('Subir cotización PDF'),
            ),
        ],
      ),
    );
  }

  Widget _bannerMonto(Estimado e) {
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

  Widget? _footer(Estimado e, Perfil? perfil) {
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
                : () => e.archivado ? _restaurar(e) : _archivar(e),
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

  Widget _seccion(String titulo, Widget hijo) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo.toUpperCase(),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.primary)),
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
      );
      if (!mounted || res == null || res.files.isEmpty) return;
      setState(() => _pdfNombre = res.files.first.name);
    } catch (_) {
      _aviso('No se pudo abrir el selector de archivos.');
    }
  }

  Future<void> _pickFoto(Estimado e) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted || res == null || res.files.isEmpty) return;
      final archivo = res.files.first;
      if (archivo.bytes != null) {
        _fotosLocales[archivo.name] = archivo.bytes!;
      }
      setState(() => _ocupado = true);
      await ref.read(estimadosControllerProvider).agregarFoto(e, archivo.name);
      if (mounted) setState(() => _ocupado = false);
    } catch (_) {
      if (mounted) setState(() => _ocupado = false);
      _aviso('No se pudo adjuntar la foto.');
    }
  }

  Future<void> _agregarCotizacion(Estimado e) async {
    final titulo = _tituloCtrl.text.trim();
    final monto = double.tryParse(
        _montoCtrl.text.replaceAll(',', '').replaceAll(' ', '').trim());

    if (titulo.isEmpty) {
      _aviso('Escribe un título para la cotización (ej. OEM).');
      return;
    }
    if (monto == null || monto <= 0) {
      _aviso('Escribe un monto válido mayor a 0.');
      return;
    }

    setState(() => _ocupado = true);
    final cotizacion = PdfCotizacion(
      titulo: titulo,
      url: _pdfNombre ?? 'cotizacion_${DateTime.now().millisecondsSinceEpoch}.pdf',
      montoSugerido: monto,
    );
    await ref.read(estimadosControllerProvider).agregarCotizacion(e, cotizacion);
    if (!mounted) return;
    setState(() => _ocupado = false);
    _cerrarForm();
    _aviso('Cotización "$titulo" agregada.');
  }

  Future<void> _quitarCotizacion(Estimado e, int indice) async {
    setState(() => _ocupado = true);
    await ref.read(estimadosControllerProvider).quitarCotizacion(e, indice);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _archivar(Estimado e) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _ocupado = true);
    await ref.read(estimadosControllerProvider).archivar(e);
    navigator.maybePop();
    messenger.showSnackBar(
      SnackBar(content: Text('Orden de ${e.clienteNombre} archivada.')),
    );
  }

  Future<void> _restaurar(Estimado e) async {
    setState(() => _ocupado = true);
    await ref.read(estimadosControllerProvider).restaurar(e);
    if (mounted) setState(() => _ocupado = false);
    _aviso('Orden restaurada al tablero.');
  }

  Future<void> _cerrarTrato(Estimado e) async {
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
  const _TileFoto({required this.nombre, this.bytes});
  final String nombre;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: _imagen(),
    );
  }

  Widget _imagen() {
    // Foto recién elegida en esta sesión: se muestra de verdad.
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover, width: 84, height: 88);
    }
    // URL real, o nombre de archivo usado como semilla de una fotografía.
    final url = nombre.startsWith('http')
        ? nombre
        : 'https://picsum.photos/seed/${Uri.encodeComponent(nombre)}/240/240';
    return Image.network(
      url,
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
  const _FilaCotizacion({required this.cotizacion, this.onEliminar});
  final PdfCotizacion cotizacion;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined,
              size: 18, color: AppColors.onPrimaryContainer),
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
            ),
        ],
      ),
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
          Text('Nueva cotización', style: theme.textTheme.titleMedium),
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
