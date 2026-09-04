import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usuarios_providers.dart';
import 'ingresar_pin_screen.dart';

class SeleccionarUsuarioScreen extends ConsumerWidget {
  const SeleccionarUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién eres?')),
      body: usuariosAsync.when(
        data: (usuarios) => ListView(
          children: usuarios
              .map((usuario) => ListTile(
                    key: Key('usuario_${usuario.id}'),
                    leading: const Icon(Icons.person, size: 32),
                    title: Text(usuario.nombre,
                        style: const TextStyle(fontSize: 20)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IngresarPinScreen(usuario: usuario),
                      ),
                    ),
                  ))
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
