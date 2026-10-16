import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/orden_productos_provider.dart';
import '../ui/colores_app.dart';
import '../ui/hoja_inferior.dart';
import '../util/orden_productos.dart';

const _nombres = {
  OrdenProductos.alfabetico: ('A–Z', 'Por nombre', Icons.sort_by_alpha_rounded),
  OrdenProductos.creacion: (
    'Como los creé',
    'Del primero al último que agregaste',
    Icons.history_rounded,
  ),
  OrdenProductos.masVendidos: (
    'Más vendidos',
    'Lo que más salió en los últimos 30 días',
    Icons.trending_up_rounded,
  ),
};

const _claves = {
  OrdenProductos.alfabetico: 'orden_alfabetico',
  OrdenProductos.creacion: 'orden_creacion',
  OrdenProductos.masVendidos: 'orden_mas_vendidos',
};

/// Botón "Ordenar" para la barra superior de un listado de productos.
class BotonOrdenProductos extends ConsumerWidget {
  const BotonOrdenProductos({
    super.key,
    required this.listado,
    this.conMasVendidos = false,
  });

  final ListadoProductos listado;
  final bool conMasVendidos;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Ordenar',
    icon: const Icon(Icons.sort_rounded),
    onPressed: () => mostrarHojaInferior<void>(
      context,
      titulo: 'Ordenar productos',
      builder: (_) =>
          _HojaOrden(listado: listado, conMasVendidos: conMasVendidos),
    ),
  );
}

class _HojaOrden extends ConsumerWidget {
  const _HojaOrden({required this.listado, required this.conMasVendidos});

  final ListadoProductos listado;
  final bool conMasVendidos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(ordenProductosProvider(listado));
    final c = ColoresApp.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final orden in OrdenProductos.values)
          if (orden != OrdenProductos.masVendidos || conMasVendidos)
            ListTile(
              key: Key(_claves[orden]!),
              leading: Icon(_nombres[orden]!.$3, color: c.primario),
              title: Text(_nombres[orden]!.$1),
              subtitle: Text(_nombres[orden]!.$2),
              selected: orden == actual,
              trailing: orden == actual
                  ? Icon(Icons.check_rounded, color: c.primario)
                  : null,
              onTap: () {
                ref
                    .read(ordenProductosProvider(listado).notifier)
                    .elegir(orden);
                Navigator.pop(context);
              },
            ),
      ],
    );
  }
}
