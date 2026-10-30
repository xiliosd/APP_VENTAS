import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/etiqueta_qr.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/teclado_monto.dart';
import '../../ui/tema_app.dart';
import '../../ui/tipografia.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/nombre_cliente.dart';
import '../../util/saldos_fiado.dart';
import '../correccion/hoja_movimiento.dart';
import '../correccion/texto_correccion.dart';
import '../qr/cobro_qr_screen.dart';
import 'extracto_fiado_screen.dart';

class DetalleClienteScreen extends ConsumerWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  /// Cliente y saldo al abrir; el saldo mostrado se lee después de
  /// [saldoClienteProvider] para reflejar abonos hechos en esta pantalla.
  final ClienteConSaldo clienteConSaldo;

  Future<void> _abrirAbono(BuildContext context, int saldo) async {
    final cliente = clienteConSaldo.cliente;
    final registrado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Abono de ${cliente.nombreCompleto}',
      builder: (_) => _HojaAbono(clienteId: cliente.id, saldo: saldo),
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
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};

    final c = ColoresApp.of(context);
    final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);
    // Venta fiada vigente más antigua según los movimientos actuales (cambia
    // al anular o corregir); mientras cargan, la que se trajo al abrir.
    final ventasVigentes = [
      for (final m in movimientosAsync.valueOrNull ?? const <MovimientoFiado>[])
        if (m.tipo == TipoMovimientoFiado.venta && !m.anulado) m.fecha,
    ];
    // Sin movimientos vigentes el extracto estaría vacío.
    final hayMovimientosVigentes = (movimientosAsync.valueOrNull ??
            const <MovimientoFiado>[])
        .any((m) => !m.anulado);
    final fechaDeuda = ventasVigentes.isNotEmpty
        ? ventasVigentes.reduce((a, b) => a.isBefore(b) ? a : b)
        : clienteConSaldo.fechaDeudaMasAntigua ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombreCompleto)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('tarjeta_saldo_cliente'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tarjetaPrincipal,
              borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(cliente.nombreCompleto,
                    style: estiloTitulo(tamano: 14, color: suave)),
                const SizedBox(height: 4),
                // Con saldo a favor se muestra el valor; el texto lo aclara.
                Monto(saldo.abs(),
                    tamano: 36, tono: TonoMonto.claro, animado: true),
                const SizedBox(height: 4),
                Text(
                  saldo > 0
                      ? textoDebeDesde(fechaDeuda, DateTime.now())
                      : saldo == 0
                          ? 'Al día'
                          : 'Saldo a favor ${formatoMoneda(-saldo)}',
                  style: TextStyle(color: suave, fontSize: 13),
                ),
                if (saldo > 0) ...[
                  const SizedBox(height: 12),
                  BotonPrincipal(
                    key: const Key('boton_registrar_abono'),
                    texto: 'Registrar abono',
                    variante: VarianteBoton.entra,
                    onPressed: () => _abrirAbono(context, saldo),
                  ),
                ],
                if (hayMovimientosVigentes) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('boton_ver_extracto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.sobreTarjetaPrincipal,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: c.sobreTarjetaPrincipal),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExtractoFiadoScreen(cliente: cliente),
                      ),
                    ),
                    child: const Text('Ver extracto'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          movimientosAsync.when(
            skipLoadingOnReload: true,
            data: (movimientos) => _LineaTiempo(
              movimientos: movimientos,
              nombres: nombres,
              onTap: (m) => abrirHojaMovimiento(
                context,
                MovimientoEditable.desdeFiado(m,
                    clienteId: cliente.id, nombreCliente: cliente.nombreCompleto),
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

/// Movimientos del más reciente al más antiguo, agrupados por día, con el
/// saldo que quedó después de cada uno.
class _LineaTiempo extends StatelessWidget {
  const _LineaTiempo(
      {required this.movimientos, required this.nombres, required this.onTap});

  final List<MovimientoFiado> movimientos;
  final Map<int, String> nombres;
  final void Function(MovimientoFiado) onTap;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final saldos = saldosAcumulados(movimientos);
    final hoy = DateTime.now();
    String titulo(DateTime dia) => switch (diasDesde(dia, hoy)) {
          0 => 'Hoy',
          1 => 'Ayer',
          _ => fechaCortaConAnio(dia, hoy),
        };
    final filas = <Widget>[];
    DateTime? diaActual;
    for (final m in movimientos) {
      final dia = inicioDelDia(m.fecha);
      if (dia != diaActual) {
        diaActual = dia;
        filas.add(Padding(
          key: Key('encabezado_dia_${dia.toIso8601String().substring(0, 10)}'),
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(
            titulo(dia),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textoSecundario),
          ),
        ));
      }
      filas.add(_FilaMovimiento(
        movimiento: m,
        nombres: nombres,
        saldoTras: saldos[(m.tipo, m.id)],
        onTap: () => onTap(m),
      ));
    }
    return Column(
      key: const Key('linea_tiempo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filas,
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.movimiento,
    required this.nombres,
    required this.onTap,
    this.saldoTras,
  });

  final MovimientoFiado movimiento;

  /// Saldo después de este movimiento (null si está anulado).
  final int? saldoTras;

  /// Nombre de cada usuario por id.
  final Map<int, String> nombres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final esAbono = movimiento.tipo == TipoMovimientoFiado.abono;
    final color = esAbono ? c.entra : c.fiado;
    final correccion = movimiento.ultimaCorreccion;
    final saldo = saldoTras;
    final secundario = TextStyle(fontSize: 12, color: c.textoSecundario);
    return InkWell(
      key: Key('movimiento_fiado_${movimiento.tipo.name}_${movimiento.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(radioCampo),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Línea vertical con el punto del movimiento.
            SizedBox(
              width: 24,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: c.borde),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: movimiento.anulado ? c.borde : color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(esAbono ? 'Abono' : 'Venta fiada',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (esAbono &&
                            movimiento.medioPago == MedioPago.transferencia) ...[
                          const SizedBox(width: 8),
                          const EtiquetaQr(),
                        ],
                        const SizedBox(width: 8),
                        // El monto se encoge si no cabe (letra grande).
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(esAbono ? '− ' : '+ ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: movimiento.anulado
                                              ? c.textoSecundario
                                              : color)),
                                  Monto(movimiento.monto,
                                      tamano: 16,
                                      tono: esAbono
                                          ? TonoMonto.entra
                                          : TonoMonto.fiado,
                                      tachado: movimiento.anulado),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(formatoHora(movimiento.fecha), style: secundario),
                    if (correccion != null)
                      Text(
                        textoCorreccion(
                            correccion, nombres[correccion.usuarioId] ?? ''),
                        style: secundario,
                      ),
                    if (!movimiento.anulado && saldo != null)
                      Text(
                        saldo >= 0
                            ? 'Quedó debiendo ${formatoMoneda(saldo)}'
                            : 'Saldo a favor ${formatoMoneda(-saldo)}',
                        key: Key('saldo_tras_${movimiento.tipo.name}_'
                            '${movimiento.id}'),
                        style: secundario,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HojaAbono extends ConsumerStatefulWidget {
  const _HojaAbono({required this.clienteId, required this.saldo});

  final int clienteId;

  /// Deuda al abrir la hoja (para el abono rápido).
  final int saldo;

  @override
  ConsumerState<_HojaAbono> createState() => _HojaAbonoState();
}

class _HojaAbonoState extends ConsumerState<_HojaAbono> {
  int _monto = 0;
  MedioPago _medio = MedioPago.efectivo;
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
    if (_medio == MedioPago.transferencia) {
      final recibido = await abrirCobroQr(context, monto: _monto);
      if (!recibido || !mounted) return;
    }
    final sesion = ref.read(sesionProvider).usuarioActivo!;
    await fiadoRepo.registrarPago(
      clienteId: widget.clienteId,
      monto: _monto,
      usuarioId: sesion.id,
      medioPago: _medio,
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
        SelectorSegmentado<MedioPago>(
          key: const Key('selector_medio_abono'),
          opciones: const {
            MedioPago.efectivo: 'Efectivo',
            MedioPago.transferencia: 'Transferencia',
          },
          valor: _medio,
          onCambio: (medio) => setState(() => _medio = medio),
        ),
        const SizedBox(height: 12),
        Center(child: Monto(_monto, tamano: 36, tono: TonoMonto.entra)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresApp.of(context).sale),
            ),
          ),
        const SizedBox(height: 12),
        _AbonoRapido(
          saldo: widget.saldo,
          monto: _monto,
          onElegir: (monto) => setState(() {
            _monto = monto;
            _error = null;
          }),
        ),
        const SizedBox(height: 8),
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

/// Chips "Todo" y "Mitad" que llenan el monto del abono con un toque.
class _AbonoRapido extends StatelessWidget {
  const _AbonoRapido(
      {required this.saldo, required this.monto, required this.onElegir});

  final int saldo;
  final int monto;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    final mitad = mitadAbono(saldo);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const Key('abono_todo'),
          label: Text('Todo · ${formatoMoneda(saldo)}'),
          selected: monto == saldo,
          onSelected: (_) => onElegir(saldo),
        ),
        if (mitad > 0)
          ChoiceChip(
            key: const Key('abono_mitad'),
            label: Text('Mitad · ${formatoMoneda(mitad)}'),
            selected: monto == mitad,
            onSelected: (_) => onElegir(mitad),
          ),
      ],
    );
  }
}
