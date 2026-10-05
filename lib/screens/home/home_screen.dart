import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../configuracion/ajustes_screen.dart';
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

    final tabs = <_Pestana>[
      const _Pestana('Inicio', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded, ResumenScreen()),
      const _Pestana('Fiado', Icons.people_outline_rounded,
          Icons.people_rounded, ListaFiadoScreen()),
      const _Pestana('Historial', Icons.receipt_long_outlined,
          Icons.receipt_long_rounded, HistorialScreen()),
      if (sesion.esAdmin)
        const _Pestana('Ajustes', Icons.settings_outlined,
            Icons.settings_rounded, AjustesScreen()),
    ];
    if (_tabActual >= tabs.length) _tabActual = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabActual == 0
            ? 'Hola, ${usuario.nombre}'
            : tabs[_tabActual].titulo),
        actions: [_MenuCuenta(usuario: usuario), const SizedBox(width: 8)],
      ),
      body: tabs[_tabActual].pantalla,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (i) => setState(() => _tabActual = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icono),
              selectedIcon: Icon(t.iconoActivo),
              label: t.titulo,
            ),
        ],
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
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  key: const Key('boton_nuevo_gasto'),
                  heroTag: 'gasto',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RegistrarGastoScreen()),
                  ),
                  label: const Text('− Gasto'),
                ),
              ],
            )
          : null,
    );
  }
}

class _Pestana {
  const _Pestana(this.titulo, this.icono, this.iconoActivo, this.pantalla);

  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
}

class _MenuCuenta extends ConsumerWidget {
  const _MenuCuenta({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('menu_cuenta'),
      tooltip: 'Cuenta',
      icon: AvatarInicial(id: usuario.id, nombre: usuario.nombre, radio: 16),
      onSelected: (_) => ref.read(sesionProvider.notifier).cerrarSesion(),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          key: const Key('boton_cerrar_sesion'),
          value: 'salir',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded),
              const SizedBox(width: 12),
              Flexible(
                child: Text('Cerrar sesión (${usuario.nombre})',
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
