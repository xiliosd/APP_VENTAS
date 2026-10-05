import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  });

  tearDown(() => db.close());

  Future<void> vender() => db
      .into(db.ventas)
      .insert(
        VentasCompanion.insert(
          monto: 1000,
          fecha: DateTime.now(),
          usuarioId: ana,
        ),
      );

  // Los containers se cierran al final de cada test (dentro de testWidgets),
  // para que no queden temporizadores pendientes.

  testWidgets('sin configuración la fase es noConfigurado', (tester) async {
    final container = await containerRespaldo(db, null);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.noConfigurado);
    container.dispose();
  });

  testWidgets('sin sesión está desactivado y los cambios no suben nada', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    final container = await containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    await vender();
    await tester.pump(const Duration(seconds: 31));

    expect(nube.subidas, 0);
    container.dispose();
  });

  testWidgets('con sesión respalda al abrir', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    final container = await containerRespaldo(db, nube);
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
    final container = await containerRespaldo(db, nube);
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
    final container = await containerRespaldo(db, nube);
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
    final container = await containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    expect(
      container.read(respaldoProvider).fase,
      FaseRespaldo.requiereReconexion,
    );
    container.dispose();
  });

  testWidgets('un cambio durante un respaldo programa otro al terminar', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = await containerRespaldo(db, nube);
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

  testWidgets('verificar abre la sesión y devuelve el respaldo existente, '
      'sin habilitar todavía el respaldo', (tester) async {
    final existente = DateTime(2026, 10, 3, 14, 32);
    final nube = NubeRespaldoFalsa(fecha: existente);
    final container = await containerRespaldo(db, nube);
    final notifier = container.read(respaldoProvider.notifier);

    final fecha = await notifier.verificar('+573001234567', '123456');

    expect(fecha, existente);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    expect(nube.haySesion, isTrue);
    container.dispose();
  });

  testWidgets('desconectar cierra la sesión sin borrar nada', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = await containerRespaldo(db, nube);
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
    final container = await containerRespaldo(
      db,
      nube,
      restaurador: restaurador,
    );
    final usuario = await (db.select(db.usuarios)).getSingle();
    container.read(sesionProvider.notifier).state = SesionState(
      usuarioActivo: usuario,
    );

    final resultado = await container
        .read(respaldoProvider.notifier)
        .restaurar();

    expect(resultado, ResultadoRestauracion.restaurado);
    expect(restaurador.llamadas, 1);
    expect(
      container.read(preferenciasProvider).getBool(claveRespaldoHabilitado),
      isTrue,
    );
    expect(container.read(sesionProvider).haySesion, isFalse);
    // El respaldo que arrancó durante la restauración deja programado otro
    // (30 s); en la app el notifier siempre tiene oyente y lo ejecuta.
    await tester.pump(const Duration(seconds: 31));
    container.dispose();
  });

  testWidgets('una sesión sin activar (flujo abandonado) no sube nada y se '
      'cierra', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = await containerRespaldo(db, nube, habilitado: false);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();
    await vender();
    await tester.pump(const Duration(seconds: 31));

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    expect(nube.subidas, 0);
    expect(nube.haySesion, isFalse);
    container.dispose();
  });

  testWidgets('verificar no habilita: hasta activar() no se sube nada', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    final container = await containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    final notifier = container.read(respaldoProvider.notifier);

    await notifier.verificar('+573001234567', '123456');
    await vender();
    await tester.pump(const Duration(seconds: 31));
    expect(nube.subidas, 0);

    expect(await notifier.activar(), isTrue);
    expect(nube.subidas, 1);
    expect(
      container.read(preferenciasProvider).getBool(claveRespaldoHabilitado),
      isTrue,
    );
    container.dispose();
  });

  testWidgets('si falla la consulta tras verificar, se cierra la sesión', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa()
      ..errorAlConsultar = Exception('sin internet');
    final container = await containerRespaldo(db, nube);
    final notifier = container.read(respaldoProvider.notifier);

    await expectLater(
      notifier.verificar('+573001234567', '123456'),
      throwsException,
    );
    expect(nube.haySesion, isFalse);
    container.dispose();
  });

  testWidgets('habilitado pero sin sesión al abrir pide reconexión', (
    tester,
  ) async {
    final container = await containerRespaldo(
      db,
      NubeRespaldoFalsa(),
      habilitado: true,
    );
    expect(
      container.read(respaldoProvider).fase,
      FaseRespaldo.requiereReconexion,
    );
    container.dispose();
  });

  testWidgets('si la sesión se pierde con el respaldo habilitado, el '
      'siguiente respaldo pide reconexión', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = await containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    await nube.cerrarSesion(); // la sesión venció o fue revocada
    await vender();
    await tester.pump(const Duration(seconds: 31));

    expect(
      container.read(respaldoProvider).fase,
      FaseRespaldo.requiereReconexion,
    );
    container.dispose();
  });

  testWidgets('restaurar sin respaldo deja habilitado el respaldo para la '
      'tienda nueva', (tester) async {
    final nube = NubeRespaldoFalsa();
    final container = await containerRespaldo(
      db,
      nube,
      restaurador: RestauradorFalso(ResultadoRestauracion.sinRespaldo),
    );
    final notifier = container.read(respaldoProvider.notifier);
    await notifier.verificar('+573001234567', '123456');

    await notifier.restaurar();

    expect(
      container.read(preferenciasProvider).getBool(claveRespaldoHabilitado),
      isTrue,
    );
    container.dispose();
  });

  testWidgets('restaurar un respaldo inválido no habilita y cierra la sesión', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    final container = await containerRespaldo(
      db,
      nube,
      restaurador: RestauradorFalso(ResultadoRestauracion.invalido),
    );
    final notifier = container.read(respaldoProvider.notifier);
    await notifier.verificar('+573001234567', '123456');

    await notifier.restaurar();

    expect(
      container.read(preferenciasProvider).getBool(claveRespaldoHabilitado),
      isNot(isTrue),
    );
    expect(nube.haySesion, isFalse);
    container.dispose();
  });

  testWidgets('un error a mitad de la restauración reabre la base', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferencias = await SharedPreferences.getInstance();
    var aperturas = 0;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          aperturas++;
          return db;
        }),
        preferenciasProvider.overrideWithValue(preferencias),
        nubeRespaldoProvider.overrideWithValue(NubeRespaldoFalsa()),
        copiadorProvider.overrideWithValue(() async => File('x.sqlite')),
        restauradorProvider.overrideWithValue(_RestauradorQueFalla()),
      ],
    );
    container.read(databaseProvider);
    expect(aperturas, 1);

    await expectLater(
      container.read(respaldoProvider.notifier).restaurar(),
      throwsA(isA<FileSystemException>()),
    );
    container.read(databaseProvider);

    expect(aperturas, 2);
    // Deja correr el trabajo que agenda la reapertura de la base.
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}

/// Falla como si el disco estuviera lleno después de cerrar la base.
class _RestauradorQueFalla extends RestauradorFalso {
  _RestauradorQueFalla() : super(ResultadoRestauracion.restaurado);

  @override
  Future<ResultadoRestauracion> restaurar(
    NubeRespaldo nube,
    AppDatabase db,
  ) async {
    throw const FileSystemException('disco lleno');
  }
}
