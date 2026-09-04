import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerStatefulWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  final ClienteConSaldo clienteConSaldo;

  @override
  ConsumerState<DetalleClienteScreen> createState() =>
      _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends ConsumerState<DetalleClienteScreen> {
  final _montoController = TextEditingController();

  Future<void> _registrarAbono() async {
    final monto = int.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) return;
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await ref.read(fiadoRepositoryProvider).registrarPago(
          clienteId: widget.clienteConSaldo.cliente.id,
          monto: monto,
          usuarioId: sesion.id,
        );
    ref.invalidate(clientesConDeudaProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.clienteConSaldo.cliente;
    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debe: ${formatoMoneda(widget.clienteConSaldo.saldo)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_abono'),
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto del abono'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_abono'),
              onPressed: _registrarAbono,
              child: const Text('Registrar abono'),
            ),
          ],
        ),
      ),
    );
  }
}
