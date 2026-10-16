import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Si se puede dictar en este celular. [sinDictadoLocal]: Android no
/// reconoce la voz dentro del celular (antes de Android 12, o sin el
/// servicio local), y dictar mandaría el audio a internet.
enum EstadoDictado { listo, sinPermiso, noDisponible, sinDictadoLocal }

/// El reconocedor no puede trabajar sin conexión (falta el español
/// descargado) o no existe.
class DictadoNoDisponible implements Exception {
  const DictadoNoDisponible();
}

/// Dictado de voz a texto, solo dentro del celular: el audio no sale del
/// teléfono.
abstract class Dictado {
  Future<EstadoDictado> preparar();

  /// Escucha y pasa a [alOir] lo que va entendiendo. Devuelve el texto
  /// final, o null si no oyó nada; lanza [DictadoNoDisponible] si el
  /// reconocedor no puede trabajar sin conexión.
  Future<String?> escuchar({required void Function(String parcial) alOir});

  Future<void> detener();
}

/// Errores del reconocedor de Android que significan "no hay español sin
/// conexión" (no "no te entendí").
const _sinIdioma = {
  'error_language_not_supported',
  'error_language_unavailable',
  'error_server_disconnected',
};

const _canalVoz = MethodChannel('vecitienda/voz');

/// Pregunta a Android (MainActivity) si hay reconocimiento de voz local.
Future<bool> _hayReconocimientoLocalEnAndroid() async {
  try {
    return await _canalVoz.invokeMethod<bool>('hayReconocimientoLocal') ??
        false;
  } catch (_) {
    return false;
  }
}

class DictadoDelCelular implements Dictado {
  DictadoDelCelular(
    SpeechToText? voz, {
    Future<bool> Function()? hayReconocimientoLocal,
    this.esperaIdiomas = const Duration(seconds: 3),
  }) : _voz = voz ?? SpeechToText(),
       _hayReconocimientoLocal =
           hayReconocimientoLocal ?? _hayReconocimientoLocalEnAndroid;

  final SpeechToText _voz;
  final Future<bool> Function() _hayReconocimientoLocal;

  /// El plugin puede no responder nunca la lista de idiomas.
  final Duration esperaIdiomas;

  /// Si el reconocedor no avisa que terminó: escucha (8 s) + resultado
  /// final del plugin (2 s) + margen.
  static const _esperaMaxima = Duration(seconds: 12);
  Timer? _plazo;
  String? _idioma;
  Completer<String?>? _escucha;
  String _ultimo = '';

  @override
  Future<EstadoDictado> preparar() async {
    try {
      // speech_to_text con onDevice cae en silencio al servicio en línea si
      // no hay reconocedor local: aquí se exige que exista.
      if (!await _hayReconocimientoLocal()) {
        return EstadoDictado.sinDictadoLocal;
      }
      final ok = await _voz.initialize(onError: _alError, onStatus: _alEstado);
      if (!ok) {
        return await _voz.hasPermission
            ? EstadoDictado.noDisponible
            : EstadoDictado.sinPermiso;
      }
      final idiomas = await _voz.locales().timeout(esperaIdiomas);
      final espanol = idiomas
          .map((l) => l.localeId)
          .where((id) => id.toLowerCase().startsWith('es'))
          .toList();
      if (espanol.isEmpty) return EstadoDictado.noDisponible;
      _idioma = espanol.firstWhere(
        (id) => id.replaceAll('-', '_') == 'es_CO',
        orElse: () => espanol.first,
      );
      return EstadoDictado.listo;
    } catch (_) {
      return EstadoDictado.noDisponible;
    }
  }

  @override
  Future<String?> escuchar({
    required void Function(String parcial) alOir,
  }) async {
    final escucha = _escucha = Completer<String?>();
    _ultimo = '';
    _plazo?.cancel();
    _plazo = Timer(_esperaMaxima, () => _terminar(_ultimo));
    try {
      await _voz.listen(
        onResult: (SpeechRecognitionResult r) {
          // Tras "Listo" el plugin aún entrega el resultado: ya no cuenta.
          if (escucha.isCompleted) return;
          _ultimo = r.recognizedWords;
          alOir(_ultimo);
          if (r.finalResult) _terminar(_ultimo);
        },
        listenOptions: SpeechListenOptions(
          onDevice: true,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
          localeId: _idioma,
        ),
      );
    } catch (_) {
      _terminar('');
    }
    return escucha.future;
  }

  @override
  Future<void> detener() async {
    await _voz.stop();
    _terminar(_ultimo);
  }

  void _alError(SpeechRecognitionError error) {
    final escucha = _escucha;
    if (escucha == null || escucha.isCompleted) return;
    if (_sinIdioma.contains(error.errorMsg)) {
      _plazo?.cancel();
      escucha.completeError(const DictadoNoDisponible());
    } else {
      _terminar(_ultimo);
    }
  }

  void _alEstado(String estado) {
    if (estado == SpeechToText.doneStatus) _terminar(_ultimo);
  }

  void _terminar(String texto) {
    final escucha = _escucha;
    if (escucha == null || escucha.isCompleted) return;
    _plazo?.cancel();
    escucha.complete(texto.trim().isEmpty ? null : texto.trim());
  }
}

final dictadoProvider = Provider<Dictado>((ref) => DictadoDelCelular(null));
