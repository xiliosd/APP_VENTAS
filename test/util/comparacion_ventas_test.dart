import 'package:app_ventas/util/comparacion_ventas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin ventas ni ayer ni hoy no hay comparación', () {
    expect(comparacionVentas(0, 0, esHoy: true), isNull);
  });

  test('sin ventas ayer y con ventas hoy', () {
    final c = comparacionVentas(5000, 0, esHoy: true)!;
    expect(c.tendencia, TendenciaVentas.sinAnterior);
    expect(c.texto, 'Ayer no hubo ventas');
    expect(comparacionVentas(5000, 0, esHoy: false)!.texto,
        'El día anterior no hubo ventas');
  });

  test('sube y baja con porcentaje redondeado', () {
    final sube = comparacionVentas(112000, 100000, esHoy: true)!;
    expect(sube.tendencia, TendenciaVentas.sube);
    expect(sube.texto, '▲ 12 % vs. ayer');
    final baja = comparacionVentas(92000, 100000, esHoy: false)!;
    expect(baja.tendencia, TendenciaVentas.baja);
    expect(baja.texto, '▼ 8 % vs. el día anterior');
  });

  test('igual y casi igual', () {
    expect(comparacionVentas(5000, 5000, esHoy: true)!.texto, 'Igual que ayer');
    final casi = comparacionVentas(100400, 100000, esHoy: true)!;
    expect(casi.tendencia, TendenciaVentas.casiIgual);
    expect(casi.texto, 'Casi igual que ayer');
    expect(comparacionVentas(5000, 5000, esHoy: false)!.texto,
        'Igual que el día anterior');
  });

  test('de algo a cero baja 100 %', () {
    expect(comparacionVentas(0, 8000, esHoy: true)!.texto, '▼ 100 % vs. ayer');
  });
}
