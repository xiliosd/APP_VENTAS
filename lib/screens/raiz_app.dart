import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inicio_marca_provider.dart';
import '../providers/sesion_provider.dart';
import '../respaldo/respaldo_provider.dart';
import '../ui/movimiento.dart';
import 'home/home_screen.dart';
import 'inicio/inicio_marca_screen.dart';
import 'login/bienvenida_screen.dart';
import 'login/seleccionar_usuario_screen.dart';

class RaizApp extends ConsumerStatefulWidget {
  const RaizApp({super.key});

  @override
  ConsumerState<RaizApp> createState() => _RaizAppState();
}

class _RaizAppState extends ConsumerState<RaizApp> {
  /// Versión completa solo si nunca se vio; se decide una vez por arranque.
  late final bool _inicioCompleto;

  /// Ya se mostró una pantalla real: recargar la consulta (cerrar sesión,
  /// restaurar un respaldo) no vuelve al inicio.
  bool _yaMostrada = false;

  @override
  void initState() {
    super.initState();
    final preferencias = ref.read(preferenciasProvider);
    _inicioCompleto =
        !(preferencias.getBool(claveInicioCompletoVisto) ?? false);
    // Se marca al empezar: si la app se cierra a mitad, la próxima es breve.
    if (_inicioCompleto) preferencias.setBool(claveInicioCompletoVisto, true);
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el respaldo automático mientras la app está abierta,
    // sin reconstruir esta pantalla en cada cambio de su estado.
    ref.listen(respaldoProvider, (_, _) {});

    final pendiente = ref.watch(inicioMarcaPendienteProvider);
    final sesion = ref.watch(sesionProvider);
    final hayUsuariosAsync = ref.watch(haySesionUsuariosProvider);

    // El inicio sigue quieto en su final si la consulta aún no responde.
    final Widget pantalla;
    final esperando = !_yaMostrada && !hayUsuariosAsync.hasValue;
    if (pendiente || (esperando && !sesion.haySesion)) {
      pantalla = InicioMarcaScreen(
        key: const ValueKey('inicio_marca'),
        completa: _inicioCompleto,
        onTerminar: () =>
            ref.read(inicioMarcaPendienteProvider.notifier).state = false,
      );
    } else {
      _yaMostrada = true;
      pantalla = sesion.haySesion
          ? const HomeScreen()
          : hayUsuariosAsync.when(
              data: (existe) => existe
                  ? const SeleccionarUsuarioScreen()
                  : const BienvenidaScreen(),
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) =>
                  Scaffold(body: Center(child: Text('Error: $e'))),
            );
    }
    return AnimatedSwitcher(
      duration: Movimiento.duracion(context, Movimiento.media),
      child: pantalla,
    );
  }
}
