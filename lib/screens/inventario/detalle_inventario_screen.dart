import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../util/fecha_util.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(item.producto.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            textoExistencias(item.existencias),
            key: const Key('existencias_detalle'),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: item.existencias <= item.producto.minimo
                  ? ColoresApp.of(context).sale
                  : ColoresApp.of(context).texto,
            ),
          ),
          Text(
            'mín. ${item.producto.minimo}',
            style: TextStyle(color: ColoresApp.of(context).textoSecundario),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_ajustar_conteo'),
            texto: 'Ajustar conteo',
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: item.producto),
          ),
          const SizedBox(height: 24),
          const Text(
            'Historial',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          for (final m in historial)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_textoMovimiento(m)),
              subtitle: Text(formatoFechaHora(m.fecha)),
            ),
        ],
      ),
    );
  }
}
