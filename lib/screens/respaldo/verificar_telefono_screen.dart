import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/nube_respaldo.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../respaldo/restaurador.dart';
import '../../respaldo/telefono.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import 'dialogo_respaldo_existente.dart';

enum ModoVerificacion { activar, restaurar }

/// Verifica el celular de la tienda con un código, para activar el respaldo
/// o restaurarlo en este celular.
class VerificarTelefonoScreen extends ConsumerStatefulWidget {
  const VerificarTelefonoScreen({super.key, required this.modo});

  final ModoVerificacion modo;

  @override
  ConsumerState<VerificarTelefonoScreen> createState() =>
      _VerificarTelefonoScreenState();
}

class _VerificarTelefonoScreenState
    extends ConsumerState<VerificarTelefonoScreen> {
  final _telefonoController = TextEditingController();
  final _codigoController = TextEditingController();

  /// Número (E.164) al que se envió el código; null mientras se pide.
  String? _telefono;
  String? _error;
  bool _ocupado = false;
  int _segundosParaReenviar = 0;
  Timer? _cuentaRegresiva;

  RespaldoNotifier get _respaldo => ref.read(respaldoProvider.notifier);

  @override
  void dispose() {
    _cuentaRegresiva?.cancel();
    _telefonoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _iniciarCuentaRegresiva() {
    _cuentaRegresiva?.cancel();
    setState(() => _segundosParaReenviar = 60);
    _cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundosParaReenviar--);
      if (_segundosParaReenviar <= 0) timer.cancel();
    });
  }

  /// Corre [accion] con la pantalla ocupada (evita dobles toques) y traduce
  /// los errores a mensajes.
  Future<void> _ejecutar(
    Future<void> Function() accion, {
    required String errorGeneral,
  }) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on ErrorCodigoRespaldo {
      if (mounted) setState(() => _error = 'Código incorrecto o vencido');
    } catch (_) {
      if (mounted) setState(() => _error = errorGeneral);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarCodigo() async {
    final telefono = telefonoE164(_telefonoController.text);
    if (telefono == null) {
      setState(
        () => _error = 'Escribe un celular de 10 dígitos que empiece por 3',
      );
      return;
    }
    await _ejecutar(
      () async {
        await _respaldo.enviarCodigo(telefono);
        if (!mounted) return;
        setState(() => _telefono = telefono);
        _iniciarCuentaRegresiva();
      },
      errorGeneral:
          'No pudimos enviar el código. Revisa el número y tu internet.',
    );
  }

  Future<void> _reenviar() => _ejecutar(() async {
    await _respaldo.enviarCodigo(_telefono!);
    if (mounted) _iniciarCuentaRegresiva();
  }, errorGeneral: 'No pudimos reenviar el código. Revisa tu internet.');

  Future<void> _verificar() async {
    final codigo = _codigoController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'El código tiene 6 dígitos');
      return;
    }
    const sinConexion =
        'No hay conexión. Revisa tu internet e inténtalo de nuevo.';
    DateTime? fechaExistente;
    var verificado = false;
    await _ejecutar(() async {
      fechaExistente = await _respaldo.verificar(_telefono!, codigo);
      verificado = true;
    }, errorGeneral: sinConexion);
    if (!verificado || !mounted) return;
    // La pantalla deja de estar "ocupada" mientras el usuario decide en los
    // diálogos; solo las operaciones de red muestran el indicador.
    if (widget.modo == ModoVerificacion.restaurar) {
      await _ejecutar(_restaurar, errorGeneral: sinConexion);
    } else {
      await _activar(fechaExistente, errorGeneral: sinConexion);
    }
  }

  Future<void> _restaurar() async {
    final resultado = await _respaldo.restaurar();
    if (!mounted) return;
    switch (resultado) {
      case ResultadoRestauracion.restaurado:
        avisar(context, 'Respaldo restaurado. Entra con tu PIN.');
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      case ResultadoRestauracion.sinRespaldo:
        avisar(context, 'No encontramos un respaldo para este número',
            error: true);
        Navigator.of(context).pop();
      case ResultadoRestauracion.invalido:
        setState(
          () => _error =
              'El respaldo no se pudo leer; tus datos actuales no se tocaron',
        );
    }
  }

  Future<void> _activar(
    DateTime? fechaExistente, {
    required String errorGeneral,
  }) async {
    if (fechaExistente == null) {
      return _ejecutar(_terminarActivacion, errorGeneral: errorGeneral);
    }

    final eleccion = await showDialog<EleccionRespaldoExistente>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoRespaldoExistente(fecha: fechaExistente),
    );
    if (!mounted) return;
    switch (eleccion) {
      case EleccionRespaldoExistente.restaurar:
        if (await _confirmarRestauracion()) {
          await _ejecutar(_restaurar, errorGeneral: errorGeneral);
        } else {
          await _ejecutar(_cancelarActivacion, errorGeneral: errorGeneral);
        }
      case EleccionRespaldoExistente.reemplazar:
        await _ejecutar(_terminarActivacion, errorGeneral: errorGeneral);
      case EleccionRespaldoExistente.cancelar:
      case null:
        await _ejecutar(_cancelarActivacion, errorGeneral: errorGeneral);
    }
  }

  Future<bool> _confirmarRestauracion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Restaurar el respaldo?'),
        content: const Text('Se reemplazarán los datos de este celular'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('boton_confirmar_restaurar'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  Future<void> _terminarActivacion() async {
    await _respaldo.activar();
    if (!mounted) return;
    avisar(context, 'Respaldo activado');
    Navigator.of(context).pop();
  }

  Future<void> _cancelarActivacion() async {
    await _respaldo.desconectar();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esperandoCodigo = _telefono != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.modo == ModoVerificacion.restaurar
              ? 'Restaurar respaldo'
              : 'Activar respaldo',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            esperandoCodigo
                ? 'Escribe el código que llegó por SMS al '
                      '${telefonoEnmascarado(_telefono!)}.'
                : 'Escribe el celular de la tienda. Te enviaremos un código '
                      'por SMS.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (!esperandoCodigo)
            TextField(
              key: const Key('campo_telefono'),
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Celular',
                prefixText: '+57 ',
                errorText: _error,
                errorMaxLines: 2,
              ),
            )
          else
            TextField(
              key: const Key('campo_codigo'),
              controller: _codigoController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Código de 6 dígitos',
                errorText: _error,
                errorMaxLines: 2,
              ),
            ),
          const SizedBox(height: 8),
          BotonPrincipal(
            key: Key(
              esperandoCodigo ? 'boton_verificar' : 'boton_enviar_codigo',
            ),
            texto: esperandoCodigo ? 'Verificar' : 'Enviarme el código',
            onPressed: _ocupado
                ? null
                : (esperandoCodigo ? _verificar : _enviarCodigo),
          ),
          if (esperandoCodigo)
            TextButton(
              key: const Key('boton_reenviar'),
              onPressed: _segundosParaReenviar > 0 || _ocupado
                  ? null
                  : _reenviar,
              child: Text(
                _segundosParaReenviar > 0
                    ? 'Reenviar código en $_segundosParaReenviar s'
                    : 'Reenviar código',
              ),
            ),
          if (_ocupado)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: CircularProgressIndicator(color: ColoresApp.of(context).primario),
              ),
            ),
        ],
      ),
    );
  }
}
