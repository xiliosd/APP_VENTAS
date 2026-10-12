import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

/// Líneas de una entrada de mercancía y "Anular entrada".
class DetalleEntradaScreen extends ConsumerWidget {
  const DetalleEntradaScreen({super.key, required this.entradaId});

  final int entradaId;

  Future<void> _anular(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Anular esta entrada?'),
        content: const Text(
          'Las existencias se descuentan; los precios actualizados no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar_anular_entrada'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.of(context).sale),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ref
          .read(inventarioRepositoryProvider)
          .anularEntrada(
            entradaId,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (context.mounted) avisar(context, 'Entrada anulada');
    } on ArgumentError {
      // Otro toque o dispositivo ya la anuló: el dato está bien.
      if (context.mounted) avisar(context, 'La entrada ya estaba anulada', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(detalleEntradaProvider(entradaId)).valueOrNull;
    if (detalle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final entrada = detalle.resumen.entrada;
    final c = ColoresApp.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(detalle.resumen.proveedor)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('cabecera_entrada'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconoCuadrado(
                        icono: Icons.local_shipping_rounded,
                        color:
                            entrada.anulada ? c.textoSecundario : c.entra,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detalle.resumen.proveedor,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${formatoFechaHora(entrada.fecha)} · '
                              '${detalle.resumen.usuario}',
                              style: TextStyle(
                                  fontSize: 13, color: c.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Monto(entrada.total, tamano: 28, tachado: entrada.anulada),
                  if (entrada.anulada)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Entrada anulada',
                          style: TextStyle(
                              color: c.sale, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final l in detalle.lineas)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${l.linea.cantidad} × ${l.producto} · '
                      '${formatoMoneda(l.linea.precioCompra)}',
                    ),
                  ),
              ],
            ),
          ),
          if (entrada.nota != null) ...[
            const SizedBox(height: 12),
            Text(entrada.nota!, style: TextStyle(color: c.textoSecundario)),
          ],
          if (!entrada.anulada) ...[
            const SizedBox(height: 24),
            BotonPrincipal(
              key: const Key('boton_anular_entrada'),
              texto: 'Anular entrada',
              variante: VarianteBoton.peligro,
              onPressed: () => _anular(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
