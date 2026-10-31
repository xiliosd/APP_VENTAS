import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/fiado_providers.dart';
import 'package:app_ventas/util/extracto_fiado.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/fiado/extracto_fiado_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FiadoRepository fiado;
  late VentaRepository ventas;
  late int usuarioId;
  late int clienteId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fiado = FiadoRepository(db);
    ventas = VentaRepository(db);
    usuarioId = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<void> fiar(
    int monto,
    DateTime fecha, {
    List<LineaNueva> lineas = const [],
  }) async {
    await ventas.registrarVenta(
      monto: monto,
      esFiado: true,
      clienteId: clienteId,
      usuarioId: usuarioId,
      fecha: fecha,
      lineas: lineas,
    );
  }

  Future<void> abonar(int monto, DateTime fecha) => fiado.registrarPago(
    clienteId: clienteId,
    monto: monto,
    usuarioId: usuarioId,
    fecha: fecha,
  );

  Future<void> montar(
    WidgetTester tester, {
    double escala = 1.0,
    Size? tamano,
  }) async {
    if (tamano != null) {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    final cliente = await (db.select(
      db.clientes,
    )..where((c) => c.id.equals(clienteId))).getSingle();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: ExtractoFiadoScreen(cliente: cliente),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> sembrar() async {
    await fiar(
      7000,
      DateTime(2026, 10, 1, 9, 0),
      lineas: const [
        LineaNueva(descripcion: 'Arepa', precioUnitario: 3500, cantidad: 2),
      ],
    );
    await fiar(2000, DateTime(2026, 10, 2, 9, 0));
    await abonar(1000, DateTime(2026, 10, 3, 9, 0));
    await fiar(500, DateTime(2026, 10, 4, 9, 0));
  }

  testWidgets('muestra consolidado del último abono y saldo actual', (
    tester,
  ) async {
    await sembrar();
    await montar(tester);

    expect(find.text('Don Pedro'), findsOneWidget);
    expect(find.textContaining('Extracto al '), findsOneWidget);
    expect(
      find.text(r'Saldo al 03/10/2026 09:00 después de abonar $1.000: $8.000'),
      findsOneWidget,
    );
    expect(find.text('04/10/2026 09:00'), findsOneWidget);
    expect(find.text(r'Saldo actual $8.500'), findsOneWidget);
  });

  testWidgets('Ver detalle anterior despliega los fiados y abonos previos', (
    tester,
  ) async {
    await sembrar();
    await abonar(500, DateTime(2026, 10, 5, 9, 0));
    await montar(tester);

    expect(find.text('Arepa · 2 × \$3.500 = \$7.000'), findsNothing);
    await tester.tap(find.byKey(const Key('ver_detalle_anterior')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa · 2 × \$3.500 = \$7.000'), findsOneWidget);
    expect(
      find.text(r'Saldo al 03/10/2026 09:00 después de abonar $1.000: $8.000'),
      findsOneWidget,
    );
    expect(
      find.text(r'Saldo al 05/10/2026 09:00 después de abonar $500: $8.000'),
      findsOneWidget,
    );
  });

  testWidgets('venta sin detalle y saldo a favor', (tester) async {
    await fiar(2000, DateTime(2026, 10, 1, 9, 0));
    await abonar(2500, DateTime(2026, 10, 2, 9, 0));
    await montar(tester);

    expect(find.text('Saldo a favor \$500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ver_detalle_anterior')));
    await tester.pumpAndSettle();
    expect(find.text('Venta sin detalle'), findsOneWidget);
  });

  testWidgets('al día cuando el saldo es cero', (tester) async {
    await fiar(2000, DateTime(2026, 10, 1, 9, 0));
    await abonar(2000, DateTime(2026, 10, 2, 9, 0));
    await montar(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('saldo_actual_extracto')),
        matching: find.text('Al día'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'sin botones de corrección: tocar un fiado no abre la hoja de movimiento',
    (tester) async {
      await sembrar();
      await montar(tester);

      await tester.tap(find.text('04/10/2026 09:00'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets('sin desborde a 2,0× en 360 dp', (tester) async {
    await sembrar();
    await abonar(500, DateTime(2026, 10, 5, 9, 0));
    await montar(tester, escala: 2.0, tamano: const Size(360, 800));
    final detalle = find.byKey(const Key('ver_detalle_anterior'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(detalle);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('si falla la carga muestra el aviso amable', (tester) async {
    final cliente = await (db.select(
      db.clientes,
    )..where((c) => c.id.equals(clienteId))).getSingle();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        extractoClienteProvider.overrideWith(
          (ref, id) => Future<ExtractoFiado>.error(StateError('base dañada')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          home: ExtractoFiadoScreen(cliente: cliente),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Cierra la app y vuelve a abrirla'), findsOneWidget);
    expect(find.textContaining('base dañada'), findsNothing);
  });
}
