import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Si se puede dictar en este celular.
enum EstadoDictado { listo, sinPermiso, noDisponible }

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

class DictadoDelCelular implements Dictado {
  DictadoDelCelular([SpeechToText? voz]) : _voz = voz ?? SpeechToText();

  final SpeechToText _voz;
  String? _idioma;
  Completer<String?>? _escucha;
  String _ultimo = '';

  @override
  Future<EstadoDictado> preparar() async {
    try {
      final ok = await _voz.initialize(onError: _alError, onStatus: _alEstado);
      if (!ok) {
        return await _voz.hasPermission
            ? EstadoDictado.noDisponible
            : EstadoDictado.sinPermiso;
      }
      final idiomas = await _voz.locales();
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
    await _voz.listen(
      onResult: (SpeechRecognitionResult r) {
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
    escucha.complete(texto.trim().isEmpty ? null : texto.trim());
  }
}

final dictadoProvider = Provider<Dictado>((ref) => DictadoDelCelular());
