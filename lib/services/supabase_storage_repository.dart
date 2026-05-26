import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'storage_repository.dart';

/// Implementación de [StorageRepository] que sube los archivos a
/// **Supabase Storage**.
///
/// Buckets esperados (definidos en `supabase/schema.sql`):
///   - `fotos-ordenes`    (público)
///   - `cotizaciones-pdf` (público)
///
/// Convención de path: `<ordenId>/<uuid>_<nombre_seguro>`. Incluir el
/// `ordenId` arriba facilita auditoría (todos los archivos de una orden
/// en una "carpeta") y permite eventuales limpiezas masivas. El `uuid`
/// previene colisiones entre archivos con el mismo nombre.
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

  String _construirPath(String ordenId, String nombreArchivo) {
    final uuid = const Uuid().v4();
    // Solo letras, números, punto, guion, guion bajo en el nombre final.
    // Supabase storage prohibe varios caracteres especiales en paths.
    final safe = nombreArchivo
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$ordenId/${uuid}_$safe';
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
