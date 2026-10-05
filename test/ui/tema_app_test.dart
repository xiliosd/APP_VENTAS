import 'dart:io';
import 'dart:math' as math;

import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('los pares de texto y fondo cumplen contraste 4.5:1', () {
    const pares = <String, (Color, Color)>{
      'texto/fondo': (ColoresApp.texto, ColoresApp.fondo),
      'secundario/fondo': (ColoresApp.textoSecundario, ColoresApp.fondo),
      'secundario/superficie': (ColoresApp.textoSecundario, ColoresApp.superficie),
      'primario/superficie': (ColoresApp.primario, ColoresApp.superficie),
      'blanco/primario': (Colors.white, ColoresApp.primario),
      'entra/superficie': (ColoresApp.entra, ColoresApp.superficie),
      'blanco/entra': (Colors.white, ColoresApp.entra),
      'sale/superficie': (ColoresApp.sale, ColoresApp.superficie),
      'blanco/sale': (Colors.white, ColoresApp.sale),
      'fiado/superficie': (ColoresApp.fiado, ColoresApp.superficie),
      'fiado/fiadoSuave': (ColoresApp.fiado, ColoresApp.fiadoSuave),
    };
    pares.forEach((nombre, par) {
      expect(contraste(par.$1, par.$2), greaterThanOrEqualTo(4.5),
          reason: nombre);
    });
  });

  test('el tema usa el color primario, el fondo y la fuente Inter', () {
    final tema = temaApp();
    expect(tema.colorScheme.primary, ColoresApp.primario);
    expect(tema.scaffoldBackgroundColor, ColoresApp.fondo);
    expect(tema.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('la fuente Inter está empaquetada y declarada', () {
    for (final archivo in [
      'Inter-Regular.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'Inter-ExtraBold.ttf',
    ]) {
      expect(File('assets/fonts/$archivo').existsSync(), isTrue,
          reason: archivo);
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('family: Inter'));
  });
}
