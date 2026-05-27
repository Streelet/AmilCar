import 'dart:typed_data';

import 'storage_repository.dart';

/// Implementación de [StorageRepository] para MODO MOCKUP.
///
/// No persiste bytes: simula el path que generaría Supabase Storage y lo
/// devuelve como "URL". La UI guarda los bytes en memoria por la duración
/// de la sesión. Sirve para probar el flujo completo sin internet.
class MockStorageRepository implements StorageRepository {
  Future<void> _simularLatencia() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  @override
  Future<String> subirFoto({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  }) async {
    await _simularLatencia();
    return _construirPathMock(ordenId, nombreArchivo);
  }

  @override
  Future<String> subirPdf({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  }) async {
    await _simularLatencia();
    return _construirPathMock(ordenId, nombreArchivo);
  }

  /// Mismo esquema que [SupabaseStorageRepository._construirPath] para que
  /// los datos mock sean representativos.
  String _construirPathMock(String ordenId, String nombreArchivo) {
    final now = DateTime.now();
    final mes =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final shortId = ordenId.length >= 8 ? ordenId.substring(0, 8) : ordenId;
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final safe =
        nombreArchivo.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'mock/$mes/$shortId/${ts}_$safe';
  }
}
