import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../repositories/historial_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/teclado_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/permisos.dart';
import '../../widgets/selector_cliente.dart';
import 'texto_correccion.dart';

/// Lo que la hoja necesita de un movimiento, venga del Historial o de Fiado.
class MovimientoEditable {
  const MovimientoEditable({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.clienteId,
    this.nombreCliente,
    this.medioPago = MedioPago.efectivo,
    this.descripcion,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  factory MovimientoEditable.desdeHistorial(
    MovimientoHistorial m, {
    String? nombreCliente,
  }) =>
      MovimientoEditable(
        tipo: m.tipo == TipoMovimientoHistorial.venta
            ? TipoMovimiento.venta
            : TipoMovimiento.gasto,
        id: m.id,
        monto: m.monto,
        fecha: m.fecha,
        usuarioId: m.usuarioId,
        esFiado: m.esFiado,
        clienteId: m.clienteId,
        nombreCliente: nombreCliente,
        medioPago: m.medioPago,
        descripcion: m.descripcion,
        anulado: m.anulado,
        ultimaCorreccion: m.ultimaCorreccion,
      );

  factory MovimientoEditable.desdeFiado(
    MovimientoFiado m, {
    required int clienteId,
    required String nombreCliente,
  }) {
    final esVenta = m.tipo == TipoMovimientoFiado.venta;
    return MovimientoEditable(
      tipo: esVenta ? TipoMovimiento.venta : TipoMovimiento.abono,
      id: m.id,
      monto: m.monto,
      fecha: m.fecha,
      usuarioId: m.usuarioId,
      esFiado: esVenta,
      clienteId: clienteId,
      nombreCliente: nombreCliente,
      medioPago: m.medioPago,
      anulado: m.anulado,
      ultimaCorreccion: m.ultimaCorreccion,
    );
  }

  final TipoMovimiento tipo;
  final int id;
  final int monto;
  final DateTime fecha;

  /// Quién lo registró.
  final int usuarioId;
  final bool esFiado;
  final int? clienteId;
  final String? nombreCliente;
  final MedioPago medioPago;
  final String? descripcion;
  final bool anulado;
  final Correccion? ultimaCorreccion;
}

String _titulo(TipoMovimiento tipo) => switch (tipo) {
      TipoMovimiento.venta => 'Venta',
      TipoMovimiento.abono => 'Abono',
      TipoMovimiento.gasto => 'Gasto',
    };

String _esteMovimiento(TipoMovimiento tipo) => switch (tipo) {
      TipoMovimiento.venta => 'esta venta',
      TipoMovimiento.abono => 'este abono',
      TipoMovimiento.gasto => 'este gasto',
    };

String _aviso(TipoMovimiento tipo, {required bool anulado}) => switch (tipo) {
      TipoMovimiento.venta => anulado ? 'Venta anulada' : 'Venta corregida',
      TipoMovimiento.abono => anulado ? 'Abono anulado' : 'Abono corregido',
      TipoMovimiento.gasto => anulado ? 'Gasto anulado' : 'Gasto corregido',
    };

String _nombreMedio(MedioPago medio) =>
    medio == MedioPago.efectivo ? 'Efectivo' : 'Transferencia';

/// Abre el detalle de [movimiento]; si se corrige o anula, avisa al cerrar.
Future<void> abrirHojaMovimiento(
  BuildContext context,
  MovimientoEditable movimiento,
) async {
  final aviso = await mostrarHojaInferior<String>(
    context,
    titulo: _titulo(movimiento.tipo),
    builder: (_) => HojaMovimiento(movimiento: movimiento),
  );
  if (aviso != null && context.mounted) avisar(context, aviso);
}

/// Detalle de un movimiento con Corregir y Anular si el usuario puede.
/// Al guardar o anular se cierra devolviendo el texto del aviso.
class HojaMovimiento extends ConsumerStatefulWidget {
  const HojaMovimiento({super.key, required this.movimiento});

  final MovimientoEditable movimiento;

  @override
  ConsumerState<HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends ConsumerState<HojaMovimiento> {
  bool _editando = false;
  late int _monto = widget.movimiento.monto;
  late bool _esFiado = widget.movimiento.esFiado;
  late MedioPago _medio = widget.movimiento.medioPago;
  late ClienteTicket? _cliente =
      widget.movimiento.esFiado && widget.movimiento.clienteId != null
          ? ClienteTicket(
              id: widget.movimiento.clienteId,
              nombre: widget.movimiento.nombreCliente ?? '')
          : null;
  String _escrito = '';
  late final _descripcion =
      TextEditingController(text: widget.movimiento.descripcion ?? '');

  /// True mientras se guarda; evita guardar dos veces con un doble toque.
  bool _guardando = false;
  String? _error;

  MovimientoEditable get _m => widget.movimiento;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  ClienteTicket? get _clienteElegido {
    if (_cliente != null) return _cliente;
    final nombre = _escrito.trim();
    return nombre.isEmpty ? null : ClienteTicket(nombre: nombre);
  }

  bool get _hayCambios {
    if (_monto != _m.monto) return true;
    return switch (_m.tipo) {
      TipoMovimiento.venta => _esFiado != _m.esFiado ||
          (_esFiado
              ? _clienteElegido?.id != _m.clienteId
              : _medio != _m.medioPago),
      TipoMovimiento.abono => _medio != _m.medioPago,
      TipoMovimiento.gasto =>
        _descripcion.text.trim() != (_m.descripcion?.trim() ?? ''),
    };
  }

  bool get _valido =>
      _monto > 0 &&
      (_m.tipo != TipoMovimiento.venta || !_esFiado || _clienteElegido != null);

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final por = ref.read(sesionProvider).usuarioActivo!;
      final repo = ref.read(correccionRepositoryProvider);
      switch (_m.tipo) {
        case TipoMovimiento.venta:
          int? clienteId;
          if (_esFiado) {
            final cliente = _clienteElegido!;
            clienteId = cliente.id ??
                await ref
                    .read(clienteRepositoryProvider)
                    .obtenerOCrearCliente(cliente.nombre);
          }
          await repo.corregirVenta(_m.id,
              monto: _monto,
              esFiado: _esFiado,
              clienteId: clienteId,
              medioPago: _medio,
              por: por);
        case TipoMovimiento.abono:
          await repo.corregirPago(_m.id,
              monto: _monto, medioPago: _medio, por: por);
        case TipoMovimiento.gasto:
          final descripcion = _descripcion.text.trim();
          await repo.corregirGasto(_m.id,
              monto: _monto,
              descripcion: descripcion.isEmpty ? null : descripcion,
              por: por);
      }
      if (mounted) {
        Navigator.of(context).pop(_aviso(_m.tipo, anulado: false));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _anular() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Anular ${_esteMovimiento(_m.tipo)} de '
            '${formatoMoneda(_m.monto)}?'),
        content: const Text('Ya no contará en los totales.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar_anular'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final por = ref.read(sesionProvider).usuarioActivo!;
      final repo = ref.read(correccionRepositoryProvider);
      switch (_m.tipo) {
        case TipoMovimiento.venta:
          await repo.anularVenta(_m.id, por: por);
        case TipoMovimiento.abono:
          await repo.anularPago(_m.id, por: por);
        case TipoMovimiento.gasto:
          await repo.anularGasto(_m.id, por: por);
      }
      if (mounted) Navigator.of(context).pop(_aviso(_m.tipo, anulado: true));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String get _detalle => switch (_m.tipo) {
        TipoMovimiento.venta => _m.esFiado
            ? 'Fiado · ${_m.nombreCliente ?? ''}'
            : 'Contado · ${_nombreMedio(_m.medioPago)}',
        TipoMovimiento.abono => 'Abono · ${_nombreMedio(_m.medioPago)}',
        TipoMovimiento.gasto => (_m.descripcion?.trim().isNotEmpty ?? false)
            ? _m.descripcion!.trim()
            : 'Gasto',
      };

  Widget? get _textoError => _error == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ColoresApp.sale),
          ),
        );

  @override
  Widget build(BuildContext context) =>
      _editando ? _formulario() : _vistaDetalle();

  Widget _vistaDetalle() {
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};
    final usuario = ref.watch(sesionProvider).usuarioActivo;
    final puede = usuario != null &&
        !_m.anulado &&
        puedeCorregir(
          usuario: usuario,
          duenoId: _m.usuarioId,
          fechaMovimiento: _m.fecha,
          ahora: DateTime.now(),
        );
    final correccion = _m.ultimaCorreccion;
    final error = _textoError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Monto(_m.monto, tamano: 32, tachado: _m.anulado),
        const SizedBox(height: 4),
        Text(_detalle, key: const Key('detalle_movimiento')),
        Text(
          '${nombres[_m.usuarioId] ?? ''} · ${formatoFechaHora(_m.fecha)}',
          style: const TextStyle(color: ColoresApp.textoSecundario),
        ),
        if (correccion != null) ...[
          const SizedBox(height: 8),
          Text(
            textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
            key: const Key('texto_correccion'),
            style: const TextStyle(color: ColoresApp.textoSecundario),
          ),
        ],
        ?error,
        if (puede) ...[
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_corregir'),
            texto: 'Corregir',
            onPressed: () => setState(() => _editando = true),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('boton_anular'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
            onPressed: _guardando ? null : _anular,
            child: const Text('Anular'),
          ),
        ],
      ],
    );
  }

  Widget _selectorMedio() => SelectorSegmentado<MedioPago>(
        key: const Key('editar_medio_pago'),
        opciones: const {
          MedioPago.efectivo: 'Efectivo',
          MedioPago.transferencia: 'Transferencia',
        },
        valor: _medio,
        onCambio: (medio) => setState(() => _medio = medio),
      );

  Widget _formulario() {
    final error = _textoError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_m.tipo == TipoMovimiento.venta) ...[
          SelectorSegmentado<bool>(
            key: const Key('editar_tipo_venta'),
            opciones: const {false: 'Contado', true: 'Fiado'},
            valor: _esFiado,
            onCambio: (fiado) => setState(() => _esFiado = fiado),
          ),
          const SizedBox(height: 12),
          if (_esFiado)
            SelectorCliente(
              elegido: _cliente,
              onElegir: (cliente) => setState(() => _cliente = cliente),
              onEscribir: (texto) => setState(() => _escrito = texto),
              exigir: true,
            )
          else
            _selectorMedio(),
        ],
        if (_m.tipo == TipoMovimiento.abono) _selectorMedio(),
        if (_m.tipo == TipoMovimiento.gasto)
          TextField(
            key: const Key('editar_descripcion'),
            controller: _descripcion,
            decoration: const InputDecoration(labelText: 'Descripción'),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        Center(child: Monto(_monto, tamano: 36)),
        ?error,
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) => setState(() {
            _monto = aplicarTecla(_monto, tecla);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_guardar_correccion'),
          texto: 'Guardar',
          onPressed: _hayCambios && _valido && !_guardando ? _guardar : null,
        ),
      ],
    );
  }
}
