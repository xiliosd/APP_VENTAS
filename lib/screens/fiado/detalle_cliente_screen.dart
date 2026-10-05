import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerStatefulWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  /// Cliente y saldo al momento de abrir; el saldo mostrado se lee después
  /// de [saldoClienteProvider] para reflejar abonos hechos en esta pantalla.
  final ClienteConSaldo clienteConSaldo;

  @override
  ConsumerState<DetalleClienteScreen> createState() =>
      _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends ConsumerState<DetalleClienteScreen> {
  final _montoController = TextEditingController();
  String? _errorMonto;

  /// True mientras se valida y guarda un abono; evita que un doble toque
  /// registre el mismo abono dos veces.
  bool _guardando = false;

  int get _clienteId => widget.clienteConSaldo.cliente.id;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _registrarAbono() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await _guardarAbono();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardarAbono() async {
    final monto = parsearMonto(_montoController.text);
    if (monto == null || monto <= 0) {
      setState(() => _errorMonto = 'Escribe un monto válido');
      return;
    }
    final fiadoRepo = ref.read(fiadoRepositoryProvider);
    final saldo = await fiadoRepo.saldoCliente(_clienteId);
    if (!mounted) return;
    if (monto > saldo) {
      setState(() => _errorMonto =
          'El abono no puede ser mayor que la deuda (${formatoMoneda(saldo)})');
      return;
    }
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await fiadoRepo.registrarPago(
      clienteId: _clienteId,
      monto: monto,
      usuarioId: sesion.id,
    );
    ref.invalidate(clientesConDeudaProvider);
    ref.invalidate(saldoClienteProvider(_clienteId));
    ref.invalidate(movimientosClienteProvider(_clienteId));
    if (!mounted) return;
    _montoController.clear();
    setState(() => _errorMonto = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abono registrado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.clienteConSaldo.cliente;
    final saldo = ref.watch(saldoClienteProvider(_clienteId)).valueOrNull ??
        widget.clienteConSaldo.saldo;
    final movimientosAsync = ref.watch(movimientosClienteProvider(_clienteId));

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debe: ${formatoMoneda(saldo)}',
              key: const Key('texto_saldo_cliente'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_abono'),
              controller: _montoController,
              decoration: InputDecoration(
                labelText: 'Monto del abono',
                errorText: _errorMonto,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_abono'),
              onPressed: _guardando ? null : _registrarAbono,
              child: const Text('Registrar abono'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: movimientosAsync.when(
                data: (movimientos) => ListView(
                  children: movimientos.map((m) {
                    final esAbono = m.tipo == TipoMovimientoFiado.abono;
                    final color = esAbono ? Colors.green.shade700 : null;
                    return ListTile(
                      leading: Icon(
                        esAbono ? Icons.payments : Icons.shopping_bag,
                        color: color,
                      ),
                      title: Text(
                        formatoMoneda(m.monto),
                        style: TextStyle(color: color),
                      ),
                      subtitle: Text(formatoFechaHora(m.fecha)),
                      trailing: Text(esAbono ? 'Abono' : 'Venta fiada'),
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
