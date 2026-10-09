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
  Map<String, (Color, Color)> paresDe(ColoresApp c) => {
        'texto/fondo': (c.texto, c.fondo),
        'texto/superficie': (c.texto, c.superficie),
        'secundario/fondo': (c.textoSecundario, c.fondo),
        'secundario/superficie': (c.textoSecundario, c.superficie),
        'primario/superficie': (c.primario, c.superficie),
        'primario/fondo': (c.primario, c.fondo),
        'primario/primarioSuave': (c.primario, c.primarioSuave),
        'sobrePrimario/primario': (c.sobrePrimario, c.primario),
        'sobreTarjeta/tarjeta': (c.sobreTarjetaPrincipal, c.tarjetaPrincipal),
        'entra/superficie': (c.entra, c.superficie),
        'sobreEntra/rellenoEntra': (c.sobreEntra, c.rellenoEntra),
        'sale/superficie': (c.sale, c.superficie),
        'sobreSale/sale': (c.sobreSale, c.sale),
        'fiado/superficie': (c.fiado, c.superficie),
        'fiado/fiadoSuave': (c.fiado, c.fiadoSuave),
        'texto/fiadoSuave': (c.texto, c.fiadoSuave),
        'textoAviso/fondoAviso': (c.textoAviso, c.fondoAviso),
        'accionAviso/fondoAviso': (c.accionAviso, c.fondoAviso),
      };

  for (final (nombre, c) in [
    ('claro', ColoresApp.claro),
    ('oscuro', ColoresApp.oscuro),
  ]) {
    test('modo $nombre: los pares de texto y fondo cumplen 4.5:1', () {
      paresDe(c).forEach((par, colores) {
        expect(contraste(colores.$1, colores.$2), greaterThanOrEqualTo(4.5),
            reason: '$nombre $par');
      });
    });

    test('modo $nombre: el verde de marca se distingue (≥ 3:1) sobre la '
        'superficie', () {
      expect(contraste(c.marcaVerde, c.superficie), greaterThanOrEqualTo(3));
    });
  }

  test('los avatares tienen texto blanco legible', () {
    for (final color in ColoresApp.paletaAvatar) {
      expect(contraste(ColoresApp.blancoMarca, color),
          greaterThanOrEqualTo(4.5),
          reason: '$color');
    }
  });

  test('la paleta clara es la de VeciTienda y la oscura es Azul noche', () {
    expect(ColoresApp.claro.primario, const Color(0xFF1A539B));
    expect(ColoresApp.claro.marcaVerde, const Color(0xFF16A34A));
    expect(ColoresApp.claro.fondo, const Color(0xFFF8FAFC));
    expect(ColoresApp.claro.texto, const Color(0xFF1E293B));
    expect(ColoresApp.claro.primarioSuave, const Color(0xFFDDE5F0));
    expect(ColoresApp.claro.entraSuave, const Color(0xFFBBF7D0));
    expect(ColoresApp.claro.saleSuave, const Color(0xFFFECACA));
    expect(ColoresApp.oscuro.fondo, const Color(0xFF0B1220));
    expect(ColoresApp.oscuro.superficie, const Color(0xFF131C2E));
    expect(ColoresApp.oscuro.tarjetaPrincipal, const Color(0xFF1B3A66));
  });

  test('cada tema registra su paleta, su brillo, su fondo y la fuente Inter',
      () {
    final claro = temaClaro();
    final oscuro = temaOscuro();
    expect(claro.extension<ColoresApp>(), ColoresApp.claro);
    expect(oscuro.extension<ColoresApp>(), ColoresApp.oscuro);
    expect(claro.brightness, Brightness.light);
    expect(oscuro.brightness, Brightness.dark);
    expect(claro.colorScheme.primary, ColoresApp.claro.primario);
    expect(claro.scaffoldBackgroundColor, ColoresApp.claro.fondo);
    expect(oscuro.scaffoldBackgroundColor, ColoresApp.oscuro.fondo);
    expect(oscuro.textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(claro.navigationBarTheme.indicatorColor,
        ColoresApp.claro.primarioSuave);
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

  test('los títulos usan Nunito ExtraBold con el eje de peso fijado', () {
    final estilo = estiloTitulo(tamano: 20);
    expect(estilo.fontFamily, 'Nunito');
    expect(estilo.fontWeight, FontWeight.w800);
    expect(estilo.fontVariations, const [FontVariation('wght', 800)]);
    expect(temaClaro().appBarTheme.titleTextStyle!.fontFamily, 'Nunito');
    expect(File('assets/fonts/Nunito-Variable.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('family: Nunito'));
  });

  test('los botones principales tienen radio 16', () {
    final forma = temaClaro().filledButtonTheme.style!.shape!.resolve({})!
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
