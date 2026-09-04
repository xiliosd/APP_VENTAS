import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/clientes_providers.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/monto_rapido_grid.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen({super.key});

  @override
  ConsumerState<RegistrarVentaScreen> createState() =>
      _RegistrarVentaScreenState();
}

class _RegistrarVentaScreenState extends ConsumerState<RegistrarVentaScreen> {
  final _montoLibreController = TextEditingController();
  final _nombreClienteNuevoController = TextEditingController();
  bool _esFiado = false;
  Cliente? _clienteSeleccionado;

  Future<void> _registrar(int monto, {int? productoId}) async {
    final sesion = ref.read(sesionProvider).usuarioActivo!;
    int? clienteId;

    if (_esFiado) {
      if (_clienteSeleccionado != null) {
        clienteId = _clienteSeleccionado!.id;
      } else if (_nombreClienteNuevoController.text.trim().isNotEmpty) {
        clienteId = await ref.read(clienteRepositoryProvider).crearCliente(
              nombre: _nombreClienteNuevoController.text.trim(),
            );
      } else {
        return; // fiado requiere cliente
      }
    }

    await ref.read(ventaRepositoryProvider).registrarVenta(
          monto: monto,
          productoId: productoId,
          esFiado: _esFiado,
          clienteId: clienteId,
          usuarioId: sesion.id,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final clientesAsync = ref.watch(listaClientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar venta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Productos frecuentes', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            productosAsync.when(
              data: (productos) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: productos.map((producto) {
                  return ElevatedButton(
                    key: Key('producto_${producto.id}'),
                    onPressed: () =>
                        _registrar(producto.precio, productoId: producto.id),
                    child: Text(
                      '${producto.nombre}\n${formatoMoneda(producto.precio)}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            const Text('Montos rápidos', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            MontoRapidoGrid(onSeleccionar: (monto) => _registrar(monto)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_libre'),
              controller: _montoLibreController,
              decoration: const InputDecoration(labelText: 'Monto libre'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_monto_libre'),
              onPressed: () {
                final monto = int.tryParse(_montoLibreController.text.trim());
                if (monto != null && monto > 0) _registrar(monto);
              },
              child: const Text('Registrar monto libre'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('checkbox_fiado'),
              title: const Text('Fiado'),
              value: _esFiado,
              onChanged: (value) => setState(() => _esFiado = value ?? false),
            ),
            if (_esFiado)
              clientesAsync.when(
                data: (clientes) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<Cliente>(
                      key: const Key('dropdown_cliente'),
                      hint: const Text('Elegir cliente existente'),
                      value: _clienteSeleccionado,
                      items: clientes
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.nombre)))
                          .toList(),
                      onChanged: (c) =>
                          setState(() => _clienteSeleccionado = c),
                    ),
                    TextField(
                      key: const Key('campo_cliente_nuevo'),
                      controller: _nombreClienteNuevoController,
                      decoration: const InputDecoration(
                        labelText: 'O nombre de cliente nuevo',
                      ),
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),
          ],
        ),
      ),
    );
  }
}
