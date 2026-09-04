import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../util/formato_moneda.dart';
import 'detalle_cliente_screen.dart';

class ListaFiadoScreen extends ConsumerWidget {
  const ListaFiadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesConDeudaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Me deben')),
      body: clientesAsync.when(
        data: (clientes) {
          if (clientes.isEmpty) {
            return const Center(child: Text('Nadie te debe por ahora'));
          }
          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final item = clientes[index];
              return ListTile(
                key: Key('cliente_deuda_${item.cliente.id}'),
                title: Text(item.cliente.nombre),
                subtitle: Text(
                  'Desde ${item.fechaDeudaMasAntigua.day}/${item.fechaDeudaMasAntigua.month}',
                ),
                trailing: Text(
                  formatoMoneda(item.saldo),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetalleClienteScreen(clienteConSaldo: item),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
