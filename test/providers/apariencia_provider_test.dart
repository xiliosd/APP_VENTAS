import 'package:app_ventas/providers/apariencia_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter/material.dart';
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
  test('sin elección guardada sigue al sistema', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    expect(c.read(aparienciaProvider), ThemeMode.system);
  });

  test('elegir oscuro lo guarda y lo conserva al reabrir', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    await c.read(aparienciaProvider.notifier).elegir(ThemeMode.dark);
    expect(c.read(aparienciaProvider), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('apariencia'), 'oscuro');

    final otra = ProviderContainer(
        overrides: [preferenciasProvider.overrideWithValue(prefs)]);
    addTearDown(otra.dispose);
    expect(otra.read(aparienciaProvider), ThemeMode.dark);
  });

  test('un valor ilegible se toma como Automático', () async {
    final c = await contenedor({'apariencia': 'violeta'});
    addTearDown(c.dispose);
    expect(c.read(aparienciaProvider), ThemeMode.system);
  });
}
