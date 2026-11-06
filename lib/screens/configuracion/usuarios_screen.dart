import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../ui/error_carga.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/pildora.dart';
import '../../ui/selector_segmentado.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../util/id_global.dart';
import '../../util/pin_hash.dart';
import 'resetear_pin_dialog.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  Future<void> _agregar() async {
    final creado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Nuevo usuario',
      builder: (_) => const _FormularioUsuario(),
    );
    if (creado == true && mounted) {
      ref.invalidate(listaUsuariosProvider);
      avisar(context, 'Usuario creado');
    }
  }

  Future<void> _resetearPin(Usuario usuario) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => ResetearPinDialog(usuario: usuario),
    );
    if (actualizado == true && mounted) avisar(context, 'PIN actualizado');
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    final actual = ref.watch(sesionProvider).usuarioActivo?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_usuario'),
        onPressed: _agregar,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Agregar'),
      ),
      body: usuariosAsync.when(
        data: (usuarios) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (usuarios.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (final u in usuarios)
                      ListTile(
                        key: Key('usuario_item_${u.id}'),
                        leading: AvatarInicial(id: u.id, nombre: u.nombre),
                        title: Text(
                          u.id == actual ? '${u.nombre} (tú)' : u.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Pildora(
                              key: Key('rol_${u.id}'),
                              texto:
                                  u.rol == 'vendedor' &&
                                      u.numeroVendedor != null
                                  ? 'Vendedor ${u.numeroVendedor}'
                                  : etiquetaRol(u.rol),
                              color: u.rol == 'admin'
                                  ? ColoresApp.of(context).primario
                                  : ColoresApp.of(context).marcaVerde,
                            ),
                          ),
                        ),
                        trailing: const Icon(Icons.lock_reset_rounded),
                        onTap: () => _resetearPin(u),
                      ),
                  ],
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorCarga(),
      ),
    );
  }
}

class _FormularioUsuario extends ConsumerStatefulWidget {
  const _FormularioUsuario();

  @override
  ConsumerState<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends ConsumerState<_FormularioUsuario> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String _rol = 'vendedor';
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
      await repo.crearUsuario(
        nombre: nombre,
        rol: _rol,
        pin: pin,
        numeroVendedor: numero,
        idGlobal: idGlobal,
      );
      if (mounted) Navigator.of(context).pop(true);
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
        SelectorSegmentado<String>(
          key: const Key('selector_rol'),
          opciones: const {'vendedor': 'Vendedor', 'admin': 'Administrador'},
          valor: _rol,
          onCambio: (rol) => setState(() => _rol = rol),
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
