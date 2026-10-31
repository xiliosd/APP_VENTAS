import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/huella_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../servicios/autenticacion_huella.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../../ui/vibracion.dart';
import '../../widgets/teclado_numerico.dart';
import '../../widgets/indicadores_pin.dart';
import '../../widgets/nombre_tienda.dart';

class IngresarPinScreen extends ConsumerStatefulWidget {
  const IngresarPinScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<IngresarPinScreen> createState() => _IngresarPinScreenState();
}

class _IngresarPinScreenState extends ConsumerState<IngresarPinScreen> {
  String _pin = '';
  String? _error;

  /// Cada PIN incorrecto lo aumenta y sacude los indicadores.
  int _errores = 0;

  /// Hay un diálogo de huella abierto: un segundo toque no abre otro.
  bool _usandoHuella = false;

  Future<void> _entrarConHuella() async {
    if (_usandoHuella) return;
    setState(() {
      _usandoHuella = true;
      _error = null;
    });
    final resultado = await ref
        .read(autenticacionHuellaProvider)
        .confirmar('Confirma que eres ${widget.usuario.nombre}');
    if (!mounted) return;
    var ok = false;
    var fallo = false;
    if (resultado == ResultadoHuella.aprobada) {
      try {
        ok = await ref
            .read(sesionProvider.notifier)
            .iniciarSesionConHuella(widget.usuario.id);
      } catch (_) {
        // Sin esto el botón quedaría bloqueado: el PIN sigue disponible.
        fallo = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _usandoHuella = false;
      _error = fallo
          ? 'No se pudo entrar con la huella: usa tu PIN'
          : switch (resultado) {
              ResultadoHuella.bloqueada =>
                'Demasiados intentos con la huella: usa tu PIN',
              ResultadoHuella.sinHuellas =>
                'Este celular ya no tiene huellas registradas: usa tu PIN',
              ResultadoHuella.noDisponible =>
                'El sensor de huella no responde ahora: usa tu PIN',
              _ => null,
            };
    });
    if (ok && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _validar() async {
    final ok = await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(widget.usuario.id, _pin);
    if (!mounted) return;
    if (!ok) {
      Vibracion.error();
      setState(() {
        _error = 'PIN incorrecto';
        _pin = '';
        _errores++;
      });
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _presionarDigito(String digito) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
    if (_pin.length == 4) _validar();
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final conHuella =
        ref.watch(usuariosConHuellaProvider).contains(usuario.id) &&
        (ref.watch(huellaDisponibleProvider).valueOrNull ?? false);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        // Desplazable para pantallas bajas o letra grande; en pantallas
        // altas el teclado queda abajo gracias al Spacer.
        child: LayoutBuilder(
          builder: (context, limites) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: limites.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    NombreTienda(
                      estilo: TextStyle(
                        color: ColoresApp.of(context).textoSecundario,
                        fontWeight: FontWeight.w600,
                      ),
                      espacioAbajo: 12,
                    ),
                    Hero(
                      tag: 'avatar_${usuario.id}',
                      child: AvatarInicial(
                        id: usuario.id,
                        nombre: usuario.nombre,
                        radio: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hola, ${usuario.nombre}',
                      style: estiloTitulo(tamano: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ingresa tu PIN',
                      style: TextStyle(
                        color: ColoresApp.of(context).textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 24),
                    IndicadoresPin(llenos: _pin.length, errores: _errores),
                    SizedBox(
                      height: 32,
                      child: _error == null
                          ? null
                          : Center(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: ColoresApp.of(context).sale,
                                ),
                              ),
                            ),
                    ),
                    const Spacer(),
                    TecladoNumerico(
                      onDigito: _presionarDigito,
                      onBorrar: _borrar,
                    ),
                    if (conHuella) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('boton_huella'),
                        onPressed: _usandoHuella ? null : _entrarConHuella,
                        icon: const Icon(Icons.fingerprint_rounded, size: 28),
                        label: const Text('Entrar con huella'),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
