import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/aviso_por_pedir_provider.dart';
import '../../providers/inventario_providers.dart';
import '../../ui/colores_app.dart';
import '../../ui/movimiento.dart';

/// Aviso que deja una venta cuando un producto llegó a su mínimo. Se queda en
/// el Inicio hasta que se cierre, porque la pantalla de venta ya no está.
class FranjaPorPedir extends ConsumerWidget {
  const FranjaPorPedir({super.key, required this.onVerPorPedir});

  final VoidCallback onVerPorPedir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = ref.watch(avisoPorPedirProvider);
    final c = ColoresApp.of(context);
    return AnimatedSize(
      duration: Movimiento.duracion(context, Movimiento.media),
      alignment: Alignment.topCenter,
      child: avisos.isEmpty
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('franja_por_pedir'),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                decoration: BoxDecoration(
                  color: c.fondoAviso,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _Textos(avisos.map((a) => a.texto).toList()),
                          ),
                        ),
                        IconButton(
                          key: const Key('cerrar_franja_por_pedir'),
                          tooltip: 'Cerrar aviso',
                          color: c.textoAviso,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              ref.read(avisoPorPedirProvider.notifier).cerrar(),
                        ),
                      ],
                    ),
                    TextButton(
                      key: const Key('boton_ver_por_pedir_franja'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.accionAviso,
                      ),
                      onPressed: () {
                        ref.read(avisoPorPedirProvider.notifier).cerrar();
                        onVerPorPedir();
                      },
                      child: const Text('Ver por pedir'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Textos extends StatelessWidget {
  const _Textos(this.textos);

  final List<String> textos;

  @override
  Widget build(BuildContext context) {
    final color = ColoresApp.of(context).textoAviso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textos.length > 1)
          Text(
            'Toca pedir ${textos.length} productos',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        for (final texto in textos)
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: textos.length > 1 ? 14 : 16,
              fontWeight: textos.length > 1 ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// "N por pedir": siempre a la vista en el Inicio, para quien no vio el aviso.
class IndicadorPorPedir extends ConsumerWidget {
  const IndicadorPorPedir({super.key, required this.onVerPorPedir});

  final VoidCallback onVerPorPedir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupos = ref.watch(porPedirProvider).valueOrNull ?? const [];
    final cantidad = grupos.fold<int>(
      0,
      (suma, g) => suma + g.productos.length,
    );
    if (cantidad == 0) return const SizedBox.shrink();
    final c = ColoresApp.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: '$cantidad por pedir. Toca para ver la lista',
        excludeSemantics: true,
        child: InkWell(
          key: const Key('indicador_por_pedir'),
          borderRadius: BorderRadius.circular(24),
          onTap: onVerPorPedir,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 20, color: c.texto),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '$cantidad por pedir',
                      style: TextStyle(
                        color: c.texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
