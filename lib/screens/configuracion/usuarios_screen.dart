import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../ui/error_carga.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/pildora.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../agregar_celular/agregar_celular_screen.dart';
import 'editar_usuario_sheet.dart';
import 'formulario_usuario.dart';
import 'resetear_pin_dialog.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  Future<void> _agregar() async {
    final creado = await mostrarHojaInferior<int>(
      context,
      titulo: 'Nuevo usuario',
      builder: (_) => const FormularioUsuario(),
    );
    if (creado != null && mounted) {
      ref.invalidate(listaUsuariosProvider);
      avisar(context, 'Usuario creado');
    }
  }

  Future<void> _desactivar(Usuario usuario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Desactivar vendedor'),
        content: Text(
          '¿Desactivar a ${usuario.nombre}? No podrá entrar y su celular '
          'dejará de tener los datos de la tienda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar_desactivar'),
            style: FilledButton.styleFrom(
              backgroundColor: ColoresApp.of(contexto).sale,
              foregroundColor: ColoresApp.of(contexto).sobreSale,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final sincronizacion = ref.read(sincronizacionProvider.notifier);
    // En la tienda compartida primero se le quita el acceso en la nube: si
    // no llega, su celular seguiría con los datos.
    if (await sincronizacion.esCompartida()) {
      try {
        await sincronizacion.desactivarVendedor(usuario.idGlobal);
      } catch (error) {
        if (mounted) {
          avisar(
            context,
            error is ErrorSinConexion
                ? 'Necesitas internet para desactivar a un vendedor de la '
                      'tienda compartida.'
                : mensajeErrorTienda(error),
            error: true,
          );
        }
        return;
      }
    }
    await ref.read(usuarioRepositoryProvider).desactivar(usuario.id);
    if (!mounted) return;
    ref.invalidate(listaUsuariosProvider);
    avisar(context, '${usuario.nombre} ya no puede entrar');
  }

  Future<void> _activar(Usuario usuario) async {
    final activado = await showDialog<bool>(
      context: context,
      builder: (_) => ResetearPinDialog(usuario: usuario, activar: true),
    );
    if (activado != true || !mounted) return;
    ref.invalidate(listaUsuariosProvider);
    avisar(context, '${usuario.nombre} puede entrar otra vez');
  }

  Future<void> _editar(Usuario usuario) async {
    final resultado = await mostrarHojaInferior<ResultadoEdicionUsuario>(
      context,
      titulo: 'Editar usuario',
      builder: (_) => EditarUsuarioSheet(usuario: usuario),
    );
    if (!mounted || resultado == null) return;
    ref.invalidate(listaUsuariosProvider);
    switch (resultado) {
      case ResultadoEdicionUsuario.guardado:
        avisar(context, 'Usuario guardado');
      case ResultadoEdicionUsuario.cambiarPin:
        final editado = await ref
            .read(usuarioRepositoryProvider)
            .buscar(usuario.id);
        if (mounted) await _resetearPin(editado ?? usuario);
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
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Pildora(
                                key: Key('rol_${u.id}'),
                                texto: _etiquetaUsuario(u),
                                color: u.rol == 'admin'
                                    ? ColoresApp.of(context).primario
                                    : ColoresApp.of(context).marcaVerde,
                              ),
                              if (!u.activo)
                                Pildora(
                                  texto: 'Desactivado',
                                  color: ColoresApp.of(context).sale,
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (u.rol == 'vendedor' && u.activo) ...[
                              IconButton(
                                key: Key('conectar_celular_${u.id}'),
                                tooltip: 'Agregar su celular',
                                icon: const Icon(Icons.smartphone_rounded),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AgregarCelularScreen(vendedor: u),
                                  ),
                                ),
                              ),
                              IconButton(
                                key: Key('desactivar_${u.id}'),
                                tooltip: 'Desactivar',
                                icon: const Icon(Icons.person_off_rounded),
                                onPressed: () => _desactivar(u),
                              ),
                            ],
                            if (!u.activo)
                              TextButton(
                                key: Key('activar_${u.id}'),
                                onPressed: () => _activar(u),
                                child: const Text('Activar'),
                              ),
                            const Icon(
                              Icons.edit_outlined,
                              semanticLabel: 'Editar',
                            ),
                          ],
                        ),
                        onTap: () => _editar(u),
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

/// "Vendedor 3", "Super vendedor 3" o "Administrador".
String _etiquetaUsuario(Usuario u) {
  if (u.rol != 'vendedor') return etiquetaRol(u.rol);
  final base = u.manejaCatalogo ? 'Super vendedor' : 'Vendedor';
  return u.numeroVendedor == null ? base : '$base ${u.numeroVendedor}';
}
