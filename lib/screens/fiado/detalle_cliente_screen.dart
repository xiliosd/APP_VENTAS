import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/teclado_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  /// Cliente y saldo al abrir; el saldo mostrado se lee después de
  /// [saldoClienteProvider] para reflejar abonos hechos en esta pantalla.
  final ClienteConSaldo clienteConSaldo;

  Future<void> _abrirAbono(BuildContext context) async {
    final cliente = clienteConSaldo.cliente;
    final registrado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Abono de ${cliente.nombre}',
      builder: (_) => _HojaAbono(clienteId: cliente.id),
    );
    if (registrado == true && context.mounted) {
      avisar(context, 'Abono registrado');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = clienteConSaldo.cliente;
    final saldo = ref.watch(saldoClienteProvider(cliente.id)).valueOrNull ??
        clienteConSaldo.saldo;
    final movimientosAsync = ref.watch(movimientosClienteProvider(cliente.id));

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('tarjeta_saldo_cliente'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColoresApp.fiadoSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Debe',
                    style: TextStyle(fontSize: 13, color: ColoresApp.fiado)),
                const SizedBox(height: 4),
                Monto(saldo, tamano: 32, tono: TonoMonto.fiado),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_registrar_abono'),
            texto: 'Registrar abono',
            variante: VarianteBoton.entra,
            onPressed: saldo > 0 ? () => _abrirAbono(context) : null,
          ),
          const SizedBox(height: 24),
          const Text('Movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          movimientosAsync.when(
            data: (movimientos) => Card(
              child: Column(
                children: [
                  for (final m in movimientos) _FilaMovimiento(movimiento: m),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento});

  final MovimientoFiado movimiento;

  @override
  Widget build(BuildContext context) {
    final esAbono = movimiento.tipo == TipoMovimientoFiado.abono;
    final color = esAbono ? ColoresApp.entra : ColoresApp.fiado;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esAbono ? Icons.payments_rounded : Icons.shopping_bag_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Monto(movimiento.monto,
          tamano: 16, tono: esAbono ? TonoMonto.entra : TonoMonto.fiado),
      subtitle: Text(formatoFechaHora(movimiento.fecha)),
      trailing: Text(esAbono ? 'Abono' : 'Venta fiada'),
    );
  }
}

class _HojaAbono extends ConsumerStatefulWidget {
  const _HojaAbono({required this.clienteId});

  final int clienteId;

  @override
  ConsumerState<_HojaAbono> createState() => _HojaAbonoState();
}

class _HojaAbonoState extends ConsumerState<_HojaAbono> {
  int _monto = 0;
  String? _error;

  /// True mientras se valida y guarda; evita registrar dos veces el abono.
  bool _guardando = false;

  Future<void> _registrar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await _guardar();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardar() async {
    final fiadoRepo = ref.read(fiadoRepositoryProvider);
    final saldo = await fiadoRepo.saldoCliente(widget.clienteId);
    if (!mounted) return;
    if (_monto > saldo) {
      setState(() => _error =
          'El abono no puede ser mayor que la deuda (${formatoMoneda(saldo)})');
      return;
    }
    final sesion = ref.read(sesionProvider).usuarioActivo!;
    await fiadoRepo.registrarPago(
      clienteId: widget.clienteId,
      monto: _monto,
      usuarioId: sesion.id,
    );
    ref.invalidate(clientesConDeudaProvider);
    ref.invalidate(saldoClienteProvider(widget.clienteId));
    ref.invalidate(movimientosClienteProvider(widget.clienteId));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Monto(_monto, tamano: 36, tono: TonoMonto.entra)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.sale),
            ),
          ),
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) => setState(() {
            _monto = aplicarTecla(_monto, tecla);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_confirmar_abono'),
          texto: 'Registrar abono',
          variante: VarianteBoton.entra,
          onPressed: _monto > 0 && !_guardando ? _registrar : null,
        ),
      ],
    );
  }
}
