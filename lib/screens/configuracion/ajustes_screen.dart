import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/colores_app.dart';
import '../qr/configurar_qr_screen.dart';
import '../respaldo/respaldo_screen.dart';
import 'hoja_nombre_tienda.dart';
import 'productos_screen.dart';
import 'proveedores_screen.dart';
import 'usuarios_screen.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Titulo('TIENDA'),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('menu_nombre_tienda'),
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Tienda'),
                subtitle: Text(
                    ref.watch(nombreTiendaProvider).valueOrNull ?? 'Sin nombre'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => mostrarHojaNombreTienda(context),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_productos'),
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Productos'),
                subtitle: const Text('Catálogo y precios'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductosScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_proveedores'),
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Proveedores'),
                subtitle: const Text('A quién le compras'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProveedoresScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_usuarios'),
                leading: const Icon(Icons.group_outlined),
                title: const Text('Usuarios'),
                subtitle: const Text('Administradores, vendedores y PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_cobro_qr'),
                leading: const Icon(Icons.qr_code_2_rounded),
                title: const Text('Cobro por QR'),
                subtitle: const Text('Tu QR de Nequi, Daviplata o banco'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConfigurarQrScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_respaldo'),
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Respaldo'),
                subtitle: const Text('Copia de seguridad en la nube'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RespaldoScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Titulo('CUENTA'),
        Card(
          child: ListTile(
            key: const Key('ajustes_cerrar_sesion'),
            leading: const Icon(Icons.logout_rounded, color: ColoresApp.sale),
            title: const Text('Cerrar sesión',
                style: TextStyle(color: ColoresApp.sale)),
            onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}
