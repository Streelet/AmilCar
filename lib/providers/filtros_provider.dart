import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  Filtros globales de órdenes de trabajo
/// ─────────────────────────────────────────────────────────────────────────
/// Estado compartido: el mismo filtro aplica al Kanban de "Pendientes de
/// Estimado" Y a las tablas posteriores (Pendientes de Trabajo, En Proceso,
/// Por Cobrar). Así si filtrás por "María González" en cualquier pestaña,
/// se filtra el pipeline entero.
///
/// Son [StateProvider]s simples: viven en memoria, no se persisten. Se
/// reinician al cerrar la app.

/// Cliente seleccionado para filtrar; `null` = mostrar todos los clientes.
final filtroClienteIdProvider = StateProvider<String?>((ref) => null);

/// Rango de fechas de creación: `null` = sin filtro de fecha.
final filtroRangoFechasProvider =
    StateProvider<DateTimeRange?>((ref) => null);

/// `true` si hay al menos un filtro activo.
final hayFiltrosActivosProvider = Provider<bool>((ref) {
  return ref.watch(filtroClienteIdProvider) != null ||
      ref.watch(filtroRangoFechasProvider) != null;
});
