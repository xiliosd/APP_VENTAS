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

  group('la pantalla de carga de Android usa el fondo del inicio', () {
    const res = 'android/app/src/main/res';
    String leer(String ruta) => File('$res/$ruta').readAsStringSync();

    test('los fondos de carga usan fondo_inicio y no el blanco', () {
      for (final ruta in [
        'drawable/launch_background.xml',
        'drawable-v21/launch_background.xml',
      ]) {
        final xml = leer(ruta);
        expect(xml, contains('@color/fondo_inicio'), reason: ruta);
        expect(xml, isNot(contains('@android:color/white')), reason: ruta);
      }
    });

    test('fondo_inicio es el fondo claro y el azul noche', () {
      expect(leer('values/colors.xml'),
          contains('<color name="fondo_inicio">#F8FAFC</color>'));
      expect(leer('values-night/colors.xml'),
          contains('<color name="fondo_inicio">#0B1220</color>'));
    });

    test('en Android 12+ solo se ve el color, sin ícono', () {
      for (final carpeta in ['values-v31', 'values-night-v31']) {
        final xml = leer('$carpeta/styles.xml');
        expect(xml,
            contains('<item name="android:windowSplashScreenBackground">'
                '@color/fondo_inicio</item>'),
            reason: carpeta);
        expect(xml,
            contains('<item name="android:windowSplashScreenAnimatedIcon">'
                '@drawable/icono_transparente</item>'),
            reason: carpeta);
      }
      expect(leer('drawable/icono_transparente.xml'),
          contains('@android:color/transparent'));
    });
  });

  group('Android está listo para entrar con huella', () {
    const res = 'android/app/src/main/res';

    test('la actividad es FlutterFragmentActivity', () {
      final actividad = File(
              'android/app/src/main/kotlin/com/appventas/app_ventas/MainActivity.kt')
          .readAsStringSync();
      expect(actividad, contains('FlutterFragmentActivity()'));
    });

    test('pide el permiso de biometría', () {
      expect(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
          contains('android.permission.USE_BIOMETRIC'));
    });

    test('los temas de arranque son AppCompat y conservan la pantalla de carga',
        () {
      const padres = {
        'values': 'Theme.AppCompat.Light.NoActionBar',
        'values-night': 'Theme.AppCompat.NoActionBar',
        'values-v31': 'Theme.AppCompat.Light.NoActionBar',
        'values-night-v31': 'Theme.AppCompat.NoActionBar',
      };
      padres.forEach((carpeta, padre) {
        final xml = File('$res/$carpeta/styles.xml').readAsStringSync();
        expect(xml, contains('<style name="LaunchTheme" parent="$padre">'),
            reason: carpeta);
        expect(xml, contains('@drawable/launch_background'), reason: carpeta);
      });
      expect(File('$res/values-v31/styles.xml').readAsStringSync(),
          contains('windowSplashScreenAnimatedIcon'));
    });
  });

  test('Android pide el micrófono y declara el reconocedor de voz', () {
    final manifiesto =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifiesto, contains('android.permission.RECORD_AUDIO'));
    expect(manifiesto, contains('android.speech.RecognitionService'));
  });

  test('MainActivity responde si hay reconocimiento de voz local', () {
    final actividad = File(
      'android/app/src/main/kotlin/com/appventas/app_ventas/MainActivity.kt',
    ).readAsStringSync();
    expect(actividad, contains('vecitienda/voz'));
    expect(actividad, contains('isOnDeviceRecognitionAvailable'));
  });
}
