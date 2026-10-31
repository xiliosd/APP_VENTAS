import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/configuracion_providers.dart';
import '../../providers/huella_provider.dart';
import '../../providers/recorrido_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../servicios/autenticacion_huella.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/tema_app.dart';
import '../../ui/titulo_seccion.dart';
import '../ayuda/preguntas_frecuentes_screen.dart';
import '../qr/configurar_qr_screen.dart';
import '../respaldo/respaldo_screen.dart';
import '../clientes/clientes_screen.dart';
import 'hoja_nombre_tienda.dart';
import 'productos_screen.dart';
import 'proveedores_screen.dart';
import 'usuarios_screen.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresApp.of(context);
    final nombre = ref.watch(nombreTiendaProvider).valueOrNull;
    final usuario = ref.watch(sesionProvider).usuarioActivo;
    final respaldoActivo =
        ref.watch(respaldoProvider).fase == FaseRespaldo.activo;
    final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);

    void abrir(Widget pantalla) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pantalla));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EntradaEscalonada(
          indice: 0,
          child: Material(
            key: const Key('cabecera_ajustes'),
            color: c.tarjetaPrincipal,
            borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
            child: InkWell(
              key: const Key('menu_nombre_tienda'),
              borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
              onTap: () => mostrarHojaNombreTienda(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarInicial(
                      id: 0,
                      nombre: nombre ?? '?',
                      radio: 28,
                      colorAnillo: c.sobreTarjetaPrincipal,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre ?? 'Sin nombre',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: c.sobreTarjetaPrincipal,
                            ),
                          ),
                          if (usuario != null)
                            Text(
                              '${usuario.nombre} · ${etiquetaRol(usuario.rol)}',
                              style: TextStyle(fontSize: 13, color: suave),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: c.sobreTarjetaPrincipal),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 1,
          child: _Grupo(titulo: 'TIENDA', opciones: [
            _Opcion(
              key: const Key('menu_productos'),
              icono: Icons.inventory_2_outlined,
              color: c.primario,
              titulo: 'Productos',
              subtitulo: 'Catálogo y precios',
              onTap: () => abrir(const ProductosScreen()),
            ),
            _Opcion(
              key: const Key('menu_proveedores'),
              icono: Icons.local_shipping_outlined,
              color: c.fiado,
              titulo: 'Proveedores',
              subtitulo: 'A quién le compras',
              onTap: () => abrir(const ProveedoresScreen()),
            ),
            _Opcion(
              key: const Key('menu_clientes'),
              icono: Icons.people_outline_rounded,
              color: c.entra,
              titulo: 'Clientes',
              subtitulo: 'Datos y compras de tus clientes',
              onTap: () => abrir(const ClientesScreen()),
            ),
            _Opcion(
              key: const Key('menu_usuarios'),
              icono: Icons.group_outlined,
              color: c.marcaVerde,
              titulo: 'Usuarios',
              subtitulo: 'Administradores, vendedores y PIN',
              onTap: () => abrir(const UsuariosScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 2,
          child: _Grupo(titulo: 'COBROS Y DATOS', opciones: [
            _Opcion(
              key: const Key('menu_cobro_qr'),
              icono: Icons.qr_code_2_rounded,
              color: c.entra,
              titulo: 'Cobro por QR',
              subtitulo: 'Tu QR de Nequi, Daviplata o banco',
              onTap: () => abrir(const ConfigurarQrScreen()),
            ),
            _Opcion(
              key: const Key('menu_respaldo'),
              icono: Icons.cloud_upload_outlined,
              color: c.primario,
              titulo: 'Respaldo',
              subtitulo: 'Copia de seguridad en la nube',
              estado: respaldoActivo
                  ? Row(
                      key: const Key('estado_respaldo_menu'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: c.entra, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text('Activo',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : null,
              onTap: () => abrir(const RespaldoScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 3,
          child: _Grupo(titulo: 'AYUDA', opciones: [
            _Opcion(
              key: const Key('boton_repetir_recorrido'),
              icono: Icons.tour_outlined,
              color: c.primario,
              titulo: 'Ver el recorrido otra vez',
              subtitulo: 'Venta de práctica y guía del Inicio',
              // El Inicio, que está a la vista, abre el paso 3.
              onTap: () => ref
                  .read(recorridoProvider.notifier)
                  .irA(PasoRecorrido.venta),
            ),
            _Opcion(
              key: const Key('boton_preguntas_frecuentes'),
              icono: Icons.help_outline_rounded,
              color: c.primario,
              titulo: 'Preguntas frecuentes',
              subtitulo: 'Cómo hacer cada cosa en la app',
              onTap: () => abrir(const PreguntasFrecuentesScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 4,
          child: _Grupo(titulo: 'CUENTA', opciones: [
            if (ref.watch(huellaDisponibleProvider).valueOrNull ?? false)
              const _FilaHuella(),
            ListTile(
              key: const Key('ajustes_cerrar_sesion'),
              leading: IconoCuadrado(icono: Icons.logout_rounded, color: c.sale),
              title: Text('Cerrar sesión', style: TextStyle(color: c.sale)),
              onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.opciones});

  final String titulo;
  final List<Widget> opciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(titulo),
        Card(
          child: Column(
            children: [
              for (final (i, o) in opciones.indexed) ...[
                if (i > 0) const Divider(height: 1),
                o,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.estado,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final Widget? estado;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconoCuadrado(icono: icono, color: color),
      title: Text(titulo),
      subtitle: Text(subtitulo),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?estado,
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Activa o desactiva la huella del usuario con sesión, en este celular.
class _FilaHuella extends ConsumerWidget {
  const _FilaHuella();

  Future<void> _activar(BuildContext context, WidgetRef ref, Usuario yo) async {
    final acepta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Entrar con huella?'),
        content: const Text(
          // El rostro también cuenta como biometría en muchos celulares.
          'Cualquier huella o rostro registrado en este celular podrá abrir '
          'tu usuario. Actívalo solo si el celular es tuyo.',
        ),
        actions: [
          TextButton(
            key: const Key('cancelar_huella'),
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('activar_huella'),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (acepta != true) return;
    // Solo se activa si quien está aquí confirma con su huella.
    final resultado = await ref
        .read(autenticacionHuellaProvider)
        .confirmar('Confirma que eres ${yo.nombre}');
    if (resultado != ResultadoHuella.aprobada) return;
    await ref.read(usuariosConHuellaProvider.notifier).activar(yo.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = ref.watch(sesionProvider).usuarioActivo;
    if (yo == null) return const SizedBox.shrink();
    final activa = ref.watch(usuariosConHuellaProvider).contains(yo.id);
    final c = ColoresApp.of(context);
    return SwitchListTile(
      key: const Key('interruptor_huella'),
      secondary: IconoCuadrado(icono: Icons.fingerprint_rounded, color: c.primario),
      title: const Text('Entrar con huella'),
      subtitle: const Text('Sin escribir el PIN, en este celular'),
      value: activa,
      onChanged: (encender) => encender
          ? _activar(context, ref, yo)
          : ref.read(usuariosConHuellaProvider.notifier).desactivar(yo.id),
    );
  }
}
