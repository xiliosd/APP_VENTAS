import 'dart:async';

import 'package:app_ventas/servicios/dictado.dart';
import 'package:flutter_test/flutter_test.dart';

/// El reconocedor de Android sin el celular: la prueba decide qué responde y
/// qué oye.
class _ReconocedorFalso implements ReconocedorLocal {
  bool hayLocal = true;
  bool permiso = true;
  List<String>? descargados = ['es-CO'];
  Completer<List<String>?>? descargadosPendientes;
  Object? errorAlEscuchar;

  String? idioma;
  int escuchas = 0;
  int detenciones = 0;
  void Function(EventoVoz evento)? _alEvento;

  @override
  Future<bool> hayReconocimientoLocal() async => hayLocal;

  @override
  Future<bool> pedirPermiso() async => permiso;

  @override
  Future<List<String>?> idiomasDescargados() =>
      descargadosPendientes?.future ?? Future.value(descargados);

  @override
  Future<void> escuchar({
    required String? idioma,
    required void Function(EventoVoz evento) alEvento,
  }) async {
    if (errorAlEscuchar != null) throw errorAlEscuchar!;
    escuchas++;
    this.idioma = idioma;
    _alEvento = alEvento;
  }

  @override
  Future<void> detener() async => detenciones++;

  void oir(String texto) => _alEvento!(TextoParcial(texto));
  void terminar(String texto) => _alEvento!(TextoFinal(texto));
  void fallar(int codigo) => _alEvento!(ErrorVoz(codigo));
}

void main() {
  late _ReconocedorFalso reconocedor;
  late DictadoDelCelular dictado;

  setUp(() {
    reconocedor = _ReconocedorFalso();
    dictado = DictadoDelCelular(reconocedor);
  });

  /// Idioma con el que empezó a escuchar teniendo [descargados].
  Future<String?> idiomaElegido(List<String>? descargados) async {
    reconocedor.descargados = descargados;
    expect(await dictado.preparar(), EstadoDictado.listo);
    unawaited(dictado.escuchar(alOir: (_) {}));
    await Future<void>.delayed(Duration.zero);
    return reconocedor.idioma;
  }

  group('preparar', () {
    test('listo con permiso y español descargado', () async {
      expect(await dictado.preparar(), EstadoDictado.listo);
    });

    test('sin permiso de micrófono', () async {
      reconocedor.permiso = false;
      expect(await dictado.preparar(), EstadoDictado.sinPermiso);
    });

    test(
      'sin reconocimiento local no dicta: el audio no sale del celular',
      () async {
        reconocedor.hayLocal = false;
        expect(await dictado.preparar(), EstadoDictado.sinDictadoLocal);
      },
    );

    test('sin español descargado no está disponible', () async {
      reconocedor.descargados = ['en-US'];
      expect(await dictado.preparar(), EstadoDictado.noDisponible);
    });

    test('si los idiomas no responden, no está disponible', () async {
      reconocedor.descargadosPendientes = Completer();
      final lento = DictadoDelCelular(
        reconocedor,
        esperaIdiomas: const Duration(milliseconds: 10),
      );
      expect(await lento.preparar(), EstadoDictado.noDisponible);
    });
  });

  group('idioma', () {
    test('es_CO descargado gana a los demás', () async {
      expect(await idiomaElegido(['es-ES', 'es-CO', 'es-US']), 'es-CO');
    });

    test('sin es_CO prefiere es_US a es_ES', () async {
      expect(await idiomaElegido(['es-ES', 'es-US']), 'es-US');
    });

    test('usa el único español descargado', () async {
      expect(await idiomaElegido(['en-US', 'es-ES']), 'es-ES');
    });

    test('si Android no dice cuáles hay, usa el del celular', () async {
      expect(await idiomaElegido(null), isNull);
    });
  });

  group('escuchar', () {
    test('pasa lo parcial y devuelve lo final', () async {
      await dictado.preparar();
      final parciales = <String>[];
      final resultado = dictado.escuchar(alOir: parciales.add);
      await Future<void>.delayed(Duration.zero);

      reconocedor.oir('dos coca');
      reconocedor.terminar('dos coca colas');

      expect(await resultado, 'dos coca colas');
      expect(parciales, ['dos coca', 'dos coca colas']);
    });

    test('un parcial vacío no borra lo que ya oyó', () async {
      // El reconocedor local manda "" justo antes de terminar.
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      reconocedor.oir('Coca Cola');
      reconocedor.oir('');
      reconocedor.terminar('');

      expect(await resultado, 'Coca Cola');
    });

    test('si no oyó nada devuelve null', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      reconocedor.fallar(ErrorVoz.sinCoincidencia);

      expect(await resultado, isNull);
    });

    test('un error después de oír algo devuelve lo oído', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      reconocedor.oir('un pan');
      reconocedor.fallar(ErrorVoz.silencio);

      expect(await resultado, 'un pan');
    });

    test('sin el español sin conexión avisa que no está disponible', () async {
      for (final codigo in [
        ErrorVoz.servidorDesconectado,
        ErrorVoz.idiomaNoSoportado,
        ErrorVoz.idiomaNoDisponible,
      ]) {
        await dictado.preparar();
        final resultado = dictado.escuchar(alOir: (_) {});
        await Future<void>.delayed(Duration.zero);

        reconocedor.fallar(codigo);

        await expectLater(resultado, throwsA(isA<DictadoNoDisponible>()));
      }
    });

    test('si el reconocedor falla al empezar devuelve null', () async {
      await dictado.preparar();
      reconocedor.errorAlEscuchar = StateError('ocupado');
      expect(await dictado.escuchar(alOir: (_) {}), isNull);
    });

    test('se puede dictar varias veces seguidas', () async {
      for (final texto in ['un pan', 'dos leches']) {
        await dictado.preparar();
        final resultado = dictado.escuchar(alOir: (_) {});
        await Future<void>.delayed(Duration.zero);
        reconocedor.terminar(texto);
        expect(await resultado, texto);
      }
      expect(reconocedor.escuchas, 2);
    });
  });

  group('detener', () {
    test('detener apaga el reconocedor y devuelve lo oído', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);
      reconocedor.oir('un pan');

      await dictado.detener();

      expect(reconocedor.detenciones, 1);
      expect(await resultado, 'un pan');
    });

    test('lo que llega después de detener se ignora', () async {
      await dictado.preparar();
      final oidos = <String>[];
      final resultado = dictado.escuchar(alOir: oidos.add);
      await Future<void>.delayed(Duration.zero);
      reconocedor.oir('un pan');

      await dictado.detener();
      reconocedor.terminar('un pan y leche');

      expect(await resultado, 'un pan');
      expect(oidos, ['un pan']);
    });

    test('al cumplir el tiempo deja de escuchar y espera lo final', () async {
      final corto = DictadoDelCelular(
        reconocedor,
        duracionEscucha: const Duration(milliseconds: 20),
      );
      await corto.preparar();
      final resultado = corto.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);
      reconocedor.oir('tres panes');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reconocedor.detenciones, 1);

      reconocedor.terminar('tres panes y leche');
      expect(await resultado, 'tres panes y leche');
    });

    test('si nunca llega lo final usa lo último que oyó', () async {
      final corto = DictadoDelCelular(
        reconocedor,
        esperaMaxima: const Duration(milliseconds: 20),
      );
      await corto.preparar();
      final resultado = corto.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);
      reconocedor.oir('un pan');

      expect(await resultado, 'un pan');
    });
  });
}
