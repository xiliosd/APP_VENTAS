import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/nivel_existencias.dart';
import '../../ui/titulo_seccion.dart';
import '../../ui/estado_vacio.dart';
import '../../util/fecha_util.dart';
import '../configuracion/producto_screen.dart';
import 'hoja_ajuste_conteo.dart';
import 'inventario_screen.dart';

String _textoMovimiento(MovimientoInventario m) {
  switch (m.tipo) {
    case TipoMovimientoInventario.conteoInicial:
      return '${m.quien} · conteo inicial ${m.cantidad}';
    case TipoMovimientoInventario.ajuste:
      final diferencia = m.cantidad - (m.anterior ?? 0);
      final signo = diferencia > 0
          ? '+$diferencia'
          : diferencia < 0
          ? '−${-diferencia}'
          : '0';
      return '${m.quien} · ${m.anterior} → ${m.cantidad} ($signo)';
    case TipoMovimientoInventario.entrada:
      return '${m.quien} · +${m.cantidad}${m.anulada ? ' (anulada)' : ''}';
  }
}

/// Existencias, mínimo e historial de un producto.
class DetalleInventarioScreen extends ConsumerWidget {
  const DetalleInventarioScreen({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.watch(productosConControlProvider);
    final item = (control.valueOrNull ?? const [])
        .where((c) => c.producto.id == productoId)
        .firstOrNull;
    final historial =
        ref.watch(historialInventarioProvider(productoId)).valueOrNull ??
        const <MovimientoInventario>[];
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: control.hasValue
            ? const EstadoVacio(
                icono: Icons.inventory_2_outlined,
                titulo: 'Este producto ya no controla existencias',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final c = ColoresApp.of(context);
    final nivel = nivelExistencias(item.existencias, item.producto.minimo);
    final pedirHasta = item.producto.pedirHasta;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.producto.nombre),
        actions: [
          if (ref.watch(sesionProvider).esAdmin)
            IconButton(
              key: const Key('boton_editar_producto'),
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final guardado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ProductoScreen(producto: item.producto),
                  ),
                );
                if (guardado == true && context.mounted) {
                  avisar(context, 'Producto guardado');
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntradaEscalonada(
            indice: 0,
            child: Card(
              key: const Key('tarjeta_existencias'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          textoExistencias(item.existencias),
                          key: const Key('existencias_detalle'),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: item.existencias <= item.producto.minimo
                                ? c.sale
                                : c.texto,
                          ),
                        ),
                        EtiquetaNivel(nivel: nivel),
                      ],
                    ),
                    Text(
                      'mín. ${item.producto.minimo}'
                      '${pedirHasta == null ? '' : ' · pedir hasta $pedirHasta'}',
                      style: TextStyle(color: c.textoSecundario),
                    ),
                    const SizedBox(height: 12),
                    BarraNivel(
                      fraccion: fraccionNivel(
                          item.existencias, item.producto.minimo, pedirHasta),
                      nivel: nivel,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_ajustar_conteo'),
            texto: 'Ajustar conteo',
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: item.producto),
          ),
          if (historial.isNotEmpty) ...[
            const SizedBox(height: 24),
            const TituloSeccion('HISTORIAL'),
            EntradaEscalonada(
              indice: 1,
              child: Card(
                child: Column(
                  children: [
                    for (final (i, m) in historial.indexed)
                      ListTile(
                        key: Key('movimiento_inventario_$i'),
                        leading: m.tipo == TipoMovimientoInventario.entrada
                            ? IconoCuadrado(
                                icono: Icons.call_received_rounded,
                                color: c.entra)
                            : IconoCuadrado(
                                icono: Icons.edit_rounded,
                                color: c.textoSecundario),
                        title: Text(_textoMovimiento(m)),
                        subtitle: Text(formatoFechaHora(m.fecha)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
