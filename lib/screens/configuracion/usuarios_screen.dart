import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/selector_segmentado.dart';
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
                        title: Text(u.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(etiquetaRol(u.rol)),
                        trailing: const Icon(Icons.lock_reset_rounded),
                        onTap: () => _resetearPin(u),
                      ),
                  ],
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
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

    setState(() => _guardando = true);
    try {
      await ref
          .read(usuarioRepositoryProvider)
          .crearUsuario(nombre: nombre, rol: _rol, pin: pin);
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
          decoration:
              InputDecoration(labelText: 'Nombre', errorText: _errorNombre),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_pin_usuario'),
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: InputDecoration(
              labelText: 'PIN de 4 dígitos', errorText: _errorPin),
        ),
        const SizedBox(height: 4),
        SelectorSegmentado<String>(
          key: const Key('selector_rol'),
          opciones: const {'vendedor': 'Vendedor', 'admin': 'Administrador'},
          valor: _rol,
          onCambio: (rol) => setState(() => _rol = rol),
        ),
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
