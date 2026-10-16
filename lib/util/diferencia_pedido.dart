/// Cómo llegó un producto comparado con lo que se pidió.
enum EstadoLineaPedido { completo, faltan, noLlego, deMas, extra }

/// [pedido] null: el producto no estaba en el pedido.
EstadoLineaPedido estadoLineaPedido({int? pedido, required int llego}) {
  if (pedido == null) return EstadoLineaPedido.extra;
  if (llego == 0) return EstadoLineaPedido.noLlego;
  if (llego < pedido) return EstadoLineaPedido.faltan;
  if (llego > pedido) return EstadoLineaPedido.deMas;
  return EstadoLineaPedido.completo;
}

String textoEstadoLinea(
  EstadoLineaPedido estado, {
  int? pedido,
  required int llego,
}) => switch (estado) {
  EstadoLineaPedido.completo => 'Completo',
  EstadoLineaPedido.faltan => 'Faltan ${pedido! - llego}',
  EstadoLineaPedido.noLlego => 'No llegó',
  EstadoLineaPedido.deMas => 'Llegaron ${llego - pedido!} de más',
  EstadoLineaPedido.extra => 'Extra',
};
