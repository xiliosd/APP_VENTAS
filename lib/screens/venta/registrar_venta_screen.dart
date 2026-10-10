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
import '../../ui/teclado_monto.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import '../../widgets/monto_rapido_grid.dart';
import '../qr/cobro_qr_screen.dart';
import '../../providers/recorrido_provider.dart';
import '../../ui/recorrido/globos.dart';
import '../../ui/recorrido/objetivo_recorrido.dart';
import '../recorrido/globos_venta.dart';
import 'hoja_como_paga.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen(
      {super.key, this.practica = false, this.conGlobos = true});

  /// Venta de práctica del recorrido: guía con globos y no guarda nada.
  final bool practica;

  /// Solo para pruebas: práctica sin guía, para probar otras formas de pago
  /// (con la guía solo se puede tocar Efectivo).
  final bool conGlobos;

  @override
  ConsumerState<RegistrarVentaScreen> createState() =>
      _RegistrarVentaScreenState();
}

class _RegistrarVentaScreenState extends ConsumerState<RegistrarVentaScreen> {
  /// Evita registrar dos veces el mismo ticket con un doble toque.
  bool _cobrando = false;

  /// Con más de estos productos aparece el buscador.
  static const _productosSinBuscador = 6;
  final _busqueda = TextEditingController();
  String _filtro = '';

  /// Globos de la venta de práctica (solo con [RegistrarVentaScreen.practica]).
  ControladorGlobos? _globos;

  @override
  void initState() {
    super.initState();
    if (widget.practica && widget.conGlobos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _globos =
            mostrarGlobos(context, globosVenta, onSaltar: _saltarRecorrido);
      });
    }
  }

  @override
  void dispose() {
    _globos?.cerrar();
    _busqueda.dispose();
    super.dispose();
  }

  void _saltarRecorrido() {
    ref.read(recorridoProvider.notifier).saltar();
    if (mounted) Navigator.of(context).pop();
  }

  /// Muestra el resultado de la práctica, vacía el ticket y vuelve al Inicio
  /// (que sigue con los globos del Inicio).
  Future<void> _terminarPractica() async {
    final ticket = ref.read(ticketProvider);
    await mostrarHojaInferior<void>(
      context,
      titulo: '¡Así de fácil!',
      descartable: false,
      builder: (contexto) => Column(
        key: const Key('hoja_asi_de_facil'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${plural(ticket.cantidadArticulos, 'artículo', 'artículos')}'
              ' · ${formatoMoneda(ticket.total)}'),
          const SizedBox(height: 4),
          Text('Esta venta fue de práctica, no quedó en tus cuentas.',
              style:
                  TextStyle(color: ColoresApp.of(contexto).textoSecundario)),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_continuar_practica'),
            texto: 'Continuar',
            variante: VarianteBoton.entra,
            onPressed: () => Navigator.of(contexto).pop(),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final recorrido = ref.read(recorridoProvider.notifier);
    ref.read(ticketProvider.notifier).vaciar();
    // Primero se cierra: así el Inicio ya está a la vista cuando reacciona.
    Navigator.of(context).pop(true);
    await recorrido.irA(PasoRecorrido.inicio);
  }

  void _vaciar() {
    ref.read(ticketProvider.notifier).vaciar();
    _busqueda.clear();
    setState(() => _filtro = '');
  }

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

  /// Pregunta cómo paga y, si elige, fija la forma de pago en el ticket y
  /// cobra. Cerrar la hoja sin elegir deja el ticket como estaba (contado).
  Future<void> _alCobrar() async {
    if (_cobrando) return;
    final notifier = ref.read(ticketProvider.notifier);
    // En la práctica, la capa de globos pasa encima de la hoja.
    if (widget.practica && _globos?.indice == 1) _globos!.avanzar();
    final forma = await mostrarHojaComoPaga(context);
    if (!mounted) return;
    if (forma == null) {
      notifier.cambiarFiado(false);
      if (widget.practica) _globos?.irA(1);
      return;
    }
    if (widget.practica) {
      _globos?.cerrar();
      await _terminarPractica();
      return;
    }
    if (forma != FormaPago.fiado) {
      notifier.cambiarFiado(false);
      notifier.cambiarMedioPago(forma == FormaPago.transferencia
          ? MedioPago.transferencia
          : MedioPago.efectivo);
    }
    await _cobrar();
  }

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
    if (widget.practica) {
      ref.listen(ticketProvider, (antes, ahora) {
        if (_globos?.indice == 0 &&
            (antes?.estaVacio ?? true) &&
            !ahora.estaVacio) {
          _globos!.avanzar();
        }
      });
    }

    final lista = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Seccion('PRODUCTOS'),
          productosAsync.when(
            data: (productos) {
              final visibles = [
                for (final p in productos)
                  if (_filtro.isEmpty || sinTildes(p.nombre).contains(_filtro))
                    p,
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (productos.length > _productosSinBuscador) ...[
                    TextField(
                      key: const Key('buscador_productos'),
                      controller: _busqueda,
                      decoration: const InputDecoration(
                        hintText: 'Buscar producto…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (t) =>
                          setState(() => _filtro = sinTildes(t.trim())),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_filtro.isNotEmpty && visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Sin resultados',
                        key: const Key('texto_sin_resultados'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ColoresApp.of(context).textoSecundario),
                      ),
                    ),
                  GrillaMosaicos(
              conSubtitulo: true,
              children: [
                for (final (i, p) in visibles.indexed)
                  ObjetivoRecorrido(
                    id: i == 0 ? 'primer_producto' : 'producto_${p.id}',
                    child: Mosaico(
                      key: Key('producto_${p.id}'),
                      titulo: p.nombre,
                      subtitulo: formatoMoneda(p.precio),
                      cantidad: ticket.cantidadDe('p${p.id}'),
                      onTap: () => notifier.agregarProducto(p),
                    ),
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
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
          const _Seccion('MONTOS RÁPIDOS'),
          MontoRapidoGrid(
            onSeleccionar: notifier.agregarMonto,
            cantidadDe: (monto) => ticket.cantidadDe('m$monto'),
          ),
        ],
      );
    final c = ColoresApp.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: !widget.practica
          ? lista
          : Column(
              children: [
                Container(
                  key: const Key('franja_practica'),
                  width: double.infinity,
                  color: c.fiadoSuave,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'MODO PRÁCTICA · no se guarda',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: c.fiado, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: lista),
              ],
            ),
      bottomNavigationBar: _BarraCobro(
        ticket: ticket,
        cobrando: _cobrando,
        onCobrar: _alCobrar,
        onVerTicket: _verTicket,
        onVaciar: _vaciar,
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.of(context).textoSecundario,
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
    final c = ColoresApp.of(context);
    final texto = 'Cobrar ${formatoMoneda(ticket.total)}';
    final String? aviso = ticket.estaVacio ? 'Agrega algo para cobrar' : null;
    final n = ticket.cantidadArticulos;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: c.texto.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                      style: TextStyle(color: ColoresApp.of(context).textoSecundario),
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
                            foregroundColor: ColoresApp.of(context).sale,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: ColoresApp.of(context).textoSecundario,
                    ),
                  ),
                ),
              ObjetivoRecorrido(
                id: 'boton_cobrar',
                child: BotonPrincipal(
                  key: const Key('boton_cobrar'),
                  texto: texto,
                  variante: VarianteBoton.entra,
                  onPressed: !ticket.estaVacio && !cobrando ? onCobrar : null,
                ),
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
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: ColoresApp.of(context).sale,
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
