import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/estimado.dart';
import '../providers/auth_provider.dart';
import '../providers/estimados_provider.dart';
import '../theme/app_colors.dart';
import 'widgets/soft_card.dart';

/// Pantalla de Recuperación (Fase 5).
///
/// Lista las órdenes archivadas y permite restaurarlas al tablero si el
/// cliente cambia de opinión. La restauración es una acción de gestión:
/// solo disponible para el rol 'admin'.
class ArchivedScreen extends ConsumerWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivados = ref.watch(estimadosArchivadosProvider);
    final perfil = ref.watch(currentPerfilProvider);
    final esAdmin = perfil?.rol.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Órdenes Archivadas')),
      body: archivados.isEmpty
          ? const _Vacio()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${archivados.length} orden(es) archivada(s)',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 12),
                      for (final e in archivados)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ArchivadoCard(
                            estimado: e,
                            puedeRestaurar: esAdmin,
                            onRestaurar: () => _restaurar(context, ref, e),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _restaurar(
    BuildContext context,
    WidgetRef ref,
    Estimado estimado,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(estimadosControllerProvider).restaurar(estimado);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Orden de ${estimado.clienteNombre} restaurada al tablero.',
        ),
      ),
    );
  }
}

class _ArchivadoCard extends StatelessWidget {
  const _ArchivadoCard({
    required this.estimado,
    required this.puedeRestaurar,
    required this.onRestaurar,
  });

  final Estimado estimado;
  final bool puedeRestaurar;
  final VoidCallback onRestaurar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.onSurfaceVariant, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estimado.vehiculoResumen,
                        style: theme.textTheme.titleMedium),
                    Text(estimado.clienteNombre,
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (estimado.direccion != null &&
              estimado.direccion!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(estimado.direccion!,
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (puedeRestaurar)
            ElevatedButton.icon(
              onPressed: onRestaurar,
              icon: const Icon(Icons.unarchive_outlined, size: 18),
              label: const Text('Restaurar al tablero'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solo un administrador puede restaurar órdenes.',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Sin órdenes archivadas',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Las órdenes que archives aparecerán aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
