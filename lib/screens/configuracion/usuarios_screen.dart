import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../util/pin_hash.dart';
import 'resetear_pin_dialog.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String _rol = 'vendedor';
  String? _errorNombre;
  String? _errorPin;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crearUsuario() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPin = esPinValido(pin) ? null : 'El PIN debe tener 4 dígitos';
    });
    if (_errorNombre != null || _errorPin != null) return;

    await ref.read(usuarioRepositoryProvider).crearUsuario(
          nombre: nombre,
          rol: _rol,
          pin: pin,
        );
    _nombreController.clear();
    _pinController.clear();
    setState(() => _rol = 'vendedor');
    ref.invalidate(listaUsuariosProvider);
  }

  Future<void> _resetearPin(Usuario usuario) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => ResetearPinDialog(usuario: usuario),
    );
    if (actualizado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(
        children: [
          Expanded(
            child: usuariosAsync.when(
              data: (usuarios) => ListView(
                children: usuarios
                    .map((u) => ListTile(
                          key: Key('usuario_item_${u.id}'),
                          title: Text(u.nombre),
                          subtitle: Text(u.rol),
                          trailing: const Icon(Icons.lock_reset),
                          onTap: () => _resetearPin(u),
                        ))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_usuario'),
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _errorNombre,
                  ),
                ),
                TextField(
                  key: const Key('campo_pin_usuario'),
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: 'PIN de 4 dígitos',
                    errorText: _errorPin,
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const Key('selector_rol'),
                  segments: const [
                    ButtonSegment(value: 'vendedor', label: Text('Vendedor')),
                    ButtonSegment(value: 'admin', label: Text('Administrador')),
                  ],
                  selected: {_rol},
                  onSelectionChanged: (seleccion) =>
                      setState(() => _rol = seleccion.first),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_usuario'),
                  onPressed: _crearUsuario,
                  child: const Text('Agregar usuario'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
