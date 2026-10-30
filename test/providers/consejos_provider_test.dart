import 'package:app_ventas/providers/consejos_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer contenedor(SharedPreferences prefs) {
    final c = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'sin preferencias no hay consejos vistos y marcarVisto lo recuerda',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = contenedor(prefs);
      expect(c.read(consejosVistosProvider), isEmpty);

      await c
          .read(consejosVistosProvider.notifier)
          .marcarVisto(Consejo.escanearVenta);
      expect(c.read(consejosVistosProvider), {Consejo.escanearVenta});
      expect(prefs.getBool('consejo_visto_escanearVenta'), isTrue);

      final nuevo = contenedor(prefs);
      expect(nuevo.read(consejosVistosProvider), {Consejo.escanearVenta});
    },
  );
}
