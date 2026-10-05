import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../util/formato_moneda.dart';

class LineaTicket {
  const LineaTicket({
    required this.clave,
    required this.etiqueta,
    required this.precio,
    this.cantidad = 1,
    this.productoId,
  });

  /// `p<idProducto>` para productos, `m<monto>` para montos sueltos.
  final String clave;
  final String etiqueta;
  final int precio;
  final int cantidad;
  final int? productoId;

  int get subtotal => precio * cantidad;

  LineaTicket conCantidad(int nueva) => LineaTicket(
        clave: clave,
        etiqueta: etiqueta,
        precio: precio,
        cantidad: nueva,
        productoId: productoId,
      );
}

/// Cliente de una venta fiada. [id] null = cliente nuevo por crear al cobrar.
class ClienteTicket {
  const ClienteTicket({this.id, required this.nombre});

  final int? id;
  final String nombre;
}

class Ticket {
  const Ticket({this.lineas = const [], this.esFiado = false, this.cliente});

  final List<LineaTicket> lineas;
  final bool esFiado;
  final ClienteTicket? cliente;

  int get total => lineas.fold(0, (suma, l) => suma + l.subtotal);
  int get cantidadArticulos => lineas.fold(0, (suma, l) => suma + l.cantidad);
  bool get estaVacio => lineas.isEmpty;

  /// Producto de la venta: solo si el ticket tiene una única línea y es de
  /// producto; si no, la venta queda sin producto.
  int? get productoIdUnico =>
      lineas.length == 1 ? lineas.single.productoId : null;

  bool get puedeCobrar => !estaVacio && (!esFiado || cliente != null);

  int cantidadDe(String clave) {
    for (final linea in lineas) {
      if (linea.clave == clave) return linea.cantidad;
    }
    return 0;
  }
}

class TicketNotifier extends AutoDisposeNotifier<Ticket> {
  @override
  Ticket build() => const Ticket();

  void agregarProducto(Producto producto) => _agregar(LineaTicket(
        clave: 'p${producto.id}',
        etiqueta: producto.nombre,
        precio: producto.precio,
        productoId: producto.id,
      ));

  void agregarMonto(int monto) {
    if (monto <= 0) return;
    _agregar(LineaTicket(
      clave: 'm$monto',
      etiqueta: formatoMoneda(monto),
      precio: monto,
    ));
  }

  void sumar(String clave) => _cambiarCantidad(clave, 1);

  void restar(String clave) => _cambiarCantidad(clave, -1);

  void quitar(String clave) => _conLineas(
      [for (final l in state.lineas) if (l.clave != clave) l]);

  void vaciar() => _conLineas(const []);

  void cambiarFiado(bool esFiado) => state = Ticket(
        lineas: state.lineas,
        esFiado: esFiado,
        cliente: esFiado ? state.cliente : null,
      );

  void elegirCliente(ClienteTicket? cliente) => state =
      Ticket(lineas: state.lineas, esFiado: state.esFiado, cliente: cliente);

  void _agregar(LineaTicket nueva) {
    if (state.cantidadDe(nueva.clave) > 0) {
      _cambiarCantidad(nueva.clave, 1);
    } else {
      _conLineas([...state.lineas, nueva]);
    }
  }

  void _cambiarCantidad(String clave, int delta) => _conLineas([
        for (final l in state.lineas)
          if (l.clave != clave)
            l
          else if (l.cantidad + delta > 0)
            l.conCantidad(l.cantidad + delta),
      ]);

  void _conLineas(List<LineaTicket> lineas) => state =
      Ticket(lineas: lineas, esFiado: state.esFiado, cliente: state.cliente);
}

/// Ticket de la pantalla "Nueva venta". Se descarta al salir de la pantalla.
final ticketProvider =
    NotifierProvider.autoDispose<TicketNotifier, Ticket>(TicketNotifier.new);
