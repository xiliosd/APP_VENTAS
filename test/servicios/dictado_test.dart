import 'dart:async';

import 'package:app_ventas/servicios/dictado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// `SpeechToText` sin el plugin: la prueba decide qué responde y qué oye.
class _VozFalsa extends SpeechToText {
  _VozFalsa() : super.withMethodChannel();

  bool inicia = true;
  bool permiso = true;
  List<LocaleName> idiomas = [LocaleName('es_CO', 'Español (Colombia)')];
  SpeechListenOptions? opciones;
  SpeechResultListener? oyente;
  SpeechErrorListener? alError;
  SpeechStatusListener? alEstado;
  bool detenido = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(milliseconds: 2000),
    List<SpeechConfigOption>? options,
  }) async {
    alError = onError;
    alEstado = onStatus;
    return inicia;
  }

  @override
  Future<bool> get hasPermission async => permiso;

  @override
  Future<List<LocaleName>> locales() async => idiomas;

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    oyente = onResult;
    opciones = listenOptions;
  }

  @override
  Future<void> stop() async => detenido = true;

  void oir(String texto, {bool final_ = false}) => oyente!(
    SpeechRecognitionResult([
      SpeechRecognitionWords(texto, null, 0.9),
    ], final_ ? ResultType.finalResult.value : ResultType.partial.value),
  );
}

void main() {
  late _VozFalsa voz;
  late DictadoDelCelular dictado;

  setUp(() {
    voz = _VozFalsa();
    dictado = DictadoDelCelular(voz);
  });

  group('preparar', () {
    test('listo con permiso y español', () async {
      expect(await dictado.preparar(), EstadoDictado.listo);
    });

    test('sin permiso de micrófono', () async {
      voz
        ..inicia = false
        ..permiso = false;
      expect(await dictado.preparar(), EstadoDictado.sinPermiso);
    });

    test('sin reconocedor o sin español no está disponible', () async {
      voz.inicia = false;
      expect(await dictado.preparar(), EstadoDictado.noDisponible);

      voz
        ..inicia = true
        ..idiomas = [LocaleName('en_US', 'English')];
      expect(
        await DictadoDelCelular(voz).preparar(),
        EstadoDictado.noDisponible,
      );
    });
  });

  group('escuchar', () {
    test('solo en el celular, 8 s o 3 s de silencio, en es_CO', () async {
      await dictado.preparar();
      unawaited(dictado.escuchar(alOir: (_) {}));
      await Future<void>.delayed(Duration.zero);

      expect(voz.opciones!.onDevice, isTrue);
      expect(voz.opciones!.listenFor, const Duration(seconds: 8));
      expect(voz.opciones!.pauseFor, const Duration(seconds: 3));
      expect(voz.opciones!.localeId, 'es_CO');
    });

    test('sin es_CO usa otro español', () async {
      voz.idiomas = [LocaleName('es_MX', 'Español (México)')];
      await dictado.preparar();
      unawaited(dictado.escuchar(alOir: (_) {}));
      await Future<void>.delayed(Duration.zero);

      expect(voz.opciones!.localeId, 'es_MX');
    });

    test('pasa lo parcial y devuelve lo final', () async {
      await dictado.preparar();
      final parciales = <String>[];
      final resultado = dictado.escuchar(alOir: parciales.add);
      await Future<void>.delayed(Duration.zero);

      voz.oir('dos coca');
      voz.oir('dos coca colas', final_: true);

      expect(await resultado, 'dos coca colas');
      expect(parciales, ['dos coca', 'dos coca colas']);
    });

    test('si no oyó nada devuelve null', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      voz.alError!(SpeechRecognitionError('error_no_match', false));

      expect(await resultado, isNull);
    });

    test('sin el español sin conexión avisa que no está disponible', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      voz.alError!(SpeechRecognitionError('error_language_unavailable', true));

      await expectLater(resultado, throwsA(isA<DictadoNoDisponible>()));
    });

    test('si termina sin resultado final usa lo último que oyó', () async {
      await dictado.preparar();
      final resultado = dictado.escuchar(alOir: (_) {});
      await Future<void>.delayed(Duration.zero);

      voz.oir('un pan');
      voz.alEstado!('done');

      expect(await resultado, 'un pan');
    });

    test('detener corta la escucha', () async {
      await dictado.preparar();
      unawaited(dictado.escuchar(alOir: (_) {}));
      await dictado.detener();
      expect(voz.detenido, isTrue);
    });
  });
}
