import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/orden_trabajo.dart';
import '../models/perfil.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/estado_style.dart';
import 'archived_screen.dart';
import 'clientes_screen.dart';
import 'nueva_orden_screen.dart';
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
            // Directorio de clientes.
            IconButton(
              tooltip: 'Clientes',
              icon: const Icon(Icons.people_alt_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ClientesScreen(),
                ),
              ),
            ),
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => abrirNuevaOrdenTrabajo(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva orden'),
          tooltip: 'Crear orden de trabajo',
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
        contenido: _ConTemaDeEstado(
          estado: EstadoKanban.pendienteTrabajo,
          child: ListaOrdenesTrabajoTab(
            estado: EstadoKanban.pendienteTrabajo,
            icono: Icons.build_outlined,
            mensajeVacio: 'Sin trabajos pendientes por iniciar.',
            comoTabla: true,
            accionRapida: AccionRapidaOrden(
              icono: Icons.play_arrow_rounded,
              label: 'Iniciar trabajo (Pasar a En Proceso)',
              labelCorta: 'Iniciar',
              destino: EstadoKanban.enProceso,
            ),
          ),
        ),
      ),
      const _TabDef(
        titulo: 'En Proceso',
        contenido: _ConTemaDeEstado(
          estado: EstadoKanban.enProceso,
          child: ListaOrdenesTrabajoTab(
            estado: EstadoKanban.enProceso,
            icono: Icons.handyman_outlined,
            mensajeVacio: 'No hay vehículos en reparación ahora mismo.',
            comoTabla: true,
            accionRapida: AccionRapidaOrden(
              icono: Icons.payments_outlined,
              label: 'Mover a Por Cobrar',
              labelCorta: 'A Por Cobrar',
              destino: EstadoKanban.pendientePago,
              estilo: EstiloAccionRapida.moverAPendientePagoConMonto,
            ),
          ),
        ),
      ),
    ];

    if (rol.isAdmin) {
      tabs.add(
        const _TabDef(
          titulo: 'Pendiente de Pago',
          contenido: _ConTemaDeEstado(
            estado: EstadoKanban.pendientePago,
            child: ListaOrdenesTrabajoTab(
              estado: EstadoKanban.pendientePago,
              icono: Icons.payments_outlined,
              mensajeVacio: 'No hay cobros pendientes.',
              comoTabla: true,
              vistaCobros: true,
              accionRapida: AccionRapidaOrden(
                icono: Icons.add_card_rounded,
                label: 'Registrar pago',
                labelCorta: 'Registrar pago',
                destino: EstadoKanban.pendientePago,
                estilo: EstiloAccionRapida.registrarPago,
              ),
            ),
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
    // El logo de AmilCar ya contiene "AMILCAR" como texto, así que en el
    // AppBar va solo el logo (sin un Text adicional al lado, sería
    // redundante). Altura limitada a 40 para que entre cómodo en la
    // barra superior.
    return Image.asset(
      'assets/branding/logo.png',
      height: 40,
      fit: BoxFit.contain,
    );
  }
}

/// Envuelve un widget con un [Theme] override cuyo color primario es el
/// acento de la [EstadoStyle] correspondiente. Le da identidad cromática
/// distintiva a cada pestaña sin tener que pintar widget por widget.
class _ConTemaDeEstado extends StatelessWidget {
  const _ConTemaDeEstado({required this.estado, required this.child});
  final EstadoKanban estado;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaParaEstado(context, estado),
      child: child,
    );
  }
}
