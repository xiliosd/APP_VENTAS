import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sesion_provider.dart';
import '../respaldo/respaldo_provider.dart';
import 'home/home_screen.dart';
import 'login/bienvenida_screen.dart';
import 'login/seleccionar_usuario_screen.dart';

class RaizApp extends ConsumerWidget {
  const RaizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el respaldo automático mientras la app está abierta,
    // sin reconstruir esta pantalla en cada cambio de su estado.
    ref.listen(respaldoProvider, (_, _) {});

    final sesion = ref.watch(sesionProvider);
    if (sesion.haySesion) return const HomeScreen();

    final hayUsuariosAsync = ref.watch(haySesionUsuariosProvider);
    return hayUsuariosAsync.when(
      data: (existe) =>
          existe ? const SeleccionarUsuarioScreen() : const BienvenidaScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
