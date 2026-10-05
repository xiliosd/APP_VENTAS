import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });

  tearDown(() => db.close());

  Future<void> vender() => db.into(db.ventas).insert(VentasCompanion.insert(
      monto: 1000, fecha: DateTime.now(), usuarioId: ana));

  // Los containers se cierran al final de cada test (dentro de testWidgets),
  // para que no queden temporizadores pendientes.

  testWidgets('sin configuración la fase es noConfigurado', (tester) async {
    final container = containerRespaldo(db, null);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.noConfigurado);
    container.dispose();
  });

  testWidgets('sin sesión está desactivado y los cambios no suben nada',
      (tester) async {
    final nube = NubeRespaldoFalsa();
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    await vender();
    await tester.pump(const Duration(seconds: 31));

    expect(nube.subidas, 0);
    container.dispose();
  });

  testWidgets('con sesión respalda al abrir', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    final estado = container.read(respaldoProvider);
    expect(nube.subidas, 1);
    expect(estado.fase, FaseRespaldo.activo);
    expect(estado.telefono, '+573001234567');
    expect(estado.ultimoRespaldo, isNotNull);
    container.dispose();
  });

  testWidgets('varios cambios seguidos producen un solo respaldo, 30 s '
      'después del último', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();
    expect(nube.subidas, 1); // el de al abrir

    await vender();
    await tester.pump(const Duration(seconds: 20));
    await vender();
    await tester.pump(const Duration(seconds: 20));
    expect(nube.subidas, 1);

    await tester.pump(const Duration(seconds: 11));
    expect(nube.subidas, 2);
    container.dispose();
  });

  testWidgets('un error de red no cambia la fase y se reintenta en el '
      'siguiente cambio', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = Exception('sin internet');
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    expect(container.read(respaldoProvider).fase, FaseRespaldo.activo);
    expect(container.read(respaldoProvider).ultimoRespaldo, isNull);

    nube.errorAlSubir = null;
    await vender();
    await tester.pump(const Duration(seconds: 31));
    expect(nube.subidas, 1);
    container.dispose();
  });

  testWidgets('una sesión vencida pasa a requiereReconexion', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = const ErrorSesionRespaldo();
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    expect(container.read(respaldoProvider).fase,
        FaseRespaldo.requiereReconexion);
    container.dispose();
  });

  testWidgets('un cambio durante un respaldo programa otro al terminar',
      (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();
    final notifier = container.read(respaldoProvider.notifier);

    final primero = notifier.respaldarAhora();
    final segundo = await notifier.respaldarAhora(); // llega en curso
    await primero;
    expect(segundo, isFalse);
    expect(nube.subidas, 2);

    await tester.pump(const Duration(seconds: 31));
    expect(nube.subidas, 3);
    container.dispose();
  });

  testWidgets('verificar activa la sesión y devuelve el respaldo existente',
      (tester) async {
    final existente = DateTime(2026, 10, 3, 14, 32);
    final nube = NubeRespaldoFalsa(fecha: existente);
    final container = containerRespaldo(db, nube);
    final notifier = container.read(respaldoProvider.notifier);

    final fecha = await notifier.verificar('+573001234567', '123456');

    expect(fecha, existente);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.activo);
    expect(nube.haySesion, isTrue);
    container.dispose();
  });

  testWidgets('desconectar cierra la sesión sin borrar nada', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    await container.read(respaldoProvider.notifier).desconectar();

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    expect(nube.haySesion, isFalse);
    expect(nube.archivoSubido, isNotNull);
    container.dispose();
  });

  testWidgets('restaurar con éxito cierra la sesión local', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final restaurador = RestauradorFalso(ResultadoRestauracion.restaurado);
    final container = containerRespaldo(db, nube, restaurador: restaurador);
    final usuario = await (db.select(db.usuarios)).getSingle();
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);

    final resultado = await container.read(respaldoProvider.notifier).restaurar();

    expect(resultado, ResultadoRestauracion.restaurado);
    expect(restaurador.llamadas, 1);
    expect(container.read(sesionProvider).haySesion, isFalse);
    // El respaldo que arrancó durante la restauración deja programado otro
    // (30 s); en la app el notifier siempre tiene oyente y lo ejecuta.
    await tester.pump(const Duration(seconds: 31));
    container.dispose();
  });
}
