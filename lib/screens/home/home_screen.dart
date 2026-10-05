import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../configuracion/productos_screen.dart';
import '../configuracion/usuarios_screen.dart';
import '../fiado/lista_fiado_screen.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../historial/historial_screen.dart';
import '../venta/registrar_venta_screen.dart';
import 'resumen_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabActual = 0;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    if (!sesion.haySesion) return const SizedBox.shrink();
    final usuario = sesion.usuarioActivo!;

    final tabs = <_TabInfo>[
      const _TabInfo('Resumen', Icons.dashboard, ResumenScreen()),
      const _TabInfo('Fiado', Icons.people, ListaFiadoScreen()),
      const _TabInfo('Historial', Icons.history, HistorialScreen()),
      if (sesion.esAdmin)
        const _TabInfo('Config', Icons.settings, _ConfiguracionMenu()),
    ];

    if (_tabActual >= tabs.length) _tabActual = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${usuario.nombre}'),
        actions: [
          IconButton(
            key: const Key('boton_cerrar_sesion'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
      body: tabs[_tabActual].pantalla,
      bottomNavigationBar: BottomNavigationBar(
        // Con 4 pestañas el tipo por defecto es "shifting", que deja los
        // íconos casi blancos sobre la barra clara (invisibles).
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabActual,
        onTap: (index) => setState(() => _tabActual = index),
        items: tabs
            .map((t) =>
                BottomNavigationBarItem(icon: Icon(t.icono), label: t.titulo))
            .toList(),
      ),
      floatingActionButton: _tabActual == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  key: const Key('boton_nueva_venta'),
                  heroTag: 'venta',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RegistrarVentaScreen()),
                  ),
                  label: const Text('+ Venta'),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  key: const Key('boton_nuevo_gasto'),
                  heroTag: 'gasto',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RegistrarGastoScreen()),
                  ),
                  label: const Text('+ Gasto'),
                  icon: const Icon(Icons.remove_shopping_cart),
                ),
              ],
            )
          : null,
    );
  }
}

class _TabInfo {
  const _TabInfo(this.titulo, this.icono, this.pantalla);

  final String titulo;
  final IconData icono;
  final Widget pantalla;
}

class _ConfiguracionMenu extends StatelessWidget {
  const _ConfiguracionMenu();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          key: const Key('menu_productos'),
          title: const Text('Productos'),
          leading: const Icon(Icons.inventory),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductosScreen()),
          ),
        ),
        ListTile(
          key: const Key('menu_usuarios'),
          title: const Text('Usuarios'),
          leading: const Icon(Icons.group),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsuariosScreen()),
          ),
        ),
      ],
    );
  }
}
