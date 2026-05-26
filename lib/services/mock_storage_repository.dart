import 'dart:typed_data';

import 'storage_repository.dart';

/// Implementación de [StorageRepository] para MODO MOCKUP.
///
/// No persiste bytes: devuelve el nombre del archivo y la UI guarda los
/// bytes en memoria por la duración de la sesión. Sirve para probar el
/// flujo completo sin internet ni cuotas de storage.
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
    return nombreArchivo;
  }

  @override
  Future<String> subirPdf({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  }) async {
    await _simularLatencia();
    return nombreArchivo;
  }
}
