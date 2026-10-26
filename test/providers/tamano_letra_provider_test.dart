import 'package:app_ventas/providers/tamano_letra_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> contenedor(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [preferenciasProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('arranca en normal sin valor guardado o con uno desconocido', () async {
    final vacio = await contenedor({});
    addTearDown(vacio.dispose);
    expect(vacio.read(tamanoLetraProvider), TamanoLetra.normal);

    final raro = await contenedor({'tamano_letra': 'gigante'});
    addTearDown(raro.dispose);
    expect(raro.read(tamanoLetraProvider), TamanoLetra.normal);
  });

  test('elegir guarda y recuerda el tamaño', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    await c.read(tamanoLetraProvider.notifier).elegir(TamanoLetra.muyGrande);
    expect(c.read(tamanoLetraProvider), TamanoLetra.muyGrande);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tamano_letra'), 'muy_grande');

    final otra = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(otra.dispose);
    expect(otra.read(tamanoLetraProvider), TamanoLetra.muyGrande);
  });

  test('los factores son 1,0 / 1,3 / 1,6', () {
    expect(TamanoLetra.normal.factor, 1.0);
    expect(TamanoLetra.grande.factor, 1.3);
    expect(TamanoLetra.muyGrande.factor, 1.6);
  });

  test('escalaCombinada multiplica y topa en 2,0', () {
    expect(
      escalaCombinada(TextScaler.linear(1.0), TamanoLetra.grande).scale(10),
      closeTo(13, 0.01),
    );
    expect(
      escalaCombinada(TextScaler.linear(1.5), TamanoLetra.muyGrande).scale(10),
      closeTo(20, 0.01),
    );
    expect(
      escalaCombinada(TextScaler.linear(1.2), TamanoLetra.normal).scale(10),
      closeTo(12, 0.01),
    );
  });
}
