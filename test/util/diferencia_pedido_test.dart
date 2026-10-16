import 'package:app_ventas/util/diferencia_pedido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada caso de pedido contra llegado tiene su estado y su texto', () {
    final casos = [
      (24, 24, EstadoLineaPedido.completo, 'Completo'),
      (12, 6, EstadoLineaPedido.faltan, 'Faltan 6'),
      (12, 0, EstadoLineaPedido.noLlego, 'No llegó'),
      (12, 14, EstadoLineaPedido.deMas, 'Llegaron 2 de más'),
      (null, 6, EstadoLineaPedido.extra, 'Extra'),
    ];
    for (final (pedido, llego, estado, texto) in casos) {
      expect(estadoLineaPedido(pedido: pedido, llego: llego), estado);
      expect(textoEstadoLinea(estado, pedido: pedido, llego: llego), texto);
    }
  });
}
