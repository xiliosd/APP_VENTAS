import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sesion_provider.dart';
import 'home/home_screen.dart';
import 'login/crear_admin_inicial_screen.dart';
import 'login/seleccionar_usuario_screen.dart';

class RaizApp extends ConsumerWidget {
  const RaizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    if (sesion.haySesion) return const HomeScreen();

    final hayUsuariosAsync = ref.watch(haySesionUsuariosProvider);
    return hayUsuariosAsync.when(
      data: (existe) => existe
          ? const SeleccionarUsuarioScreen()
          : const CrearAdminInicialScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
