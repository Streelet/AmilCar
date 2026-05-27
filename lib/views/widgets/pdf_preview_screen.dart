/// Pantalla de preview de PDF.
///
/// La implementación cambia por plataforma:
///  • Web    → iframe con blob URL (usa el visor PDF nativo del navegador).
///  • Móvil  → `PdfPreview` del paquete `printing` (preview pdfrx-like).
///  • Desktop→ `PdfPreview` (igual que móvil).
///
/// El selector se hace con imports condicionales: el stub se usa en
/// desktop/móvil; el archivo `_web.dart` se compila solo en web.
export 'pdf_preview_screen_io.dart'
    if (dart.library.html) 'pdf_preview_screen_web.dart';
