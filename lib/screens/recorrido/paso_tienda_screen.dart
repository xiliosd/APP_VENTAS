import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../providers/recorrido_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/configuracion_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../ui/tipografia.dart';
import '../../util/pin_hash.dart';
import 'indicador_pasos.dart';

class PasoTiendaScreen extends ConsumerStatefulWidget {
  const PasoTiendaScreen({super.key});

  @override
  ConsumerState<PasoTiendaScreen> createState() =>
      _PasoTiendaScreenState();
}

class _PasoTiendaScreenState
    extends ConsumerState<PasoTiendaScreen> {
  final _tiendaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _tiendaController.dispose();
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final tienda = _tiendaController.text;
    final errorTienda = errorNombreTienda(tienda);
    if (errorTienda != null) {
      setState(() => _error = errorTienda);
      return;
    }
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    if (!esPinValido(pin)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }

    await ref.read(configuracionRepositoryProvider).guardarNombreTienda(tienda);
    final repo = ref.read(usuarioRepositoryProvider);
    final id = await repo.crearUsuario(nombre: nombre, rol: 'admin', pin: pin);
    ref.invalidate(listaUsuariosProvider);
    ref.invalidate(haySesionUsuariosProvider);
    // Antes de entrar: así el Inicio, al montarse, abre el paso 2.
    await ref.read(recorridoProvider.notifier).iniciar();
    await ref.read(sesionProvider.notifier).iniciarSesion(id, pin);
    // Se abrió desde la Bienvenida: al entrar, quitarla de encima del Inicio.
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const IndicadorPasos(paso: 1),
            const SizedBox(height: 16),
            const MarcaApp(),
            const SizedBox(height: 32),
            Text('Configura tu tienda', style: estiloTitulo()),
            const SizedBox(height: 4),
            Text(
              'Crea el usuario administrador. Con él podrás agregar productos '
              'y vendedores.',
              style: TextStyle(color: ColoresApp.of(context).textoSecundario),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_nombre_tienda'),
              controller: _tiendaController,
              decoration:
                  const InputDecoration(labelText: 'Nombre de la tienda'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_nombre_admin'),
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_pin_admin'),
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: TextStyle(color: ColoresApp.of(context).sale)),
              ),
            const SizedBox(height: 8),
            BotonPrincipal(
              key: const Key('boton_crear_admin'),
              texto: 'Continuar',
              onPressed: _crear,
            ),
          ],
        ),
      ),
    );
  }
}
