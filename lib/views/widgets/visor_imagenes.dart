import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Referencia a una fotografía: bytes en memoria (recién elegida en esta
/// sesión) o un nombre de archivo / URL.
class FotoRef {
  const FotoRef({required this.nombre, this.bytes});

  /// Nombre de archivo o URL http.
  final String nombre;

  /// Bytes de la imagen, si se eligió en esta sesión.
  final Uint8List? bytes;
}

/// Resuelve la URL de una fotografía a partir de su nombre.
///
/// Si ya es una URL http se usa tal cual; si es un nombre de archivo (datos
/// de demostración) se genera una imagen estable de Picsum.
String resolverUrlFoto(String nombre, {int tamano = 1280}) {
  if (nombre.startsWith('http')) return nombre;
  return 'https://picsum.photos/seed/${Uri.encodeComponent(nombre)}/$tamano/$tamano';
}

/// Abre el visor de imágenes a pantalla completa, con zoom y desplazamiento.
Future<void> mostrarVisorImagenes(
  BuildContext context, {
  required List<FotoRef> fotos,
  int indiceInicial = 0,
}) {
  if (fotos.isEmpty) return Future<void>.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) =>
          _VisorImagenes(fotos: fotos, indiceInicial: indiceInicial),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _VisorImagenes extends StatefulWidget {
  const _VisorImagenes({required this.fotos, required this.indiceInicial});

  final List<FotoRef> fotos;
  final int indiceInicial;

  @override
  State<_VisorImagenes> createState() => _VisorImagenesState();
}

class _VisorImagenesState extends State<_VisorImagenes> {
  late int _indice;

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, widget.fotos.length - 1);
  }

  void _ir(int delta) {
    setState(
      () => _indice = (_indice + delta).clamp(0, widget.fotos.length - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayVarias = widget.fotos.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen actual con zoom. La key reinicia el zoom al cambiar de foto.
          Positioned.fill(
            child: _PaginaImagen(
              key: ValueKey(_indice),
              foto: widget.fotos[_indice],
            ),
          ),
          // Flechas de navegación entre fotos.
          if (hayVarias && _indice > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _BotonCircular(
                  icono: Icons.chevron_left_rounded,
                  onTap: () => _ir(-1),
                ),
              ),
            ),
          if (hayVarias && _indice < widget.fotos.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _BotonCircular(
                  icono: Icons.chevron_right_rounded,
                  onTap: () => _ir(1),
                ),
              ),
            ),
          // Barra superior: cerrar + contador.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    _BotonCircular(
                      icono: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (hayVarias)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          '${_indice + 1} / ${widget.fotos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Pista de uso.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Center(
                  child: Text(
                    'Pellizca o toca dos veces para hacer zoom',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una foto con [InteractiveViewer] (pellizco para zoom + arrastre) y zoom
/// con doble toque sobre el punto tocado.
class _PaginaImagen extends StatefulWidget {
  const _PaginaImagen({super.key, required this.foto});

  final FotoRef foto;

  @override
  State<_PaginaImagen> createState() => _PaginaImagenState();
}

class _PaginaImagenState extends State<_PaginaImagen> {
  final TransformationController _controlador = TransformationController();
  TapDownDetails? _ultimoTap;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alternarZoom() {
    if (_controlador.value.getMaxScaleOnAxis() > 1.05) {
      _controlador.value = Matrix4.identity();
      return;
    }
    final pos = _ultimoTap?.localPosition;
    if (pos == null) return;
    const escala = 2.6;
    // Zoom centrado en el punto tocado: matriz de escala + traslación.
    _controlador.value = Matrix4.diagonal3Values(escala, escala, 1)
      ..setTranslationRaw(
        -pos.dx * (escala - 1),
        -pos.dy * (escala - 1),
        0,
      );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _ultimoTap = d,
      onDoubleTap: _alternarZoom,
      child: InteractiveViewer(
        transformationController: _controlador,
        minScale: 1,
        maxScale: 5,
        child: Center(child: _imagen()),
      ),
    );
  }

  Widget _imagen() {
    final foto = widget.foto;
    if (foto.bytes != null) {
      return Image.memory(foto.bytes!, fit: BoxFit.contain);
    }
    return Image.network(
      resolverUrlFoto(foto.nombre),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _Cargando(),
      errorBuilder: (_, __, ___) => const _ErrorImagen(),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
      ),
    );
  }
}

class _ErrorImagen extends StatelessWidget {
  const _ErrorImagen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.6), size: 48),
          const SizedBox(height: 10),
          Text(
            'No se pudo cargar la imagen',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _BotonCircular extends StatelessWidget {
  const _BotonCircular({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icono, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
