import 'dart:io';
import 'dart:math' as math;

import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/ui/tipografia.dart';
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
      'texto/superficie': (ColoresApp.texto, ColoresApp.superficie),
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

  test('la paleta es la de VeciTienda', () {
    expect(ColoresApp.primario, const Color(0xFF1A539B));
    expect(ColoresApp.marcaVerde, const Color(0xFF16A34A));
    expect(ColoresApp.fondo, const Color(0xFFF8FAFC));
    expect(ColoresApp.texto, const Color(0xFF1E293B));
    expect(ColoresApp.entraSuave, const Color(0xFFBBF7D0));
    expect(ColoresApp.saleSuave, const Color(0xFFFECACA));
  });

  test('el verde de marca solo se usa en gráficos: ≥ 3:1 sobre blanco', () {
    expect(contraste(ColoresApp.marcaVerde, ColoresApp.superficie),
        greaterThanOrEqualTo(3));
  });

  test('los títulos usan Nunito ExtraBold con el eje de peso fijado', () {
    final estilo = estiloTitulo(tamano: 20);
    expect(estilo.fontFamily, 'Nunito');
    expect(estilo.fontWeight, FontWeight.w800);
    expect(estilo.fontVariations, const [FontVariation('wght', 800)]);
    expect(temaApp().appBarTheme.titleTextStyle!.fontFamily, 'Nunito');
    expect(File('assets/fonts/Nunito-Variable.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('family: Nunito'));
  });

  test('los botones principales tienen radio 16', () {
    final forma = temaApp().filledButtonTheme.style!.shape!.resolve({})!
        as RoundedRectangleBorder;
    expect(forma.borderRadius, BorderRadius.circular(16));
  });

  test('Nunito solo se usa a través de estiloTitulo', () {
    final fuera = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (ruta.endsWith('lib/ui/tipografia.dart')) continue;
      final texto = archivo.readAsStringSync();
      if (texto.contains("'Nunito'") || texto.contains('familiaTitulos')) {
        fuera.add(ruta);
      }
    }
    expect(fuera, isEmpty,
        reason: 'Sin el eje wght la fuente variable sale con peso 200');
  });
}
