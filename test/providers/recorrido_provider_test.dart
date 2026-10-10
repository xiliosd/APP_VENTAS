import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> contenedor(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)]);
}

void main() {
  test('sin valor guardado no hay recorrido', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.ninguno);
    expect(c.read(recorridoProvider).enCurso, isFalse);
  });

  test('iniciar, avanzar y saltar se guardan', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    final n = c.read(recorridoProvider.notifier);
    await n.iniciar();
    expect(c.read(recorridoProvider), PasoRecorrido.productos);
    expect(c.read(recorridoProvider).enCurso, isTrue);
    await n.irA(PasoRecorrido.venta);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recorrido_paso'), 'venta');
    await n.saltar();
    expect(c.read(recorridoProvider), PasoRecorrido.hecho);
    expect(prefs.getString('recorrido_paso'), 'hecho');
  });

  test('se retoma al reabrir', () async {
    final c = await contenedor({'recorrido_paso': 'inicio'});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.inicio);
  });

  test('un valor ilegible se toma como ninguno', () async {
    final c = await contenedor({'recorrido_paso': 'marte'});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.ninguno);
  });
}
