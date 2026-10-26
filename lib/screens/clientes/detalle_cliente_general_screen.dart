import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/clientes_providers.dart';
import '../../providers/fiado_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/titulo_seccion.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/nombre_cliente.dart';
import '../../widgets/formulario_cliente.dart';
import '../fiado/detalle_cliente_screen.dart';

/// Datos de un cliente y todas sus compras, de contado y fiadas.
class DetalleClienteGeneralScreen extends ConsumerWidget {
  const DetalleClienteGeneralScreen({super.key, required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(clientePorIdProvider(clienteId)).valueOrNull;
    final saldo = ref.watch(saldoClienteProvider(clienteId)).valueOrNull ?? 0;
    final movimientos =
        ref.watch(movimientosClienteProvider(clienteId)).valueOrNull ??
        const <MovimientoFiado>[];
    final compras =
        ref.watch(comprasClienteProvider(clienteId)).valueOrNull ??
        const <Venta>[];
    final tieneFiado = saldo != 0 || movimientos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(cliente?.nombreCompleto ?? 'Cliente')),
      body: cliente == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Tarjeta(cliente: cliente, saldo: saldo),
                if (tieneFiado) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('boton_ver_fiado'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetalleClienteScreen(
                          clienteConSaldo: ClienteConSaldo(
                            cliente: cliente,
                            saldo: saldo,
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.volunteer_activism_rounded),
                    label: const Text('Ver fiado'),
                  ),
                ],
                const SizedBox(height: 24),
                const TituloSeccion('COMPRAS'),
                if (compras.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aún no tiene compras',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColoresApp.of(context).textoSecundario,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final venta in compras)
                          ListTile(
                            key: Key('compra_${venta.id}'),
                            title: Text(formatoFechaHora(venta.fecha)),
                            subtitle: Text(venta.esFiado ? 'Fiado' : 'Contado'),
                            trailing: Text(
                              formatoMoneda(venta.monto),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.cliente, required this.saldo});

  final Cliente cliente;
  final int saldo;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    final telefono = cliente.telefono;
    final notas = cliente.notas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarInicial(id: cliente.id, nombre: cliente.nombreCompleto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.nombreCompleto,
                    key: const Key('nombre_cliente_detalle'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (telefono != null) Text(telefono),
                  if (notas != null && notas.trim().isNotEmpty)
                    Text(
                      notas,
                      style: TextStyle(color: colores.textoSecundario),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    saldo == 0
                        ? 'Al día'
                        : saldo > 0
                        ? 'Debe ${formatoMoneda(saldo)}'
                        : 'Saldo a favor ${formatoMoneda(-saldo)}',
                    key: const Key('deuda_cliente_detalle'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('boton_editar_cliente'),
              tooltip: 'Editar',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editarCliente(context, cliente),
            ),
          ],
        ),
      ),
    );
  }
}
