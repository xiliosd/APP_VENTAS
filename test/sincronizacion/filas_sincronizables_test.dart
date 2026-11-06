import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/sincronizacion/filas_sincronizables.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase a;
  late AppDatabase b;

  setUp(() async {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    // B ya tiene filas propias: sus ids locales no coinciden con los de A.
    for (var i = 0; i < 3; i++) {
      await b
          .into(b.usuarios)
          .insert(
            UsuariosCompanion.insert(nombre: 'Otro $i', rol: 'x', pinHash: 'x'),
          );
      await b
          .into(b.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Otro $i'));
      await b
          .into(b.productos)
          .insert(ProductosCompanion.insert(nombre: 'Otro $i', precio: 1));
    }
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  /// Copia de A a B la fila [idGlobal] de [tabla].
  Future<void> copiar(String tabla, String idGlobal) async {
    final datos = await leerFila(a, tabla, idGlobal);
    await aplicarFila(b, tabla, datos!);
  }

  Future<String> idGlobalDe(AppDatabase db, String tabla, int id) async =>
      (await db
              .customSelect(
                'SELECT id_global FROM $tabla WHERE id = ?',
                variables: [Variable.withInt(id)],
              )
              .getSingle())
          .read<String>('id_global');

  Future<int> usuarioEn(AppDatabase db) => db
      .into(db.usuarios)
      .insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'h'),
      );

  test(
    'una venta con líneas pasa de un celular a otro con sus referencias',
    () async {
      final usuario = await usuarioEn(a);
      final cliente = await a
          .into(a.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
      final producto = await a
          .into(a.productos)
          .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
      final venta = await a
          .into(a.ventas)
          .insert(
            VentasCompanion.insert(
              monto: 7000,
              fecha: DateTime(2026, 11, 3, 10),
              usuarioId: usuario,
              esFiado: const Value(true),
              clienteId: Value(cliente),
            ),
          );
      for (var i = 0; i < 2; i++) {
        await a
            .into(a.lineasVenta)
            .insert(
              LineasVentaCompanion.insert(
                ventaId: venta,
                productoId: Value(producto),
                descripcion: 'Arepa',
                precioUnitario: 3500,
                cantidad: 1,
              ),
            );
      }

      await copiar('usuarios', await idGlobalDe(a, 'usuarios', usuario));
      await copiar('clientes', await idGlobalDe(a, 'clientes', cliente));
      await copiar('productos', await idGlobalDe(a, 'productos', producto));
      final ventaGlobal = await idGlobalDe(a, 'ventas', venta);
      await copiar('ventas', ventaGlobal);
      for (final linea in await a.select(a.lineasVenta).get()) {
        await copiar('lineas_venta', linea.idGlobal);
      }

      final ventaB = await (b.select(
        b.ventas,
      )..where((v) => v.idGlobal.equals(ventaGlobal))).getSingle();
      expect(ventaB.monto, 7000);
      expect(ventaB.fecha, DateTime(2026, 11, 3, 10));
      expect(ventaB.esFiado, isTrue);
      final clienteB = await (b.select(
        b.clientes,
      )..where((c) => c.id.equals(ventaB.clienteId!))).getSingle();
      expect(clienteB.nombre, 'Don Pedro');
      final lineasB = await b.select(b.lineasVenta).get();
      expect(lineasB, hasLength(2));
      expect(lineasB.every((l) => l.ventaId == ventaB.id), isTrue);
      expect(ventaB.clienteId, isNot(cliente));
    },
  );

  test('aplicar dos veces la misma fila la actualiza sin duplicarla', () async {
    final cliente = await a
        .into(a.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final idGlobal = await idGlobalDe(a, 'clientes', cliente);
    await copiar('clientes', idGlobal);
    await (a.update(a.clientes)..where((c) => c.id.equals(cliente))).write(
      const ClientesCompanion(telefono: Value('300')),
    );
    await copiar('clientes', idGlobal);

    final copias = await (b.select(
      b.clientes,
    )..where((c) => c.idGlobal.equals(idGlobal))).get();
    expect(copias, hasLength(1));
    expect(copias.single.telefono, '300');
  });

  for (final tipo in TipoMovimiento.values) {
    test(
      'una corrección de ${tipo.name} apunta al movimiento correcto',
      () async {
        final usuario = await usuarioEn(a);
        final cliente = await a
            .into(a.clientes)
            .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
        final fecha = DateTime(2026, 11, 3);
        final (tabla, movimiento) = switch (tipo) {
          TipoMovimiento.venta => (
            'ventas',
            await a
                .into(a.ventas)
                .insert(
                  VentasCompanion.insert(
                    monto: 1000,
                    fecha: fecha,
                    usuarioId: usuario,
                  ),
                ),
          ),
          TipoMovimiento.abono => (
            'pagos_fiado',
            await a
                .into(a.pagosFiado)
                .insert(
                  PagosFiadoCompanion.insert(
                    clienteId: cliente,
                    monto: 1000,
                    fecha: fecha,
                    usuarioId: usuario,
                  ),
                ),
          ),
          TipoMovimiento.gasto => (
            'gastos',
            await a
                .into(a.gastos)
                .insert(
                  GastosCompanion.insert(
                    monto: 1000,
                    fecha: fecha,
                    usuarioId: usuario,
                  ),
                ),
          ),
        };
        final correccion = await a
            .into(a.correcciones)
            .insert(
              CorreccionesCompanion.insert(
                tipoMovimiento: tipo,
                movimientoId: movimiento,
                accion: AccionCorreccion.anulado,
                usuarioId: usuario,
                fecha: fecha,
                antes: 'antes',
              ),
            );

        await copiar('usuarios', await idGlobalDe(a, 'usuarios', usuario));
        await copiar('clientes', await idGlobalDe(a, 'clientes', cliente));
        final movimientoGlobal = await idGlobalDe(a, tabla, movimiento);
        await copiar(tabla, movimientoGlobal);
        await copiar(
          'correcciones',
          await idGlobalDe(a, 'correcciones', correccion),
        );

        final enB = await b.select(b.correcciones).getSingle();
        expect(await idGlobalDe(b, tabla, enB.movimientoId), movimientoGlobal);
      },
    );
  }

  test('una fila cuyo padre no llegó lanza FilaHuerfana', () async {
    final usuario = await usuarioEn(a);
    final venta = await a
        .into(a.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 11, 3),
            usuarioId: usuario,
          ),
        );

    expect(
      () async => copiar('ventas', await idGlobalDe(a, 'ventas', venta)),
      throwsA(isA<FilaHuerfana>()),
    );
  });

  test('un borrado quita la fila', () async {
    final cliente = await a
        .into(a.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final idGlobal = await idGlobalDe(a, 'clientes', cliente);
    await copiar('clientes', idGlobal);

    await aplicarBorrado(b, 'clientes', idGlobal);

    expect(
      await (b.select(
        b.clientes,
      )..where((c) => c.idGlobal.equals(idGlobal))).get(),
      isEmpty,
    );
  });

  test('borrar una fila que no existe no hace nada', () async {
    await aplicarBorrado(b, 'clientes', 'no-existe');
    expect(await b.select(b.clientes).get(), hasLength(3));
  });

  test('leer una fila que no existe da null', () async {
    expect(await leerFila(a, 'clientes', 'no-existe'), isNull);
  });

  test('la configuración viaja con nombre e imagen del QR', () async {
    await a
        .into(a.configuracionTienda)
        .insert(
          ConfiguracionTiendaCompanion.insert(
            id: const Value(1),
            nombreTienda: const Value('La Esquina'),
            imagenQr: Value(Uint8List.fromList([1, 2, 3])),
          ),
        );

    await copiar('configuracion_tienda', idGlobalConfiguracion);

    final enB = await b.select(b.configuracionTienda).getSingle();
    expect(enB.nombreTienda, 'La Esquina');
    expect(enB.imagenQr, [1, 2, 3]);
  });

  test(
    'las existencias son iguales en dos celulares con ids locales distintos',
    () async {
      final usuario = await usuarioEn(a);
      final producto = await a
          .into(a.productos)
          .insert(
            ProductosCompanion.insert(
              nombre: 'Arepa',
              precio: 3500,
              controlaExistencias: const Value(true),
            ),
          );
      final fecha = DateTime(2026, 11, 3, 9);
      final conteos = <String>[];
      for (final cantidad in [10, 12]) {
        final id = await a
            .into(a.conteosInventario)
            .insert(
              ConteosInventarioCompanion.insert(
                productoId: producto,
                cantidad: cantidad,
                tipo: TipoConteo.ajuste,
                usuarioId: usuario,
                fecha: fecha,
              ),
            );
        conteos.add(await idGlobalDe(a, 'conteos_inventario', id));
      }
      await copiar('usuarios', await idGlobalDe(a, 'usuarios', usuario));
      final productoGlobal = await idGlobalDe(a, 'productos', producto);
      await copiar('productos', productoGlobal);
      // En B llegan en el orden contrario: sus ids locales quedan invertidos.
      for (final idGlobal in conteos.reversed) {
        await copiar('conteos_inventario', idGlobal);
      }
      final productoB = await (b.select(
        b.productos,
      )..where((p) => p.idGlobal.equals(productoGlobal))).getSingle();

      expect(
        await InventarioRepository(b).existencias(productoB.id),
        await InventarioRepository(a).existencias(producto),
      );
    },
  );

  group('usuarios y su PIN', () {
    Future<String> usuarioGlobalEnA() async =>
        idGlobalDe(a, 'usuarios', await usuarioEn(a));

    Future<Usuario> usuarioEnB(String idGlobal) => (b.select(
      b.usuarios,
    )..where((u) => u.idGlobal.equals(idGlobal))).getSingle();

    test('el PIN no viaja a la nube', () async {
      final datos = await leerFila(a, 'usuarios', await usuarioGlobalEnA());

      expect(datos, isNot(contains('pin_hash')));
      expect(datos!['nombre'], 'Ana');
    });

    test('un usuario nuevo de la nube queda con PIN vacío', () async {
      final idGlobal = await usuarioGlobalEnA();

      await copiar('usuarios', idGlobal);

      expect((await usuarioEnB(idGlobal)).pinHash, '');
    });

    test('un usuario que llega de la nube no pisa el PIN local', () async {
      final idGlobal = await usuarioGlobalEnA();
      await copiar('usuarios', idGlobal);
      await (b.update(b.usuarios)..where((u) => u.idGlobal.equals(idGlobal)))
          .write(const UsuariosCompanion(pinHash: Value('guardado')));
      await (a.update(a.usuarios)..where((u) => u.idGlobal.equals(idGlobal)))
          .write(const UsuariosCompanion(nombre: Value('Ana María')));

      await copiar('usuarios', idGlobal);

      final enB = await usuarioEnB(idGlobal);
      expect(enB.nombre, 'Ana María');
      expect(enB.pinHash, 'guardado');
    });

    test(
      'un PIN cambiado en otro celular borra el PIN guardado aquí',
      () async {
        final idGlobal = await usuarioGlobalEnA();
        await copiar('usuarios', idGlobal);
        await (b.update(b.usuarios)..where((u) => u.idGlobal.equals(idGlobal)))
            .write(const UsuariosCompanion(pinHash: Value('guardado')));
        await (a.update(a.usuarios)..where((u) => u.idGlobal.equals(idGlobal)))
            .write(const UsuariosCompanion(versionPin: Value(1)));

        await copiar('usuarios', idGlobal);

        final enB = await usuarioEnB(idGlobal);
        expect(enB.versionPin, 1);
        expect(enB.pinHash, '');
      },
    );
  });
}
