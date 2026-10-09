import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ancho, alto y tipo de color (6 = RGBA) de un PNG, leídos de su cabecera.
({int ancho, int alto, int tipoColor}) cabeceraPng(String ruta) {
  final bytes = File(ruta).readAsBytesSync();
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: ruta);
  final datos = ByteData.sublistView(bytes);
  return (
    ancho: datos.getUint32(16),
    alto: datos.getUint32(20),
    tipoColor: bytes[25],
  );
}

void main() {
  test('el isotipo es cuadrado, de 512 px y con transparencia', () {
    final cabecera = cabeceraPng('assets/marca/isotipo.png');
    expect(cabecera.ancho, 512);
    expect(cabecera.alto, 512);
    expect(cabecera.tipoColor, 6);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/marca/'));
  });

  test('hay íconos del lanzador clásicos y adaptativos en cada densidad', () {
    const lados = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    lados.forEach((densidad, lado) {
      final carpeta = 'android/app/src/main/res/mipmap-$densidad';
      expect(cabeceraPng('$carpeta/ic_launcher.png').ancho, lado,
          reason: densidad);
      expect(cabeceraPng('$carpeta/ic_launcher_foreground.png').ancho,
          lado * 108 ~/ 48,
          reason: densidad);
      expect(cabeceraPng('$carpeta/ic_launcher_monochrome.png').ancho,
          lado * 108 ~/ 48,
          reason: densidad);
    });
    final adaptativo = File(
            'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(adaptativo, contains('@mipmap/ic_launcher_foreground'));
    expect(adaptativo, contains('@color/ic_launcher_background'));
    expect(adaptativo, contains('@mipmap/ic_launcher_monochrome'));
  });

  test('Android muestra el nombre VeciTienda', () {
    expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:label="VeciTienda"'));
  });

  testWidgets('la app se llama VeciTienda', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferenciasProvider.overrideWithValue(prefs),
      ],
      child: const AppVentas(),
    ));

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'VeciTienda');
  });
}
