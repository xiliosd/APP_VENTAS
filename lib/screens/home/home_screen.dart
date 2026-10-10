import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/configuracion_providers.dart';
import '../../providers/recorrido_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/recorrido/globos.dart';
import '../../ui/recorrido/objetivo_recorrido.dart';
import '../../ui/tipografia.dart';
import '../../ui/vibracion.dart';
import '../../widgets/nombre_tienda.dart';
import '../configuracion/ajustes_screen.dart';
import '../configuracion/hoja_nombre_tienda.dart';
import '../fiado/lista_fiado_screen.dart';
import '../historial/historial_screen.dart';
import '../inventario/inventario_screen.dart';
import '../recorrido/globos_inicio.dart';
import '../recorrido/paso_productos_screen.dart';
import '../recorrido/paso_venta_screen.dart';
import 'hoja_apariencia.dart';
import 'resumen_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabActual = 0;
  bool _pidioNombre = false;
  bool _atendioAlMontar = false;
  ControladorGlobos? _globos;

  @override
  void dispose() {
    _globos?.cerrar();
    super.dispose();
  }

  /// Abre el paso pendiente del recorrido (solo administrador).
  void _atender(PasoRecorrido paso) {
    if (!mounted || !ref.read(sesionProvider).esAdmin) return;
    final navegador = Navigator.of(context);
    switch (paso) {
      case PasoRecorrido.productos:
        navegador.push(
            MaterialPageRoute(builder: (_) => const PasoProductosScreen()));
      case PasoRecorrido.venta:
        navegador.push(
            MaterialPageRoute(builder: (_) => const PasoVentaScreen()));
      case PasoRecorrido.inicio:
        if (_globos?.activo ?? false) return;
        setState(() => _tabActual = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _globos = mostrarGlobos(context, globosInicio,
              onTerminar: _terminarRecorrido,
              onSaltar: () => ref.read(recorridoProvider.notifier).saltar());
        });
      case PasoRecorrido.ninguno:
      case PasoRecorrido.hecho:
        break;
    }
  }

  Future<void> _terminarRecorrido() async {
    await ref.read(recorridoProvider.notifier).irA(PasoRecorrido.hecho);
    if (!mounted) return;
    await mostrarHojaInferior<void>(
      context,
      titulo: '¡Listo! Tu tienda está lista',
      builder: (contexto) => Column(
        key: const Key('hoja_listo'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ya puedes vender, fiar y ver cómo va tu tienda.'),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_empezar_a_vender'),
            texto: 'Empezar a vender',
            variante: VarianteBoton.entra,
            onPressed: () => Navigator.of(contexto).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    if (!sesion.haySesion) return const SizedBox.shrink();
    final usuario = sesion.usuarioActivo!;

    // El Inicio dirige el recorrido: reacciona solo si está a la vista (las
    // pantallas de pasos que van encima navegan por su cuenta).
    ref.listen<PasoRecorrido>(recorridoProvider, (_, paso) {
      if (ModalRoute.of(context)?.isCurrent ?? true) _atender(paso);
    });
    if (!_atendioAlMontar) {
      _atendioAlMontar = true;
      final paso = ref.read(recorridoProvider);
      if (paso.enCurso) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _atender(paso));
      }
    }

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
        backgroundColor:
            esInicio ? ColoresApp.of(context).tarjetaPrincipal : null,
        foregroundColor:
            esInicio ? ColoresApp.of(context).sobreTarjetaPrincipal : null,
        titleTextStyle:
            esInicio ? estiloTitulo(
                tamano: 20, color: ColoresApp.of(context).sobreTarjetaPrincipal) : null,
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
                        NombreTienda(
                          estilo: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: ColoresApp.of(context)
                                  .sobreTarjetaPrincipal
                                  .withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Text(tabs[_tabActual].titulo),
        actions: [
          ObjetivoRecorrido(
            id: 'menu_cuenta',
            child: _MenuCuenta(usuario: usuario, enBarraAzul: esInicio),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tabs[_tabActual].pantalla,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (i) {
          Vibracion.toque();
          setState(() => _tabActual = i);
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.titulo == 'Fiado'
                  ? ObjetivoRecorrido(
                      id: 'pestana_fiado', child: Icon(t.icono))
                  : Icon(t.icono),
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
        colorAnillo: enBarraAzul
            ? ColoresApp.of(context).sobreTarjetaPrincipal
            : null,
      ),
      onSelected: (valor) {
        if (valor == 'apariencia') {
          mostrarHojaApariencia(context);
        } else {
          ref.read(sesionProvider.notifier).cerrarSesion();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          key: Key('boton_apariencia'),
          value: 'apariencia',
          child: Row(
            children: [
              Icon(Icons.dark_mode_outlined),
              SizedBox(width: 12),
              Text('Apariencia'),
            ],
          ),
        ),
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
        color: ColoresApp.blancoMarca,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset('assets/marca/isotipo.png',
          semanticLabel: 'VeciTienda'),
    );
  }
}
