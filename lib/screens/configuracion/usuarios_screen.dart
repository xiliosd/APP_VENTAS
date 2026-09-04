import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();

  Future<void> _crearVendedor() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty || pin.length != 4 || int.tryParse(pin) == null) return;

    await ref.read(usuarioRepositoryProvider).crearUsuario(
          nombre: nombre,
          rol: 'vendedor',
          pin: pin,
        );
    _nombreController.clear();
    _pinController.clear();
    ref.invalidate(listaUsuariosProvider);
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
                  key: const Key('campo_nombre_vendedor'),
                  controller: _nombreController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del vendedor'),
                ),
                TextField(
                  key: const Key('campo_pin_vendedor'),
                  controller: _pinController,
                  decoration:
                      const InputDecoration(labelText: 'PIN de 4 dígitos'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_vendedor'),
                  onPressed: _crearVendedor,
                  child: const Text('Agregar vendedor'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
