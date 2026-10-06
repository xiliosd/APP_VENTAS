import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/respaldo/copia_base_datos.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v1.dart';
import '../support/respaldo_prueba.dart';

void main() {
  late Directory carpeta;
  late File archivoLocal;
  late Restaurador restaurador;

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('restaurar');
    archivoLocal = File('${carpeta.path}/app_ventas.sqlite');
    restaurador = Restaurador(
      archivoBase: () async => archivoLocal,
      directorioTemporal: () async => carpeta,
    );
  });

  tearDown(() => carpeta.delete(recursive: true));

  /// Nube con un respaldo que contiene un usuario "Ana".
  Future<NubeRespaldoFalsa> nubeConRespaldo() async {
    final origen = AppDatabase(NativeDatabase.memory());
    await origen.into(origen.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final copia = await CopiaBaseDatos.crearCopia(
        origen, await carpeta.createTemp('origen'));
    await origen.close();
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copia);
    return nube;
  }

  test('restaura el respaldo sobre la base local', () async {
    final nube = await nubeConRespaldo();
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.restaurado);
    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    final usuarios = await reabierta.select(reabierta.usuarios).get();
    expect(usuarios.map((u) => u.nombre), ['Ana']);
    await reabierta.close();
  });

  test('sin respaldo en la nube no toca la base local', () async {
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado =
        await restaurador.restaurar(NubeRespaldoFalsa(conSesion: true), local);

    expect(resultado, ResultadoRestauracion.sinRespaldo);
    expect((await local.select(local.usuarios).get()).single.nombre, 'Viejo');
    await local.close();
  });

  test('un respaldo dañado no toca la base local', () async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(File('${carpeta.path}/basura.sqlite')
      ..writeAsStringSync('no es sqlite'));
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.invalido);
    expect((await local.select(local.usuarios).get()).single.nombre, 'Viejo');
    await local.close();
  });
  test('restaura un respaldo hecho con la versión 1 de la app', () async {
    final copiaV1 = File('${(await carpeta.createTemp('v1')).path}/r.sqlite');
    crearBaseV1(copiaV1.path);
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copiaV1);
    final local = AppDatabase(NativeDatabase(archivoLocal));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.restaurado);
    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    final ventas = await reabierta.select(reabierta.ventas).get();
    expect(ventas.single.monto, 5000);
    expect(ventas.single.medioPago, MedioPago.efectivo);
    await reabierta.close();
  });

  test('el respaldo restaurado conserva la imagen del QR', () async {
    final origen = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(origen)
        .guardarImagenQr(Uint8List.fromList([4, 5, 6]));
    final copia = await CopiaBaseDatos.crearCopia(
        origen, await carpeta.createTemp('origenqr'));
    await origen.close();
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copia);
    final local = AppDatabase(NativeDatabase(archivoLocal));

    await restaurador.restaurar(nube, local);

    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    expect(await ConfiguracionRepository(reabierta).imagenQr(), [4, 5, 6]);
    await reabierta.close();
  });
}
