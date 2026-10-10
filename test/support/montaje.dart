import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crea un usuario en [db] y devuelve un ProviderContainer con esa base y la
/// sesión de ese usuario activa. Quien llama debe hacer `container.dispose`.
/// Sin [preferencias] usa unas vacías (como un celular recién instalado).
Future<ProviderContainer> containerConSesion(
  AppDatabase db, {
  String nombre = 'Ana',
  String rol = 'admin',
  List<Override> overrides = const [],
  SharedPreferences? preferencias,
}) async {
  if (preferencias == null) {
    SharedPreferences.setMockInitialValues({});
    preferencias = await SharedPreferences.getInstance();
  }
  final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: nombre, rol: rol, pinHash: 'x'),
      );
  final usuario =
      await (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      preferenciasProvider.overrideWithValue(preferencias),
      ...overrides,
    ],
  );
  container.read(sesionProvider.notifier).state =
      SesionState(usuarioActivo: usuario);
  return container;
}

/// App de prueba con el tema real. [inicio] es la pantalla de fondo, para
/// poder empujar pantallas encima con [navegador] y ver los avisos al volver.
/// Con [tema] se prueba otro tema (por defecto el claro).
Widget appDePrueba(
  ProviderContainer container, {
  GlobalKey<NavigatorState>? navegador,
  Widget inicio = const Scaffold(body: Text('Inicio')),
  ThemeData? tema,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
        theme: tema ?? temaClaro(), navigatorKey: navegador, home: inicio),
  );
}
