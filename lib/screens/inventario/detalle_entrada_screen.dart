import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(detalle.resumen.proveedor)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${formatoFechaHora(entrada.fecha)} · ${detalle.resumen.usuario}',
            style: TextStyle(color: ColoresApp.of(context).textoSecundario),
          ),
          const SizedBox(height: 12),
          for (final l in detalle.lineas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${l.linea.cantidad} × ${l.producto} · '
                '${formatoMoneda(l.linea.precioCompra)}',
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Total ${formatoMoneda(entrada.total)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (entrada.nota != null) ...[
            const SizedBox(height: 8),
            Text(entrada.nota!),
          ],
          const SizedBox(height: 24),
          if (entrada.anulada)
            Text(
              'Entrada anulada',
              style: TextStyle(color: ColoresApp.of(context).sale),
            )
          else
            TextButton(
              key: const Key('boton_anular_entrada'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.of(context).sale),
              onPressed: () => _anular(context, ref),
              child: const Text('Anular entrada'),
            ),
        ],
      ),
    );
  }
}
