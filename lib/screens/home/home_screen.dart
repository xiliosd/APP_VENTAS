import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/configuracion_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../../widgets/nombre_tienda.dart';
import '../configuracion/ajustes_screen.dart';
import '../configuracion/hoja_nombre_tienda.dart';
import '../fiado/lista_fiado_screen.dart';
import '../historial/historial_screen.dart';
import '../inventario/inventario_screen.dart';
import 'resumen_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabActual = 0;
  bool _pidioNombre = false;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    if (!sesion.haySesion) return const SizedBox.shrink();
    final usuario = sesion.usuarioActivo!;

    // Un administrador sin nombre de tienda debe ponerlo una vez.
    final nombreTienda = ref.watch(nombreTiendaProvider);
    if (!_pidioNombre &&
        sesion.esAdmin &&
        nombreTienda.hasValue &&
        nombreTienda.value == null) {
      _pidioNombre = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarHojaNombreTienda(context, obligatoria: true);
      });
    }

    final tabs = <_Pestana>[
      _Pestana('Inicio', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          ResumenScreen(onVerFiado: () => setState(() => _tabActual = 1))),
      const _Pestana('Fiado', Icons.people_outline_rounded,
          Icons.people_rounded, ListaFiadoScreen()),
      const _Pestana('Inventario', Icons.inventory_2_outlined,
          Icons.inventory_2_rounded, InventarioScreen()),
      const _Pestana('Historial', Icons.receipt_long_outlined,
          Icons.receipt_long_rounded, HistorialScreen()),
      if (sesion.esAdmin)
        const _Pestana('Ajustes', Icons.settings_outlined,
            Icons.settings_rounded, AjustesScreen()),
    ];
    if (_tabActual >= tabs.length) _tabActual = 0;

    final esInicio = _tabActual == 0;
    final escala = MediaQuery.textScalerOf(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: esInicio
            ? math.max(
                kToolbarHeight,
                escala.scale(20) * 1.3 + escala.scale(12) * 1.3 + 16,
              )
            : null,
        // Sin la línea gris del tema bajo el azul.
        shape: esInicio ? const Border() : null,
        // Header de marca solo en Inicio; las demás pestañas, barra blanca.
        backgroundColor: esInicio ? ColoresApp.primario : null,
        foregroundColor: esInicio ? Colors.white : null,
        titleTextStyle:
            esInicio ? estiloTitulo(tamano: 20, color: Colors.white) : null,
        title: esInicio
            ? Row(
                children: [
                  const _InsigniaMarca(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${usuario.nombre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const NombreTienda(
                          estilo: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Text(tabs[_tabActual].titulo),
        actions: [
          _MenuCuenta(usuario: usuario, enBarraAzul: esInicio),
          const SizedBox(width: 8),
        ],
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
  const _MenuCuenta({required this.usuario, this.enBarraAzul = false});

  final Usuario usuario;
  final bool enBarraAzul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('menu_cuenta'),
      tooltip: 'Cuenta',
      icon: AvatarInicial(
        id: usuario.id,
        nombre: usuario.nombre,
        radio: 16,
        colorAnillo: enBarraAzul ? Colors.white : null,
      ),
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

/// Isotipo sobre una insignia blanca, para el header azul del Inicio.
class _InsigniaMarca extends StatelessWidget {
  const _InsigniaMarca();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('insignia_marca'),
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset('assets/marca/isotipo.png',
          semanticLabel: 'VeciTienda'),
    );
  }
}
