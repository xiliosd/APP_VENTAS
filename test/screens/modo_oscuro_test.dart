import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:app_ventas/screens/reportes/reportes_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });
  tearDown(() => db.close());

  /// Monta [pantalla] en modo oscuro en una vista de 800×1600 dp.
  Future<void> montarOscuro(WidgetTester tester, Widget pantalla,
      {double escalaLetra = 1}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final productoId = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 2000));
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 2000,
          fecha: DateTime.now(),
          productoId: Value(productoId),
          usuarioId: 1,
        ));
    await tester.pumpWidget(appDePrueba(
      container,
      tema: temaOscuro(),
      inicio: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escalaLetra)),
          child: pantalla,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  void verificarOscuro(WidgetTester tester, Finder pantalla) {
    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(pantalla)).brightness, Brightness.dark);
  }

  testWidgets('Inicio y cada pestaña se dibujan en oscuro', (tester) async {
    await montarOscuro(tester, const HomeScreen());
    verificarOscuro(tester, find.byType(HomeScreen));
    expect(find.byKey(const Key('mini_grafica')), findsOneWidget);
    expect(find.byKey(const Key('barra_acciones_inicio')), findsOneWidget);

    for (final pestana in ['Fiado', 'Inventario', 'Historial', 'Ajustes']) {
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text(pestana)));
      await tester.pumpAndSettle();
      verificarOscuro(tester, find.byType(HomeScreen));
    }
  });

  testWidgets('Nueva venta se dibuja en oscuro', (tester) async {
    await montarOscuro(tester, const RegistrarVentaScreen());
    verificarOscuro(tester, find.byType(RegistrarVentaScreen));

    // La hoja "¿Cómo paga?" con el selector de cliente abierto.
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_fiado')));
    await tester.pumpAndSettle();
    verificarOscuro(tester, find.byKey(const Key('hoja_como_paga')));
  });

  testWidgets('"¿Quién eres?" se dibuja en oscuro', (tester) async {
    await montarOscuro(tester, const SeleccionarUsuarioScreen());
    verificarOscuro(tester, find.byType(SeleccionarUsuarioScreen));
  });

  testWidgets('el PIN se dibuja en oscuro', (tester) async {
    final usuario = (await db.into(db.usuarios).insertReturning(
        UsuariosCompanion.insert(nombre: 'Luis', rol: 'vendedor', pinHash: 'x')));
    await montarOscuro(tester, IngresarPinScreen(usuario: usuario));
    verificarOscuro(tester, find.byType(IngresarPinScreen));
  });

  testWidgets('Reportes se dibuja en oscuro', (tester) async {
    await montarOscuro(tester, const ReportesScreen());
    verificarOscuro(tester, find.byType(ReportesScreen));
  });

  testWidgets('Inicio en oscuro con letra grande no desborda', (tester) async {
    await montarOscuro(tester, const HomeScreen(), escalaLetra: 1.6);
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
    verificarOscuro(tester, find.byType(HomeScreen));
  });
}
