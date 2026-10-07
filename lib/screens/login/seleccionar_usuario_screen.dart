import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usuarios_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../ui/tipografia.dart';
import '../../widgets/nombre_tienda.dart';
import 'ingresar_pin_screen.dart';

class SeleccionarUsuarioScreen extends ConsumerWidget {
  const SeleccionarUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      body: SafeArea(
        child: usuariosAsync.when(
          data: (usuarios) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const MarcaApp(),
              const SizedBox(height: 32),
              const NombreTienda(
                estilo: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.primario),
              ),
              const SizedBox(height: 4),
              Text('¿Quién eres?', style: estiloTitulo()),
              const SizedBox(height: 4),
              const Text('Toca tu nombre para entrar',
                  style: TextStyle(color: ColoresApp.textoSecundario)),
              const SizedBox(height: 16),
              for (final usuario in usuarios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      key: Key('usuario_${usuario.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: AvatarInicial(
                          id: usuario.id, nombre: usuario.nombre, radio: 22),
                      title: Text(usuario.nombre,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      subtitle: Text(etiquetaRol(usuario.rol)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IngresarPinScreen(usuario: usuario),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
