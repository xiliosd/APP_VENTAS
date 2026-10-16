import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/correccion_repository.dart';
import '../../repositories/pedido_repository.dart';
import '../../ui/avisos.dart';
import '../../data/database.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/monto.dart';
import '../../ui/pildora.dart';
import '../../util/diferencia_pedido.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

/// Líneas de una entrada de mercancía y "Anular entrada".
class DetalleEntradaScreen extends ConsumerWidget {
  const DetalleEntradaScreen({super.key, required this.entradaId});

  final int entradaId;

  Future<void> _anular(BuildContext context, WidgetRef ref, Gasto? gasto) async {
    final conGasto = gasto != null && !gasto.anulado;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Anular esta entrada?'),
        content: Text(
          'Las existencias se descuentan; los precios actualizados no cambian.'
          '${conGasto ? ' También se anula el gasto de ${formatoMoneda(gasto.monto)}.' : ''}',
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
      if (context.mounted) {
        avisar(context, conGasto ? 'Entrada y gasto anulados' : 'Entrada anulada');
      }
    } on PermisoDenegado {
      if (context.mounted) {
        avisar(
          context,
          'Solo el administrador o quien la recibió hoy puede anularla',
          error: true,
        );
      }
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
          if (detalle.lineasPedido != null) ...[
            const SizedBox(height: 12),
            _ComparacionPedido(
              pedidas: detalle.lineasPedido!,
              llegaron: detalle.lineas,
            ),
          ],
          if (detalle.gasto != null) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('gasto_entrada'),
              child: ListTile(
                leading: Icon(Icons.payments_outlined, color: c.sale),
                title: Text('Gasto ${detalle.gasto!.descripcion ?? ''}'),
                subtitle: detalle.gasto!.anulado
                    ? Text('Gasto anulado', style: TextStyle(color: c.sale))
                    : const Text('Pagado de la caja'),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Monto(
                    detalle.gasto!.monto,
                    tamano: 16,
                    tachado: detalle.gasto!.anulado,
                  ),
                ),
              ),
            ),
          ],
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
              onPressed: () => _anular(context, ref, detalle.gasto),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que se pidió frente a lo que llegó, producto por producto.
class _ComparacionPedido extends StatelessWidget {
  const _ComparacionPedido({required this.pedidas, required this.llegaron});

  final List<LineaPedidoDetalle> pedidas;
  final List<({LineaEntrada linea, String producto})> llegaron;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final llego = {for (final l in llegaron) l.linea.productoId: l};
    final pedidos = {for (final p in pedidas) p.linea.productoId};
    final filas = [
      for (final p in pedidas)
        (
          nombre: p.producto.nombre,
          pedido: p.linea.cantidad as int?,
          llego: llego[p.linea.productoId]?.linea.cantidad ?? 0,
        ),
      for (final l in llegaron)
        if (!pedidos.contains(l.linea.productoId))
          (nombre: l.producto, pedido: null, llego: l.linea.cantidad),
    ];
    return Card(
      key: const Key('comparacion_pedido'),
      child: Column(
        children: [
          for (final f in filas)
            Builder(
              builder: (_) {
                final estado = estadoLineaPedido(
                  pedido: f.pedido,
                  llego: f.llego,
                );
                return ListTile(
                  dense: true,
                  title: Text(
                    f.pedido == null
                        ? '${f.nombre} · no se pidió · llegó ${f.llego}'
                        : '${f.nombre} · pedido ${f.pedido} · llegó ${f.llego}',
                  ),
                  trailing: Pildora(
                    texto: textoEstadoLinea(
                      estado,
                      pedido: f.pedido,
                      llego: f.llego,
                    ),
                    color: switch (estado) {
                      EstadoLineaPedido.completo => c.entra,
                      EstadoLineaPedido.noLlego => c.sale,
                      EstadoLineaPedido.extra => c.primario,
                      _ => c.fiado,
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
