import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún color suelto fuera de colores_app.dart', () {
    final patron = RegExp(r'Color\(0x|Colors\.(white|black)');
    final fuera = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (ruta.endsWith('lib/ui/colores_app.dart')) continue;
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (patron.hasMatch(lineas[i])) fuera.add('$ruta:${i + 1}');
      }
    }
    expect(fuera, isEmpty, reason: 'Usar ColoresApp.of(context)');
  });
}
