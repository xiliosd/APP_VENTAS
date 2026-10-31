import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inicio_marca_provider.dart';
import '../providers/sesion_provider.dart';
import '../respaldo/respaldo_provider.dart';
import '../ui/error_carga.dart';
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

  /// Se está mostrando el inicio de marca: solo su salida se funde; entrar a
  /// la sesión u otros cambios son inmediatos.
  bool _desdeInicio = false;

  @override
  void initState() {
    super.initState();
    final preferencias = ref.read(preferenciasProvider);
    _inicioCompleto =
        !(preferencias.getBool(claveInicioCompletoVisto) ?? false);
    // Se marca al empezar: si la app se cierra a mitad, la próxima es breve.
    if (_inicioCompleto) {
      // El valor en memoria cambia ya; no hace falta esperar al disco.
      unawaited(preferencias.setBool(claveInicioCompletoVisto, true));
    }
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
    var duracion = Duration.zero;
    var duracionSalida = Duration.zero;
    // Un error no se espera: se muestra, para no dejar la app quieta.
    final esperando =
        !_yaMostrada &&
        !hayUsuariosAsync.hasValue &&
        !hayUsuariosAsync.hasError;
    if (pendiente || (esperando && !sesion.haySesion)) {
      _desdeInicio = true;
      // El controlador del inicio se crea al agregarlo: su salida se fija aquí.
      duracionSalida = Movimiento.duracion(context, Movimiento.media);
      pantalla = InicioMarcaScreen(
        key: const ValueKey('inicio_marca'),
        completa: _inicioCompleto,
        onTerminar: () =>
            ref.read(inicioMarcaPendienteProvider.notifier).state = false,
      );
    } else {
      _yaMostrada = true;
      if (_desdeInicio) {
        duracion = Movimiento.duracion(context, Movimiento.media);
        _desdeInicio = false;
      }
      pantalla = sesion.haySesion
          ? const HomeScreen()
          : hayUsuariosAsync.when(
              data: (existe) => existe
                  ? const SeleccionarUsuarioScreen()
                  : const BienvenidaScreen(),
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Scaffold(body: ErrorCarga()),
            );
    }
    return AnimatedSwitcher(
      duration: duracion,
      reverseDuration: duracionSalida,
      child: pantalla,
    );
  }
}
