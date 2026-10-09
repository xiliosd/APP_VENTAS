import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usuarios_providers.dart';
import '../../data/database.dart';
import '../../ui/aplastable.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/marca_app.dart';
import '../../ui/tema_app.dart';
import '../../ui/tipografia.dart';
import '../../ui/vibracion.dart';
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
              NombreTienda(
                estilo: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.of(context).primario),
              ),
              const SizedBox(height: 4),
              Text('¿Quién eres?', style: estiloTitulo()),
              const SizedBox(height: 4),
              Text('Toca tu nombre para entrar',
                  style: TextStyle(color: ColoresApp.of(context).textoSecundario)),
              const SizedBox(height: 16),
              const SizedBox(height: 4),
              _GrillaUsuarios(usuarios: usuarios),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

/// Usuarios en tarjetas grandes: 2 columnas; una sola si hay un usuario o
/// la letra del celular es muy grande.
class _GrillaUsuarios extends StatelessWidget {
  const _GrillaUsuarios({required this.usuarios});

  final List<Usuario> usuarios;

  @override
  Widget build(BuildContext context) {
    final letraGrande = MediaQuery.textScalerOf(context).scale(18) > 27;
    return LayoutBuilder(
      builder: (context, limites) {
        final columnas = usuarios.length == 1 || letraGrande ? 1 : 2;
        final ancho = (limites.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < usuarios.length; i++)
              SizedBox(
                width: ancho,
                child: EntradaEscalonada(
                  indice: i,
                  child: _TarjetaUsuario(usuario: usuarios[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Aplastable(
      child: Material(
        key: Key('usuario_${usuario.id}'),
        color: c.superficie,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioTarjeta)),
        child: InkWell(
          borderRadius: BorderRadius.circular(radioTarjeta),
          onTap: () {
            Vibracion.toque();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => IngresarPinScreen(usuario: usuario)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                Hero(
                  tag: 'avatar_${usuario.id}',
                  child: AvatarInicial(
                      id: usuario.id, nombre: usuario.nombre, radio: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  usuario.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(etiquetaRol(usuario.rol),
                    style: TextStyle(color: c.textoSecundario)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
