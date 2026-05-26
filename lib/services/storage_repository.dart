import 'dart:typed_data';

/// Contrato para subir archivos (fotos y PDFs) que después se referencian
/// vía URL pública desde una [OrdenTrabajo].
///
/// La capa de UI no necesita saber si el storage es real (Supabase) o
/// simulado (mock): solo recibe bytes + nombre + ordenId y obtiene una
/// URL para guardar en `OrdenTrabajo.fotosUrls` o `PdfCotizacion.url`.
abstract interface class StorageRepository {
  /// Sube una foto del vehículo / del trabajo. Devuelve la URL para
  /// guardar en `OrdenTrabajo.fotosUrls`.
  ///
  /// En Supabase: bucket `fotos-ordenes`, ruta `<ordenId>/<uuid>_<filename>`.
  /// En mock: devuelve el [nombreArchivo] tal cual (la app conserva los
  /// bytes en memoria solo durante la sesión).
  Future<String> subirFoto({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  });

  /// Sube un PDF de cotización. Devuelve la URL para guardar en
  /// `PdfCotizacion.url`.
  ///
  /// En Supabase: bucket `cotizaciones-pdf`, ruta `<ordenId>/<uuid>_<filename>`.
  /// En mock: devuelve [nombreArchivo].
  Future<String> subirPdf({
    required Uint8List bytes,
    required String nombreArchivo,
    required String ordenId,
  });
}
