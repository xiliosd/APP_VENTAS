import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Lo que avisa el reconocedor de Android mientras escucha.
sealed class EventoVoz {
  const EventoVoz();
}

class TextoParcial extends EventoVoz {
  const TextoParcial(this.texto);

  final String texto;
}

/// Lo último que entendió; después de esto el reconocedor ya se apagó.
class TextoFinal extends EventoVoz {
  const TextoFinal(this.texto);

  final String texto;
}

/// Error de `SpeechRecognizer`; después de esto el reconocedor ya se apagó.
class ErrorVoz extends EventoVoz {
  const ErrorVoz(this.codigo);

  final int codigo;

  static const silencio = 6;
  static const sinCoincidencia = 7;
  static const servidorDesconectado = 11;
  static const idiomaNoSoportado = 12;
  static const idiomaNoDisponible = 13;

  /// Errores que significan "no hay español sin conexión" (no "no te
  /// entendí"): el reconocedor local se cae si el idioma no está descargado.
  bool get sinIdioma =>
      codigo == servidorDesconectado ||
      codigo == idiomaNoSoportado ||
      codigo == idiomaNoDisponible;
}

/// El reconocedor de voz local de Android (MainActivity y DictadoLocal).
abstract class ReconocedorLocal {
  Future<bool> hayReconocimientoLocal();

  /// Idiomas descargados (p. ej. "es-US"), o null si Android no lo dice
  /// (antes de Android 13).
  Future<List<String>?> idiomasDescargados();

  /// Pide el micrófono si hace falta; true si quedó permitido.
  Future<bool> pedirPermiso();

  /// Empieza a escuchar en [idioma] (null: el del celular) y pasa a
  /// [alEvento] lo que va pasando, hasta un [TextoFinal] o un [ErrorVoz].
  Future<void> escuchar({
    required String? idioma,
    required void Function(EventoVoz evento) alEvento,
  });

  /// Deja de oír; lo final llega después por `alEvento`.
  Future<void> detener();
}

class CanalVoz implements ReconocedorLocal {
  CanalVoz() {
    _canal.setMethodCallHandler(_recibir);
  }

  static const _canal = MethodChannel('vecitienda/voz');

  /// Silencio que da por terminado el dictado.
  static const _silencio = Duration(seconds: 3);

  void Function(EventoVoz evento)? _alEvento;

  Future<void> _recibir(MethodCall llamada) async {
    final evento = switch (llamada.method) {
      'parcial' => TextoParcial(llamada.arguments as String),
      'final' => TextoFinal(llamada.arguments as String),
      'error' => ErrorVoz(llamada.arguments as int),
      _ => null,
    };
    if (evento != null) _alEvento?.call(evento);
  }

  @override
  Future<bool> hayReconocimientoLocal() async {
    try {
      return await _canal.invokeMethod<bool>('hayReconocimientoLocal') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>?> idiomasDescargados() async {
    try {
      return await _canal.invokeListMethod<String>('idiomasDescargados');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> pedirPermiso() async =>
      await _canal.invokeMethod<bool>('pedirPermiso') ?? false;

  @override
  Future<void> escuchar({
    required String? idioma,
    required void Function(EventoVoz evento) alEvento,
  }) async {
    _alEvento = alEvento;
    await _canal.invokeMethod<void>('escuchar', {
      'idioma': idioma,
      'silencioMs': _silencio.inMilliseconds,
    });
  }

  @override
  Future<void> detener() => _canal.invokeMethod<void>('detener');
}

/// Español preferido: el de Colombia, luego el latino de Estados Unidos,
/// luego cualquiera.
const _espanolPreferido = ['es-co', 'es-us'];

/// El español de [ids] que se va a usar, o null si no hay ninguno.
String? _elegirEspanol(Iterable<String> ids) {
  final espanol = ids
      .map((id) => id.replaceAll('_', '-'))
      .where((id) => id.toLowerCase().startsWith('es'))
      .toList();
  for (final preferido in _espanolPreferido) {
    for (final id in espanol) {
      if (id.toLowerCase() == preferido) return id;
    }
  }
  return espanol.firstOrNull;
}

class DictadoDelCelular implements Dictado {
  DictadoDelCelular(
    ReconocedorLocal? reconocedor, {
    this.esperaIdiomas = const Duration(seconds: 3),
    this.duracionEscucha = const Duration(seconds: 8),
    this.esperaMaxima = const Duration(seconds: 12),
  }) : _reconocedor = reconocedor ?? CanalVoz();

  final ReconocedorLocal _reconocedor;

  /// Android puede no responder nunca la lista de idiomas.
  final Duration esperaIdiomas;

  /// Lo más que se escucha antes de pedir lo final.
  final Duration duracionEscucha;

  /// Si el reconocedor no avisa que terminó: escucha + lo final + margen.
  final Duration esperaMaxima;

  Timer? _limiteEscucha;
  Timer? _plazo;
  String? _idioma;
  Completer<String?>? _escucha;
  String _ultimo = '';

  @override
  Future<EstadoDictado> preparar() async {
    try {
      if (!await _reconocedor.hayReconocimientoLocal()) {
        return EstadoDictado.sinDictadoLocal;
      }
      if (!await _reconocedor.pedirPermiso()) return EstadoDictado.sinPermiso;
      // Android lista como soportados idiomas que no están descargados, y
      // pedir uno de esos corta la escucha al instante.
      final descargados = await _reconocedor.idiomasDescargados().timeout(
        esperaIdiomas,
      );
      if (descargados == null) {
        _idioma = null;
        return EstadoDictado.listo;
      }
      _idioma = _elegirEspanol(descargados);
      return _idioma == null ? EstadoDictado.noDisponible : EstadoDictado.listo;
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
    _cancelarPlazos();
    _limiteEscucha = Timer(duracionEscucha, _reconocedor.detener);
    _plazo = Timer(esperaMaxima, () => _terminar(_ultimo));
    try {
      await _reconocedor.escuchar(
        idioma: _idioma,
        alEvento: (evento) {
          // Tras "Listo" el reconocedor aún entrega lo final: ya no cuenta.
          if (escucha.isCompleted) return;
          switch (evento) {
            case TextoParcial(:final texto):
              // El reconocedor local manda "" antes de terminar: no borra
              // lo que ya oyó.
              if (texto.trim().isEmpty) return;
              _ultimo = texto;
              alOir(texto);
            case TextoFinal(:final texto):
              if (texto.trim().isNotEmpty) {
                _ultimo = texto;
                alOir(texto);
              }
              _terminar(_ultimo);
            case ErrorVoz() when evento.sinIdioma:
              _cancelarPlazos();
              escucha.completeError(const DictadoNoDisponible());
            case ErrorVoz():
              _terminar(_ultimo);
          }
        },
      );
    } catch (_) {
      _terminar('');
    }
    return escucha.future;
  }

  @override
  Future<void> detener() async {
    _terminar(_ultimo);
    await _reconocedor.detener();
  }

  void _cancelarPlazos() {
    _limiteEscucha?.cancel();
    _plazo?.cancel();
  }

  void _terminar(String texto) {
    final escucha = _escucha;
    if (escucha == null || escucha.isCompleted) return;
    _cancelarPlazos();
    escucha.complete(texto.trim().isEmpty ? null : texto.trim());
  }
}

final dictadoProvider = Provider<Dictado>((ref) => DictadoDelCelular(null));
