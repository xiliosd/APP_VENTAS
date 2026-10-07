import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../repositories/venta_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/mosaico.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/teclado_monto.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/monto_rapido_grid.dart';
import '../../widgets/selector_cliente.dart';
import '../qr/cobro_qr_screen.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen({super.key});

  @override
  ConsumerState<RegistrarVentaScreen> createState() =>
      _RegistrarVentaScreenState();
}

class _RegistrarVentaScreenState extends ConsumerState<RegistrarVentaScreen> {
  /// Evita registrar dos veces el mismo ticket con un doble toque.
  bool _cobrando = false;

  Future<void> _otroMonto() async {
    final monto = await mostrarHojaInferior<int>(
      context,
      titulo: 'Otro monto',
      builder: (_) => const _HojaOtroMonto(),
    );
    if (monto != null) ref.read(ticketProvider.notifier).agregarMonto(monto);
  }

  Future<void> _verTicket() => mostrarHojaInferior<void>(
    context,
    titulo: 'Ticket',
    builder: (_) => const _HojaTicket(),
  );

  Future<void> _cobrar() async {
    if (_cobrando) return;
    setState(() => _cobrando = true);
    try {
      final ticket = ref.read(ticketProvider);
      final porQr =
          !ticket.esFiado && ticket.medioPago == MedioPago.transferencia;
      if (porQr) {
        final recibido = await abrirCobroQr(context, monto: ticket.total);
        if (!recibido || !mounted) return;
      }
      final sesion = ref.read(sesionProvider).usuarioActivo!;
      int? clienteId;
      if (ticket.esFiado) {
        final cliente = ticket.clienteParaCobrar!;
        clienteId =
            cliente.id ??
            await ref
                .read(clienteRepositoryProvider)
                .obtenerOCrearCliente(cliente.nombre);
      }
      final ventaRepo = ref.read(ventaRepositoryProvider);
      final ventaId = await ventaRepo.registrarVenta(
        monto: ticket.total,
        productoId: ticket.productoIdUnico,
        esFiado: ticket.esFiado,
        clienteId: clienteId,
        usuarioId: sesion.id,
        medioPago: porQr ? MedioPago.transferencia : MedioPago.efectivo,
        lineas: [
          for (final linea in ticket.lineas)
            LineaNueva(
              productoId: linea.productoId,
              descripcion: linea.etiqueta,
              precioUnitario: linea.precio,
              cantidad: linea.cantidad,
            ),
        ],
      );
      if (!mounted) return;
      avisar(
        context,
        'Venta registrada · ${formatoMoneda(ticket.total)}',
        onDeshacer: () => ventaRepo.eliminarVenta(ventaId),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final productosAsync = ref.watch(productosActivosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectorSegmentado<bool>(
            key: const Key('selector_tipo_venta'),
            opciones: const {false: 'Contado', true: 'Fiado'},
            valor: ticket.esFiado,
            onCambio: notifier.cambiarFiado,
          ),
          if (ticket.esFiado) ...[
            const SizedBox(height: 12),
            SelectorCliente(
              elegido: ticket.cliente,
              onElegir: notifier.elegirCliente,
              onEscribir: notifier.escribirCliente,
              exigir: !ticket.estaVacio,
            ),
          ],
          if (!ticket.esFiado) ...[
            const SizedBox(height: 12),
            SelectorSegmentado<MedioPago>(
              key: const Key('selector_medio_pago'),
              opciones: const {
                MedioPago.efectivo: 'Efectivo',
                MedioPago.transferencia: 'Transferencia',
              },
              valor: ticket.medioPago,
              onCambio: notifier.cambiarMedioPago,
            ),
          ],
          const _Seccion('PRODUCTOS'),
          productosAsync.when(
            data: (productos) => GrillaMosaicos(
              conSubtitulo: true,
              children: [
                for (final p in productos)
                  Mosaico(
                    key: Key('producto_${p.id}'),
                    titulo: p.nombre,
                    subtitulo: formatoMoneda(p.precio),
                    cantidad: ticket.cantidadDe('p${p.id}'),
                    onTap: () => notifier.agregarProducto(p),
                  ),
                Mosaico(
                  key: const Key('boton_otro_monto'),
                  titulo: '+ Otro',
                  subtitulo: 'monto',
                  destacado: true,
                  onTap: _otroMonto,
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
          const _Seccion('MONTOS RÁPIDOS'),
          MontoRapidoGrid(
            onSeleccionar: notifier.agregarMonto,
            cantidadDe: (monto) => ticket.cantidadDe('m$monto'),
          ),
        ],
      ),
      bottomNavigationBar: _BarraCobro(
        ticket: ticket,
        cobrando: _cobrando,
        onCobrar: _cobrar,
        onVerTicket: _verTicket,
        onVaciar: notifier.vaciar,
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}

class _BarraCobro extends StatelessWidget {
  const _BarraCobro({
    required this.ticket,
    required this.cobrando,
    required this.onCobrar,
    required this.onVerTicket,
    required this.onVaciar,
  });

  final Ticket ticket;
  final bool cobrando;
  final VoidCallback onCobrar;
  final VoidCallback onVerTicket;
  final VoidCallback onVaciar;

  @override
  Widget build(BuildContext context) {
    final total = formatoMoneda(ticket.total);
    final cliente = ticket.clienteParaCobrar;
    final texto = !ticket.esFiado
        ? (ticket.medioPago == MedioPago.transferencia
              ? 'Cobrar $total por QR'
              : 'Cobrar $total')
        : cliente == null
        ? 'Fiar $total'
        : 'Fiar $total a ${cliente.nombre}';
    final String? aviso = ticket.estaVacio
        ? 'Agrega algo para cobrar'
        : (ticket.esFiado && cliente == null)
        ? 'Falta elegir el cliente'
        : null;
    final n = ticket.cantidadArticulos;

    return Material(
      color: ColoresApp.superficie,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ColoresApp.borde)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      n == 1 ? '1 artículo' : '$n artículos',
                      key: const Key('texto_articulos'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.textoSecundario),
                    ),
                  ),
                  // Los botones van lado a lado si caben; con letra muy
                  // grande se apilan en vez de cortarse o desbordarse.
                  Expanded(
                    flex: 3,
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      children: [
                        TextButton(
                          key: const Key('boton_ver_ticket'),
                          onPressed: ticket.estaVacio ? null : onVerTicket,
                          child: const Text('Ver ticket'),
                        ),
                        TextButton(
                          key: const Key('boton_vaciar'),
                          style: TextButton.styleFrom(
                            foregroundColor: ColoresApp.sale,
                          ),
                          onPressed: ticket.estaVacio ? null : onVaciar,
                          child: const Text('Vaciar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (aviso != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    aviso,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
              BotonPrincipal(
                key: const Key('boton_cobrar'),
                texto: texto,
                variante: VarianteBoton.entra,
                onPressed: ticket.puedeCobrar && !cobrando ? onCobrar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaTicket extends ConsumerWidget {
  const _HojaTicket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    if (ticket.estaVacio) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('El ticket está vacío', textAlign: TextAlign.center),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final linea in ticket.lineas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              linea.etiqueta,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${linea.cantidad} × ${formatoMoneda(linea.precio)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('restar_${linea.clave}'),
                  tooltip: 'Quitar uno',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () => notifier.restar(linea.clave),
                ),
                IconButton(
                  key: Key('sumar_${linea.clave}'),
                  tooltip: 'Agregar uno',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () => notifier.sumar(linea.clave),
                ),
                IconButton(
                  key: Key('quitar_${linea.clave}'),
                  tooltip: 'Quitar del ticket',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: ColoresApp.sale,
                  ),
                  onPressed: () => notifier.quitar(linea.clave),
                ),
              ],
            ),
          ),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Total',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Monto(ticket.total, tamano: 22),
          ],
        ),
      ],
    );
  }
}

class _HojaOtroMonto extends StatefulWidget {
  const _HojaOtroMonto();

  @override
  State<_HojaOtroMonto> createState() => _HojaOtroMontoState();
}

class _HojaOtroMontoState extends State<_HojaOtroMonto> {
  int _monto = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Monto(_monto, tamano: 36)),
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) =>
              setState(() => _monto = aplicarTecla(_monto, tecla)),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_agregar_monto'),
          texto: 'Agregar al ticket',
          onPressed: _monto > 0
              ? () => Navigator.of(context).pop(_monto)
              : null,
        ),
      ],
    );
  }
}
