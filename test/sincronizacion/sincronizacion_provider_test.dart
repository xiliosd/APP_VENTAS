import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/sincronizacion/sincronizador.dart';
import 'package:app_ventas/sincronizacion/supabase_nube_tienda.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/nube_tienda_falsa.dart';
import '../support/respaldo_prueba.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NubeTiendaFalsa nube;

  const retardo = Duration(milliseconds: 40);
  const intervalo = Duration(milliseconds: 300);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    nube = NubeTiendaFalsa();
  });
  tearDown(() => db.close());

  Future<ProviderContainer> contenedor({NubeRespaldoFalsa? respaldo}) async {
    SharedPreferences.setMockInitialValues({
      if (respaldo != null) claveRespaldoHabilitado: true,
    });
    final preferencias = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferenciasProvider.overrideWithValue(preferencias),
        nubeTiendaProvider.overrideWithValue(nube),
        nubeRespaldoProvider.overrideWithValue(respaldo),
        copiadorProvider.overrideWithValue(
          () async => File('copia_de_prueba.sqlite'),
        ),
        retardoSincronizacionProvider.overrideWithValue(retardo),
        intervaloSincronizacionProvider.overrideWithValue(intervalo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> esperar(Duration duracion) =>
      Future<void>.delayed(duracion + const Duration(milliseconds: 20));

  Future<void> compartir() =>
      Sincronizador(db, nube).convertirEnCompartida('T');

  test('una tienda no compartida no sincroniza', () async {
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});

    await esperar(intervalo);

    expect(nube.ciclos, 0);
    expect(
      container.read(sincronizacionProvider).fase,
      FaseSincronizacion.noCompartida,
    );
  });

  test('al abrir la app sincroniza', () async {
    await compartir();
    nube.ciclos = 0;
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});

    await esperar(retardo);

    expect(nube.ciclos, 1);
    expect(
      container.read(sincronizacionProvider).fase,
      FaseSincronizacion.alDia,
    );
    expect(
      container.read(sincronizacionProvider).ultimaSincronizacion,
      isNotNull,
    );
  });

  test('un cambio local sincroniza después de la espera', () async {
    await compartir();
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});
    await esperar(retardo);
    nube.ciclos = 0;

    await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Juan'));
    expect(nube.ciclos, 0);
    await esperar(retardo);

    expect(nube.ciclos, 1);
    expect(nube.filas.where((f) => f.tabla == 'clientes'), hasLength(1));
    expect(container.read(sincronizacionProvider).pendientes, 0);
  });

  test('sin cambios no se encadenan ciclos antes del intervalo', () async {
    await compartir();
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});
    await esperar(retardo);
    nube.ciclos = 0;

    await esperar(retardo * 3);

    expect(nube.ciclos, 0);
  });

  test('cada intervalo vuelve a sincronizar', () async {
    await compartir();
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});
    await esperar(retardo);
    nube.ciclos = 0;

    await esperar(intervalo);

    expect(nube.ciclos, greaterThanOrEqualTo(1));
  });

  test(
    'sin conexión queda en sinConexion y reintenta en el siguiente ciclo',
    () async {
      await compartir();
      nube.sinConexion = true;
      final container = await contenedor();
      container.listen(sincronizacionProvider, (_, _) {});
      await esperar(retardo);
      expect(
        container.read(sincronizacionProvider).fase,
        FaseSincronizacion.sinConexion,
      );

      nube.sinConexion = false;
      await esperar(intervalo);

      expect(
        container.read(sincronizacionProvider).fase,
        FaseSincronizacion.alDia,
      );
    },
  );

  test(
    'un error inesperado se muestra como error, no como sin conexión',
    () async {
      await compartir();
      nube.errorInesperado = true;
      final container = await contenedor();
      container.listen(sincronizacionProvider, (_, _) {});

      await esperar(retardo);

      expect(
        container.read(sincronizacionProvider).fase,
        FaseSincronizacion.error,
      );
    },
  );

  test('sesión vencida pasa a requiereReconexion', () async {
    await compartir();
    nube.sesionVencida = true;
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});

    await esperar(retardo);

    expect(
      container.read(sincronizacionProvider).fase,
      FaseSincronizacion.requiereReconexion,
    );
  });

  test('versión vieja pasa a actualizarApp', () async {
    await compartir();
    nube.versionMinima = versionProtocoloSincronizacion + 1;
    final container = await contenedor();
    container.listen(sincronizacionProvider, (_, _) {});

    await esperar(retardo);

    expect(
      container.read(sincronizacionProvider).fase,
      FaseSincronizacion.actualizarApp,
    );
  });

  test('compartir la tienda la sube y queda al día', () async {
    await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final container = await contenedor();

    await container.read(sincronizacionProvider.notifier).compartirTienda();

    expect(
      container.read(sincronizacionProvider).fase,
      FaseSincronizacion.alDia,
    );
    expect(nube.filas.where((f) => f.tabla == 'clientes'), hasLength(1));
  });

  test(
    'al descargar la tienda la app ve que ya hay usuarios (pasa al PIN)',
    () async {
      final otro = AppDatabase(NativeDatabase.memory());
      addTearDown(otro.close);
      await otro
          .into(otro.usuarios)
          .insert(
            UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'h'),
          );
      await Sincronizador(otro, nube).convertirEnCompartida('T');
      final container = await contenedor();
      expect(await container.read(haySesionUsuariosProvider.future), isFalse);

      await container
          .read(sincronizacionProvider.notifier)
          .descargarTienda('tienda-1');

      expect(await container.read(haySesionUsuariosProvider.future), isTrue);
    },
  );

  test('con tienda compartida el respaldo por archivo no sube nada', () async {
    await compartir();
    final respaldo = NubeRespaldoFalsa(conSesion: true);
    final container = await contenedor(respaldo: respaldo);

    final subio = await container
        .read(respaldoProvider.notifier)
        .respaldarAhora();

    expect(subio, isFalse);
    expect(respaldo.subidas, 0);
  });
}
