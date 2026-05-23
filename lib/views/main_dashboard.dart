import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/orden_trabajo.dart';
import '../models/perfil.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'archived_screen.dart';
import 'tabs/lista_ordenes_tab.dart';
import 'tabs/pendientes_estimado_tab.dart';
import 'widgets/user_avatar_menu.dart';

/// Descriptor de una pestaña superior del dashboard.
class _TabDef {
  const _TabDef({required this.titulo, required this.contenido});
  final String titulo;
  final Widget contenido;
}

/// Fase 3 — Pantalla principal tras el login.
///
/// 4 pestañas superiores fijas con sincronización en tiempo real. Si el rol
/// es 'asesor', la pestaña "Pendiente de Pago" desaparece para evitar
/// desvíos financieros y sobrecarga de información.
class MainDashboard extends ConsumerWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentPerfilProvider);
    if (perfil == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = _tabsParaRol(perfil.rol);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          titleSpacing: AppSpacing.marginMobile,
          title: const _TituloAppBar(),
          actions: [
            // Acceso rápido a las órdenes archivadas.
            IconButton(
              tooltip: 'Órdenes archivadas',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ArchivedScreen(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const UserAvatarMenu(),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile - 8,
                ),
                tabs: [
                  for (final t in tabs) Tab(text: t.titulo),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) t.contenido],
        ),
      ),
    );
  }

  /// Construye las pestañas según el rol. El 'asesor' (técnico en campo) no
  /// ve la pestaña financiera "Pendiente de Pago".
  List<_TabDef> _tabsParaRol(UserRole rol) {
    final tabs = <_TabDef>[
      const _TabDef(
        titulo: 'Pendientes de Estimado',
        contenido: PendientesEstimadoTab(),
      ),
      const _TabDef(
        titulo: 'Pendientes de Trabajo',
        contenido: ListaOrdenesTrabajoTab(
          estado: EstadoKanban.pendienteTrabajo,
          icono: Icons.build_outlined,
          mensajeVacio: 'Sin trabajos pendientes por iniciar.',
        ),
      ),
      const _TabDef(
        titulo: 'En Proceso',
        contenido: ListaOrdenesTrabajoTab(
          estado: EstadoKanban.enProceso,
          icono: Icons.handyman_outlined,
          mensajeVacio: 'No hay vehículos en reparación ahora mismo.',
        ),
      ),
    ];

    if (rol.isAdmin) {
      tabs.add(
        const _TabDef(
          titulo: 'Pendiente de Pago',
          contenido: ListaOrdenesTrabajoTab(
            estado: EstadoKanban.pendientePago,
            icono: Icons.payments_outlined,
            mensajeVacio: 'No hay cobros pendientes.',
          ),
        ),
      );
    }

    return tabs;
  }
}

class _TituloAppBar extends StatelessWidget {
  const _TituloAppBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.car_repair_rounded,
              color: AppColors.onPrimary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(AppConfig.appName, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
