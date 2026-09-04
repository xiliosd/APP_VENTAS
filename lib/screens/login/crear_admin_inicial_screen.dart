import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';

class CrearAdminInicialScreen extends ConsumerStatefulWidget {
  const CrearAdminInicialScreen({super.key});

  @override
  ConsumerState<CrearAdminInicialScreen> createState() =>
      _CrearAdminInicialScreenState();
}

class _CrearAdminInicialScreenState
    extends ConsumerState<CrearAdminInicialScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String? _error;

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }

    final repo = ref.read(usuarioRepositoryProvider);
    final id = await repo.crearUsuario(nombre: nombre, rol: 'admin', pin: pin);
    ref.invalidate(listaUsuariosProvider);
    ref.invalidate(haySesionUsuariosProvider);
    await ref.read(sesionProvider.notifier).iniciarSesion(id, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configura tu tienda')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Crea el usuario administrador de tu tienda',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_nombre_admin'),
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_pin_admin'),
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('boton_crear_admin'),
              onPressed: _crear,
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
