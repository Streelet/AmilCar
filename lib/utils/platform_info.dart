import 'dart:io';
import 'package:flutter/foundation.dart';

/// Devuelve la plataforma actual como cadena corta lowercase.
/// Ejemplos: 'android', 'ios', 'web', 'windows', 'macos', 'linux'.
String currentPlatform() {
  if (kIsWeb) return 'web';
  try {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
  } catch (_) {}
  return 'desconocido';
}
