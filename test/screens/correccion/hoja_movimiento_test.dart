import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/lineas_venta_providers.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/correccion/hoja_movimiento.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/teclado_monto.dart';
import 'package:app_ventas/util/fecha_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Sesión de un usuario nuevo con [rol]; devuelve el container y el usuario.
  Future<(ProviderContainer, Usuario)> sesion({String rol = 'admin'}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    return (container, container.read(sesionProvider).usuarioActivo!);
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer container,
      MovimientoEditable movimiento) async {
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => abrirHojaMovimiento(context, movimiento),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<Venta> venta(int id) =>
      (db.select(db.ventas)..where((v) => v.id.equals(id))).getSingle();

  MovimientoEditable deVenta(int id, Usuario dueno, {DateTime? fecha}) =>
      MovimientoEditable(
        tipo: TipoMovimiento.venta,
        id: id,
        monto: 5000,
        fecha: fecha ?? DateTime.now(),
        usuarioId: dueno.id,
      );

  bool guardarHabilitado(WidgetTester tester) =>
      tester
          .widget<BotonPrincipal>(
              find.byKey(const Key('boton_guardar_correccion')))
          .onPressed !=
      null;

  testWidgets('el administrador ve el detalle con Corregir y Anular',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);

    await abrir(tester, container, deVenta(id, ana));

    expect(find.text('Contado · Efectivo'), findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsOneWidget);
    expect(find.byKey(const Key('boton_anular')), findsOneWidget);
  });

  testWidgets('el vendedor no ve botones en una venta suya de ayer',
      (tester) async {
    final (container, beto) = await sesion(rol: 'vendedor');
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final id = await VentaRepository(db).registrarVenta(
        monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

    await abrir(tester, container, deVenta(id, beto, fecha: ayer));

    expect(find.text('Contado · Efectivo'), findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsNothing);
    expect(find.byKey(const Key('boton_anular')), findsNothing);
  });

  testWidgets('corregir el monto guarda, cierra la hoja y avisa',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();
    expect(guardarHabilitado(tester), isTrue);
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect((await venta(id)).monto, 500);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Venta corregida'), findsOneWidget);
  });

  testWidgets('un doble toque en Guardar guarda una sola corrección',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await db.select(db.correcciones).get(), hasLength(1));
  });

  testWidgets(
      'pasar a fiada exige cliente y usa el existente aunque cambien las '
      'mayúsculas', (tester) async {
    final (container, ana) = await sesion();
    final rosa =
        await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Rosa'));
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fiado'));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.enterText(find.byKey(const Key('campo_cliente')), 'rosa');
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isTrue);
    // Las sugerencias de clientes alargan la hoja: se desplaza hasta Guardar.
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final v = await venta(id);
    expect(v.esFiado, isTrue);
    expect(v.clienteId, rosa);
    expect(await db.select(db.clientes).get(), hasLength(1));
  });

  testWidgets('anular pide confirmación; cancelar no cambia nada',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    expect(find.text(r'¿Anular esta venta de $5.000?'), findsOneWidget);
    expect(find.text('Ya no contará en los totales.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await venta(id)).anulado, isFalse);
    expect(find.byKey(const Key('boton_anular')), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular')));
    await tester.pumpAndSettle();

    expect((await venta(id)).anulado, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Venta anulada'), findsOneWidget);
  });

  testWidgets('un abono se corrige cambiando el medio de pago',
      (tester) async {
    final (container, ana) = await sesion();
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final fecha = DateTime.now();
    final id = await FiadoRepository(db).registrarPago(
        clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: fecha);
    await abrir(
        tester,
        container,
        MovimientoEditable(
            tipo: TipoMovimiento.abono,
            id: id,
            monto: 2000,
            fecha: fecha,
            usuarioId: ana.id,
            clienteId: pedro));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final pago = await (db.select(db.pagosFiado)..where((p) => p.id.equals(id)))
        .getSingle();
    expect(pago.medioPago, MedioPago.transferencia);
    expect(find.text('Abono corregido'), findsOneWidget);
  });

  testWidgets('un gasto se corrige cambiando la descripción', (tester) async {
    final (container, ana) = await sesion();
    final fecha = DateTime.now();
    final id = await GastoRepository(db).registrarGasto(
        monto: 1500, descripcion: 'Hielo', usuarioId: ana.id, fecha: fecha);
    await abrir(
        tester,
        container,
        MovimientoEditable(
            tipo: TipoMovimiento.gasto,
            id: id,
            monto: 1500,
            fecha: fecha,
            usuarioId: ana.id,
            descripcion: 'Hielo'));

    expect(find.text('Hielo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('editar_descripcion')), 'Hielo y bolsas');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final gasto =
        await (db.select(db.gastos)..where((g) => g.id.equals(id))).getSingle();
    expect(gasto.descripcion, 'Hielo y bolsas');
    expect(find.text('Gasto corregido'), findsOneWidget);
  });

  testWidgets('un movimiento anulado dice quién lo anuló y no deja corregir',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await CorreccionRepository(db).anularVenta(id, por: ana);
    final correccion = await db.select(db.correcciones).getSingle();

    await abrir(
        tester,
        container,
        MovimientoEditable(
          tipo: TipoMovimiento.venta,
          id: id,
          monto: 5000,
          fecha: DateTime.now(),
          usuarioId: ana.id,
          anulado: true,
          ultimaCorreccion: correccion,
        ));

    expect(find.text('Anulada por Ana · ${formatoHora(correccion.fecha)}'),
        findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsNothing);
    expect(find.byKey(const Key('boton_anular')), findsNothing);
  });

  /// Venta de Ana con 2 Arepa ($3.500) y 1 Cocacola ($1.200) = $8.200.
  Future<(int, List<LineaVenta>)> ventaConLineas(Usuario ana) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Cocacola', precio: 1200));
    final repo = VentaRepository(db);
    final id = await repo.registrarVenta(
      monto: 8200,
      esFiado: false,
      usuarioId: ana.id,
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: coca,
            descripcion: 'Cocacola',
            precioUnitario: 1200,
            cantidad: 1),
      ],
    );
    return (id, await repo.lineasDeVenta(id));
  }

  MovimientoEditable ventaDe8200(int id, Usuario ana) => MovimientoEditable(
        tipo: TipoMovimiento.venta,
        id: id,
        monto: 8200,
        fecha: DateTime.now(),
        usuarioId: ana.id,
      );

  testWidgets('el detalle muestra los productos de la venta', (tester) async {
    final (container, ana) = await sesion();
    final (id, _) = await ventaConLineas(ana);

    await abrir(tester, container, ventaDe8200(id, ana));

    expect(find.text(r'2× Arepa · $7.000'), findsOneWidget);
    expect(find.text(r'1× Cocacola · $1.200'), findsOneWidget);
  });

  testWidgets('corregir cantidades recalcula el total y lo guarda',
      (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    expect(find.byType(TecladoMonto), findsNothing);
    await tester.tap(find.byKey(Key('sumar_linea_${lineas[0].id}')));
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[1].id}')));
    await tester.pump();

    expect(
        find.descendant(
            of: find.byKey(const Key('total_correccion')),
            matching: find.text(r'$10.500')),
        findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect((await venta(id)).monto, 10500);
    final quedan = await VentaRepository(db).lineasDeVenta(id);
    expect(quedan.single.cantidad, 3);
    expect(find.text('Venta corregida'), findsOneWidget);
  });

  testWidgets('quitar todas las líneas no deja guardar', (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[0].id}')));
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[1].id}')));
    await tester.pump();

    expect(find.text('Para quitar todo, anula la venta'), findsOneWidget);
    expect(guardarHabilitado(tester), isFalse);
  });

  testWidgets('restar hasta 0 deja la línea tachada y se puede recuperar',
      (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    final coca = lineas[1].id;
    await tester.tap(find.byKey(Key('restar_linea_$coca')));
    await tester.pump();

    expect(tester.widget<Text>(find.byKey(Key('cantidad_linea_$coca'))).data,
        '0');
    expect(
        tester
            .widget<Text>(find.byKey(Key('nombre_linea_$coca')))
            .style
            ?.decoration,
        TextDecoration.lineThrough);
    expect(
        tester
            .widget<IconButton>(find.byKey(Key('restar_linea_$coca')))
            .onPressed,
        isNull);
    expect(find.byKey(Key('quitar_linea_$coca')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('total_correccion')),
            matching: find.text(r'$7.000')),
        findsOneWidget);

    await tester.tap(find.byKey(Key('sumar_linea_$coca')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(Key('cantidad_linea_$coca'))).data,
        '1');
    expect(guardarHabilitado(tester), isFalse);
  });

  testWidgets('sin cargar las líneas no se ofrece Corregir', (tester) async {
    final container = await containerConSesion(db, overrides: [
      lineasVentaProvider
          .overrideWith((ref, id) => Completer<List<LineaVenta>>().future),
    ]);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final (id, _) = await ventaConLineas(ana);

    await abrir(tester, container, ventaDe8200(id, ana));

    expect(find.byKey(const Key('boton_corregir')), findsNothing);
    expect(find.byKey(const Key('boton_anular')), findsOneWidget);
  });

  testWidgets('un abono mayor que la deuda muestra el motivo', (tester) async {
    final (container, ana) = await sesion();
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final fecha = DateTime.now();
    await VentaRepository(db).registrarVenta(
        monto: 5000,
        esFiado: true,
        clienteId: pedro,
        usuarioId: ana.id,
        fecha: fecha);
    final id = await FiadoRepository(db).registrarPago(
        clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: fecha);
    await abrir(
        tester,
        container,
        MovimientoEditable(
            tipo: TipoMovimiento.abono,
            id: id,
            monto: 2000,
            fecha: fecha,
            usuarioId: ana.id,
            clienteId: pedro));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_0'))); // 20.000
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('sin permiso al guardar lo dice claramente', (tester) async {
    final container = await containerConSesion(db, overrides: [
      correccionRepositoryProvider.overrideWithValue(_RepoSinPermiso(db)),
    ]);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect(find.text('Ya no puedes corregir este movimiento'), findsOneWidget);
  });
}

/// Siempre niega el permiso al corregir.
class _RepoSinPermiso extends CorreccionRepository {
  _RepoSinPermiso(super.db);

  @override
  Future<void> corregirVenta(
    int id, {
    required int monto,
    required bool esFiado,
    int? clienteId,
    MedioPago medioPago = MedioPago.efectivo,
    Map<int, int>? cantidades,
    required Usuario por,
  }) async =>
      throw const PermisoDenegado();
}
