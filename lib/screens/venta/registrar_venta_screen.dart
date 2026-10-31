import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/aviso_por_pedir_provider.dart';
import '../../providers/consejos_provider.dart';
import '../../providers/orden_productos_provider.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../repositories/venta_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_escanear.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/mosaico.dart';
import '../../ui/teclado_monto.dart';
import '../../servicios/dictado.dart';
import '../../servicios/lector_codigo.dart';
import '../../util/aviso_existencias.dart';
import '../../util/busqueda_producto.dart';
import '../configuracion/producto_screen.dart';
import '../escaner/consejos_escaner.dart';
import '../../util/catalogo_producto.dart';
import '../../util/formato_moneda.dart';
import '../../util/interpretar_dictado.dart';
import '../../util/texto_util.dart';
import '../../util/orden_productos.dart';
import '../../widgets/hoja_orden_productos.dart';
import '../../widgets/monto_rapido_grid.dart';
import '../qr/cobro_qr_screen.dart';
import '../../providers/recorrido_provider.dart';
import '../../ui/recorrido/globos.dart';
import '../../ui/recorrido/objetivo_recorrido.dart';
import '../recorrido/globos_venta.dart';
import 'hoja_como_paga.dart';
import 'hoja_dictado.dart';
import 'hoja_producto_rapido.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen({
    super.key,
    this.practica = false,
    this.conGlobos = true,
    this.dictarAlAbrir = false,
    this.escanearAlAbrir = false,
  });

  /// Venta de práctica del recorrido: guía con globos y no guarda nada.
  final bool practica;

  /// Solo para pruebas: práctica sin guía, para probar otras formas de pago
  /// (con la guía solo se puede tocar Efectivo).
  final bool conGlobos;

  /// Desde "Vender por voz" del Inicio: empieza a escuchar al abrir.
  final bool dictarAlAbrir;

  /// Desde "Vender escaneando" del recorrido: abre el escáner al abrir.
  final bool escanearAlAbrir;

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

  /// Tipo elegido en los chips (null = todos).
  String? _tipo;

  /// Último código leído y cuándo, para no sumar dos veces la misma lectura.
  String? _ultimoCodigo;
  DateTime? _ultimaLectura;

  Future<void> _escanear() async {
    // Tocar el botón con el consejo abierto lo da por entendido.
    _consejo?.entender();
    final codigo = await ref
        .read(lectorCodigoProvider)
        .leer(
          context,
          uso: widget.practica ? UsoEscaner.practica : UsoEscaner.venta,
        );
    if (codigo == null || !mounted) return;
    await _usarCodigo(codigo);
  }

  /// Agrega el producto con [codigo]; si no existe, ofrece crearlo.
  Future<void> _usarCodigo(String codigo) async {
    final limpio = codigo.trim();
    final ahora = DateTime.now();
    if (limpio == _ultimoCodigo &&
        _ultimaLectura != null &&
        ahora.difference(_ultimaLectura!) <
            const Duration(milliseconds: 1500)) {
      return;
    }
    _ultimoCodigo = limpio;
    _ultimaLectura = ahora;
    final notifier = ref.read(ticketProvider.notifier);
    final producto = await ref
        .read(productoRepositoryProvider)
        .productoPorCodigo(limpio);
    if (!mounted) return;
    if (producto != null && producto.activo) {
      notifier.agregarProducto(producto);
      _avisarAgregado(producto);
    } else if (producto != null) {
      _avisarInactivo(producto);
    } else {
      final nuevo = await mostrarHojaProductoRapido(context, codigo: limpio);
      if (nuevo != null && mounted) notifier.agregarProducto(nuevo);
    }
  }

  void _avisarInactivo(Producto producto) => avisar(
    context,
    'Ese código es de ${producto.nombre} (inactivo). Reactívalo en Productos',
    error: true,
  );

  /// Aviso de producto agregado; el admin puede tocar "Editar" desde él.
  void _avisarAgregado(Producto producto) {
    // La práctica no ofrece editar: no debe tocar productos reales.
    final esAdmin = ref.read(sesionProvider).esAdmin && !widget.practica;
    avisar(
      context,
      '${producto.nombre} agregado',
      etiquetaAccion: esAdmin ? 'Editar' : null,
      onAccion: esAdmin ? () => _editarProducto(producto) : null,
    );
  }

  /// Abre el editor del producto. Las líneas del ticket guardan su propio
  /// precio, así que lo ya agregado no cambia.
  Future<void> _editarProducto(Producto producto) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoScreen(producto: producto)),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  /// Hoja con "Editar producto", solo para el admin fuera de la práctica.
  Future<void> _menuProducto(Producto producto) async {
    final editar = await mostrarHojaInferior<bool>(
      context,
      titulo: producto.nombre,
      builder: (contexto) => ListTile(
        key: const Key('menu_editar_producto'),
        leading: const Icon(Icons.edit_outlined),
        title: const Text('Editar producto'),
        onTap: () => Navigator.of(contexto).pop(true),
      ),
    );
    if (editar == true && mounted) await _editarProducto(producto);
  }

  /// Enter en el buscador con un código exacto (p. ej. un lector físico).
  Future<void> _alEnviarBusqueda(String texto) async {
    final p = await ref
        .read(productoRepositoryProvider)
        .productoPorCodigo(texto);
    if (!mounted) return;
    if (p == null) {
      final sinEspacios = texto.replaceAll(RegExp(r'\s'), '');
      // Solo un texto que parece código avisa; "coca" es una búsqueda normal.
      if (RegExp(r'^\d{8,}$').hasMatch(sinEspacios)) {
        avisar(
          context,
          'No hay ningún producto con el código $sinEspacios',
          error: true,
        );
      }
      return;
    }
    if (!p.activo) {
      _avisarInactivo(p);
      return;
    }
    ref.read(ticketProvider.notifier).agregarProducto(p);
    _busqueda.clear();
    setState(() => _filtro = '');
    _avisarAgregado(p);
  }

  /// El dictado en curso, para detenerlo si se cierra la pantalla.
  Dictado? _dictado;

  /// Lo que va oyendo el dictado (null = no está escuchando).
  String? _oyendo;

  /// Evita abrir dos dictados con un doble toque mientras se prepara.
  bool _preparandoDictado = false;

  Future<void> _dictar() async {
    if (_preparandoDictado) return;
    var otraVez = true;
    while (otraVez && mounted) {
      otraVez = await _dictarUnaVez();
    }
  }

  /// Un dictado completo; devuelve true si piden "Dictar otra vez".
  Future<bool> _dictarUnaVez() async {
    final dictado = ref.read(dictadoProvider);
    _preparandoDictado = true;
    setState(() {});
    final EstadoDictado estado;
    try {
      estado = await dictado.preparar();
    } finally {
      _preparandoDictado = false;
      if (mounted) setState(() {});
    }
    if (!mounted) return false;
    switch (estado) {
      case EstadoDictado.sinPermiso:
        avisar(
          context,
          'Para dictar, permite el micrófono en Ajustes del celular → Apps → '
          'VeciTienda → Permisos',
          error: true,
        );
        return false;
      case EstadoDictado.noDisponible:
        _avisarSinDictado();
        return false;
      case EstadoDictado.sinDictadoLocal:
        avisar(
          context,
          'Este celular no permite dictar sin internet',
          error: true,
        );
        return false;
      case EstadoDictado.listo:
    }
    setState(() {
      _dictado = dictado;
      _oyendo = '';
    });
    String? texto;
    try {
      texto = await dictado.escuchar(
        alOir: (t) {
          // Lo que llega después de "Listo" ya no se muestra.
          if (mounted && _dictado != null) setState(() => _oyendo = t);
        },
      );
    } on DictadoNoDisponible {
      if (mounted) _avisarSinDictado();
      texto = null;
      if (mounted) setState(() => _oyendo = null);
      _dictado = null;
      return false;
    }
    _dictado = null;
    if (!mounted) return false;
    setState(() => _oyendo = null);
    if (texto == null || texto.trim().isEmpty) {
      avisar(context, 'No te escuché, intenta de nuevo', error: true);
      return false;
    }
    final productos = await ref.read(productosActivosProvider.future);
    if (!mounted) return false;
    final partes = interpretarDictado(texto, productos);
    // Si no reconoció nada, lo oído sirve como búsqueda a mano.
    if (partes.every((p) => p.tipo == TipoParteDictada.noEncontrada)) {
      _buscarTexto(
        partes.isEmpty ? texto : partes.map((p) => p.texto).join(' '),
      );
      return false;
    }
    final respuesta = await mostrarHojaDictado(
      context,
      oido: texto,
      partes: partes,
    );
    if (!mounted) return false;
    switch (respuesta) {
      case AgregarDictado(:final lineas):
        final ticket = ref.read(ticketProvider.notifier);
        for (final l in lineas) {
          ticket.agregarProducto(l.producto, cantidad: l.cantidad);
        }
      case BuscarDictado(:final texto):
        _buscarTexto(texto);
      case DictarOtraVez():
        return true;
      case null:
    }
    return false;
  }

  void _avisarSinDictado() => avisar(
    context,
    'El dictado no está disponible. Descarga el español sin conexión en los '
    'ajustes de voz de Google del celular',
    error: true,
  );

  /// Pone [texto] en el buscador; con pocos productos no hay buscador y se
  /// avisa lo que no se encontró.
  void _buscarTexto(String texto) {
    final hayBuscador =
        (ref.read(productosActivosProvider).valueOrNull?.length ?? 0) >
        _productosSinBuscador;
    if (!hayBuscador) {
      avisar(context, 'No encontré: $texto', error: true);
      return;
    }
    _busqueda.text = texto;
    setState(() => _filtro = sinTildes(texto.trim()));
  }

  /// Globos de la venta de práctica (solo con [RegistrarVentaScreen.practica]).
  ControladorGlobos? _globos;

  /// Consejo de primera vez sobre "Escanear código".
  ControladorGlobos? _consejo;

  @override
  void initState() {
    super.initState();
    if (widget.dictarAlAbrir && !widget.practica) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dictar();
      });
    }
    if (widget.escanearAlAbrir && !(widget.practica && widget.conGlobos)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _escanear();
      });
    }
    // En la práctica ya hay guía, y al dictar o escanear el consejo
    // estorbaría.
    if (!widget.practica && !widget.dictarAlAbrir && !widget.escanearAlAbrir) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vistos = ref.read(consejosVistosProvider);
        if (vistos.contains(Consejo.escanearVenta)) return;
        _consejo = mostrarConsejo(
          context,
          consejoEscanearVenta,
          alCerrar: () => ref
              .read(consejosVistosProvider.notifier)
              .marcarVisto(Consejo.escanearVenta),
        );
      });
    }
    if (widget.practica && widget.conGlobos) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Los globos viven en la capa raíz: encima del escáner lo taparían,
        // así que esperan a que se cierre.
        if (widget.escanearAlAbrir) await _escanear();
        if (!mounted) return;
        _globos = mostrarGlobos(
          context,
          globosVenta,
          onSaltar: _saltarRecorrido,
        );
        // Si ya escaneó un producto, el siguiente paso es cobrar.
        if (!ref.read(ticketProvider).estaVacio) _globos!.irA(1);
      });
    }
  }

  @override
  void dispose() {
    // Cerrar la pantalla mientras escucha apaga el micrófono.
    _dictado?.detener();
    _globos?.cerrar();
    _consejo?.cerrar();
    _busqueda.dispose();
    super.dispose();
  }

  void _saltarRecorrido() {
    ref.read(recorridoProvider.notifier).saltar();
    if (!mounted) return;
    // Si la hoja "¿Cómo paga?" está abierta, se cierra primero.
    final navegador = Navigator.of(context);
    final esta = ModalRoute.of(context);
    navegador.popUntil((ruta) => ruta == esta);
    navegador.pop();
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
          Text(
            '${plural(ticket.cantidadArticulos, 'artículo', 'artículos')}'
            ' · ${formatoMoneda(ticket.total)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Esta venta fue de práctica, no quedó en tus cuentas.',
            style: TextStyle(color: ColoresApp.of(contexto).textoSecundario),
          ),
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
    // Solo si sigue en curso (no si se saltó mientras tanto).
    if (ref.read(recorridoProvider) == PasoRecorrido.venta) {
      await recorrido.irA(PasoRecorrido.inicio);
    }
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
    final forma = await mostrarHojaComoPaga(context, practica: widget.practica);
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
      notifier.cambiarMedioPago(
        forma == FormaPago.transferencia
            ? MedioPago.transferencia
            : MedioPago.efectivo,
      );
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
      final cliente = ticket.clienteParaCobrar;
      if (cliente != null) {
        clienteId =
            cliente.id ??
            await ref
                .read(clienteRepositoryProvider)
                .crearCliente(
                  nombre: cliente.nombre,
                  apellido: cliente.apellido,
                  telefono: cliente.telefono,
                );
        // Con el id en el ticket, un reintento no vuelve a crear al cliente.
        if (cliente.id == null) {
          ref
              .read(ticketProvider.notifier)
              .elegirCliente(
                ClienteTicket(
                  id: clienteId,
                  nombre: cliente.nombre,
                  apellido: cliente.apellido,
                  telefono: cliente.telefono,
                ),
              );
        }
      }
      final ventaRepo = ref.read(ventaRepositoryProvider);
      final inventario = ref.read(inventarioRepositoryProvider);
      // El aviso de reposición no debe impedir cobrar: ante cualquier error
      // se vende sin aviso.
      Map<int, int> antes = const {};
      try {
        antes = await inventario.existenciasDe(
          ticket.lineas.map((l) => l.productoId).whereType<int>(),
        );
      } catch (_) {}
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
      var avisos = const <AvisoExistencias>[];
      try {
        avisos = await inventario.avisosTrasVenta(antes);
      } catch (_) {}
      if (!mounted) return;
      // Se lee antes del pop: el Deshacer vive más que esta pantalla.
      final avisoNotifier = ref.read(avisoPorPedirProvider.notifier);
      try {
        await avisoNotifier.trasVenta(avisos);
      } catch (_) {}
      if (!mounted) return;
      avisar(
        context,
        'Venta registrada · ${formatoMoneda(ticket.total)}',
        onDeshacer: () async {
          await ventaRepo.eliminarVenta(ventaId);
          // Sin poder recalcular, un aviso viejo sería peor que ninguno.
          try {
            await avisoNotifier.recalcular();
          } catch (_) {
            avisoNotifier.cerrar();
          }
        },
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

    final conBuscador =
        (productosAsync.valueOrNull?.length ?? 0) > _productosSinBuscador;
    final tiposEnUso = [
      for (final t in tiposProducto.keys)
        if ((productosAsync.valueOrNull ?? const <Producto>[]).any(
          (p) => p.tipo == t,
        ))
          t,
    ];
    // El tipo elegido solo filtra mientras sus chips se ven.
    final tipoActivo = conBuscador && tiposEnUso.length >= 2 ? _tipo : null;
    final lista = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Seccion('PRODUCTOS'),
        productosAsync.when(
          data: (productos) {
            final orden = ref.watch(
              ordenProductosProvider(ListadoProductos.venta),
            );
            final ordenados = ordenarProductos(
              productos,
              orden,
              vendidos: orden == OrdenProductos.masVendidos
                  ? ref.watch(unidadesVendidasProvider).valueOrNull ?? const {}
                  : const {},
            );
            final visibles = [
              for (final p in ordenados)
                if (coincideBusqueda(p, _busqueda.text) &&
                    (tipoActivo == null || p.tipo == tipoActivo))
                  p,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_filtro.isNotEmpty && visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Sin resultados',
                      key: const Key('texto_sin_resultados'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColoresApp.of(context).textoSecundario,
                      ),
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
                          subtitulo: p.tamano == null
                              ? formatoMoneda(p.precio)
                              : '${p.tamano} · ${formatoMoneda(p.precio)}',
                          cantidad: ticket.cantidadDe('p${p.id}'),
                          onTap: () => notifier.agregarProducto(p),
                          onRestar: () => notifier.restar('p${p.id}'),
                          onLongPress:
                              ref.watch(sesionProvider).esAdmin &&
                                  !widget.practica
                              ? () => _menuProducto(p)
                              : null,
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
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          // En la práctica no se crean productos reales.
          if (!widget.practica)
            const BotonOrdenProductos(
              key: Key('boton_orden_venta'),
              listado: ListadoProductos.venta,
              conMasVendidos: true,
            ),
          if (!widget.practica)
            IconButton(
              key: const Key('boton_dictar'),
              tooltip: 'Dictar venta',
              icon: const Icon(Icons.mic_rounded),
              onPressed: _oyendo == null && !_preparandoDictado
                  ? _dictar
                  : null,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_oyendo != null)
            Container(
              key: const Key('franja_dictado'),
              width: double.infinity,
              color: c.primarioSuave,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.mic_rounded, color: c.primario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _oyendo!.isEmpty ? 'Te escucho…' : _oyendo!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('boton_listo_dictado'),
                    onPressed: () {
                      final dictado = _dictado;
                      _dictado = null;
                      dictado?.detener();
                    },
                    child: const Text('Listo'),
                  ),
                ],
              ),
            ),
          if (widget.practica)
            Container(
              key: const Key('franja_practica'),
              width: double.infinity,
              color: c.fiadoSuave,
              padding: const EdgeInsets.all(8),
              child: Text(
                'MODO PRÁCTICA · no se guarda',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.fiado, fontWeight: FontWeight.w700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ObjetivoRecorrido(
              id: 'boton_escanear_venta',
              child: BotonEscanear(
                key: const Key('boton_escanear_venta'),
                onPressed: _escanear,
              ),
            ),
          ),
          // Fijo arriba: sigue a la vista aunque se baje por la lista.
          if (conBuscador)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                key: const Key('buscador_productos'),
                controller: _busqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar producto…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _filtro.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('borrar_busqueda'),
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _busqueda.clear();
                            setState(() => _filtro = '');
                          },
                        ),
                ),
                onChanged: (t) => setState(() => _filtro = sinTildes(t.trim())),
                textInputAction: TextInputAction.search,
                onSubmitted: _alEnviarBusqueda,
              ),
            ),
          if (conBuscador && tiposEnUso.length >= 2)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: const Key('filtro_tipo_venta_todos'),
                      label: const Text('Todos'),
                      selected: _tipo == null,
                      onSelected: (_) => setState(() => _tipo = null),
                    ),
                  ),
                  for (final t in tiposEnUso)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('filtro_tipo_venta_$t'),
                        label: Text(nombreTipo(t)),
                        selected: _tipo == t,
                        onSelected: (_) => setState(() => _tipo = t),
                      ),
                    ),
                ],
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
                      style: TextStyle(
                        color: ColoresApp.of(context).textoSecundario,
                      ),
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
