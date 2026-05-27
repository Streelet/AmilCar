import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage_repository.dart';

/// Implementación de [StorageRepository] que sube los archivos a
/// **Supabase Storage**.
///
/// Buckets esperados (definidos en `supabase/schema.sql`):
///   - `fotos-ordenes`    (público)
///   - `cotizaciones-pdf` (público)
///
/// Convención de path:
///   `YYYY-MM/<8chars-ordenId>/<yyyyMMdd_HHmmss>_<nombre_seguro>`
///
/// Ejemplos:
///   fotos-ordenes/2026-05/3f2a1b4c/20260526_143022_foto_daño.jpg
///   cotizaciones-pdf/2026-05/3f2a1b4c/20260526_144510_OEM.pdf
///
/// El agrupamiento por mes facilita la navegación en el dashboard de
/// Supabase y las limpiezas periódicas. El short-id (8 chars) identifica
/// la orden sin revelar el UUID completo en la URL pública. El timestamp
/// garantiza unicidad y ordena cronológicamente dentro de la carpeta.
class SupabaseStorageRepository implements StorageRepository {
  static const String _bucketFotos = 'fotos-ordenes';
  static const String _bucketPdfs = 'cotizaciones-pdf';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<String> subirFoto({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  }) async {
    final path = _construirPath(ordenId, nombreArchivo);
    await _client.storage.from(_bucketFotos).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeImagen(nombreArchivo),
          ),
        );
    return _client.storage.from(_bucketFotos).getPublicUrl(path);
  }

  @override
  Future<String> subirPdf({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  }) async {
    final path = _construirPath(ordenId, nombreArchivo);
    await _client.storage.from(_bucketPdfs).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'application/pdf',
          ),
        );
    return _client.storage.from(_bucketPdfs).getPublicUrl(path);
  }

  /// Construye el path final:
  ///   `YYYY-MM/<8chars-ordenId>/<yyyyMMdd_HHmmss>_<nombre_seguro>`
  String _construirPath(String ordenId, String nombreArchivo) {
    final now = DateTime.now();
    final mes =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final shortId = ordenId.length >= 8
        ? ordenId.substring(0, 8)
        : ordenId;
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    // Solo letras, números, punto, guion, guion bajo.
    // Supabase Storage prohíbe varios caracteres especiales en paths.
    final safe =
        nombreArchivo.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    return '$mes/$shortId/${ts}_$safe';
  }

  String _contentTypeImagen(String nombreArchivo) {
    final n = nombreArchivo.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
