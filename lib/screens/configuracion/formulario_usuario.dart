import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/selector_segmentado.dart';
import '../../util/id_global.dart';
import '../../util/pin_hash.dart';
import 'editar_usuario_sheet.dart';

/// Formulario para crear un usuario. Con [soloVendedor] no ofrece elegir el
/// rol: siempre crea un vendedor. Cierra con el id del usuario creado.
class FormularioUsuario extends ConsumerStatefulWidget {
  const FormularioUsuario({super.key, this.soloVendedor = false});

  final bool soloVendedor;

  @override
  ConsumerState<FormularioUsuario> createState() => FormularioUsuarioState();
}

class FormularioUsuarioState extends ConsumerState<FormularioUsuario> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String _rol = 'vendedor';
  bool _manejaCatalogo = false;
  String? _errorNombre;
  String? _errorPin;
  String? _errorGeneral;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPin = esPinValido(pin) ? null : 'El PIN debe tener 4 dígitos';
    });
    if (_errorNombre != null || _errorPin != null) return;

    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });
    try {
      final repo = ref.read(usuarioRepositoryProvider);
      final sincronizacion = ref.read(sincronizacionProvider.notifier);
      final numero = _rol == 'vendedor'
          ? await repo.siguienteNumeroVendedor()
          : null;
      String? idGlobal;
      // En la tienda compartida el PIN vive en la nube: si no llega, el
      // usuario no podría entrar en otro celular, así que no se crea.
      if (await sincronizacion.esCompartida()) {
        idGlobal = generarIdGlobal();
        try {
          await sincronizacion.guardarPinEnTienda(
            idGlobal: idGlobal,
            pin: pin,
            version: 0,
          );
        } catch (error) {
          if (mounted) setState(() => _errorGeneral = mensajeErrorPin(error));
          return;
        }
      }
      final id = await repo.crearUsuario(
        nombre: nombre,
        rol: _rol,
        pin: pin,
        manejaCatalogo: _rol == 'vendedor' && _manejaCatalogo,
        numeroVendedor: numero,
        idGlobal: idGlobal,
      );
      if (mounted) Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('campo_nombre_usuario'),
          controller: _nombreController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre',
            errorText: _errorNombre,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_pin_usuario'),
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: 'PIN de 4 dígitos',
            errorText: _errorPin,
          ),
        ),
        const SizedBox(height: 4),
        if (!widget.soloVendedor)
          SelectorSegmentado<String>(
            key: const Key('selector_rol'),
            opciones: const {'vendedor': 'Vendedor', 'admin': 'Administrador'},
            valor: _rol,
            onCambio: (rol) => setState(() => _rol = rol),
          ),
        if (_rol == 'vendedor')
          InterruptorPermisoCatalogo(
            valor: _manejaCatalogo,
            onCambio: (valor) => setState(() => _manejaCatalogo = valor),
          ),
        if (_errorGeneral != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorGeneral!,
            key: const Key('error_crear_usuario'),
            style: TextStyle(color: ColoresApp.of(context).sale),
          ),
        ],
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_crear_usuario'),
          texto: 'Agregar usuario',
          onPressed: _guardando ? null : _crear,
        ),
      ],
    );
  }
}

/// Por qué no se pudo guardar el PIN en la tienda compartida.
String mensajeErrorPin(Object error) => error is ErrorSinConexion
    ? mensajeSinInternetPin
    : mensajeErrorTienda(error);
