import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../../ui/vibracion.dart';
import '../../widgets/teclado_numerico.dart';
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
                          fontWeight: FontWeight.w600),
                      espacioAbajo: 12,
                    ),
                    AvatarInicial(
                      id: usuario.id,
                      nombre: usuario.nombre,
                      radio: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hola, ${usuario.nombre}',
                      style: estiloTitulo(tamano: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ingresa tu PIN',
                      style: TextStyle(color: ColoresApp.of(context).textoSecundario),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _pin.length
                                  ? ColoresApp.of(context).primario
                                  : Colors.transparent,
                              border: Border.all(
                                color: ColoresApp.of(context).primario,
                                width: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 32,
                      child: _error == null
                          ? null
                          : Center(
                              child: Text(
                                _error!,
                                style: TextStyle(color: ColoresApp.of(context).sale),
                              ),
                            ),
                    ),
                    const Spacer(),
                    TecladoNumerico(
                      onDigito: _presionarDigito,
                      onBorrar: _borrar,
                    ),
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
