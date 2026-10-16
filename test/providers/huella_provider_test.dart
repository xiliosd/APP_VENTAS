import 'package:app_ventas/providers/huella_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> crear(Map<String, Object> valores) async {
    SharedPreferences.setMockInitialValues(valores);
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  }

  UsuariosConHuella notifier() =>
      container.read(usuariosConHuellaProvider.notifier);

  test('arranca con lo guardado', () async {
    await crear({
      'usuarios_con_huella': ['1', '3'],
    });
    expect(container.read(usuariosConHuellaProvider), {1, 3});
  });

  test('activar y desactivar se guardan', () async {
    await crear({});

    await notifier().activar(2);
    await notifier().activar(5);
    expect(container.read(usuariosConHuellaProvider), {2, 5});
    expect(
      prefs.getStringList('usuarios_con_huella'),
      unorderedEquals(['2', '5']),
    );

    await notifier().desactivar(2);
    expect(prefs.getStringList('usuarios_con_huella'), ['5']);
  });

  test('borrarTodas deja la lista vacía', () async {
    await crear({
      'usuarios_con_huella': ['1'],
    });
    await notifier().borrarTodas();
    expect(container.read(usuariosConHuellaProvider), isEmpty);
    expect(prefs.getStringList('usuarios_con_huella'), isEmpty);
  });

  test('conservarSolo quita los que ya no existen', () async {
    await crear({
      'usuarios_con_huella': ['1', '2'],
    });
    await notifier().conservarSolo([1, 7]);
    expect(container.read(usuariosConHuellaProvider), {1});
    expect(prefs.getStringList('usuarios_con_huella'), ['1']);
  });
}
