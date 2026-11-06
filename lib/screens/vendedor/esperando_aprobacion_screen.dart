import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../ui/tipografia.dart';

/// El celular del vendedor pidió entrar y espera que el administrador lo
/// apruebe. Pregunta cada pocos segundos y al volver a la app; si la app se
/// cierra, la raíz vuelve a mostrar esta pantalla al abrir.
class EsperandoAprobacionScreen extends ConsumerStatefulWidget {
  const EsperandoAprobacionScreen({super.key});

  @override
  ConsumerState<EsperandoAprobacionScreen> createState() =>
      _EsperandoAprobacionScreenState();
}

class _EsperandoAprobacionScreenState
    extends ConsumerState<EsperandoAprobacionScreen> {
  Timer? _sondeo;
  AppLifecycleListener? _ciclo;
  bool _revisando = false;

  @override
  void initState() {
    super.initState();
    _sondeo = Timer.periodic(
      ref.read(intervaloSolicitudProvider),
      (_) => unawaited(_revisar()),
    );
    _ciclo = AppLifecycleListener(onResume: () => unawaited(_revisar()));
    Future.microtask(_revisar);
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _ciclo?.dispose();
    super.dispose();
  }

  Future<void> _revisar() async {
    if (_revisando || !mounted) return;
    _revisando = true;
    // Al aprobar o rechazar, esta pantalla se va: el aviso se da desde antes.
    final avisos = ScaffoldMessenger.of(context);
    try {
      final estado = await ref
          .read(sincronizacionProvider.notifier)
          .revisarSolicitud();
      final mensaje = switch (estado) {
        EstadoMiembro.aprobado => '¡Listo! Ya puedes vender en este celular.',
        EstadoMiembro.rechazado => 'El administrador no aprobó este celular.',
        _ => null,
      };
      if (mensaje != null) {
        avisos.showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (_) {
      // Sin internet o falla del servidor: se vuelve a preguntar luego.
    } finally {
      _revisando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MarcaApp(),
            const SizedBox(height: 32),
            Text('Esperando aprobación', style: estiloTitulo()),
            const SizedBox(height: 8),
            Text(
              'Pídele al administrador que apruebe este celular en su app.',
              style: TextStyle(color: ColoresApp.of(context).textoSecundario),
            ),
            const SizedBox(height: 32),
            Center(
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: ColoresApp.of(context).primario,
                semanticLabel: 'Esperando',
              ),
            ),
            const SizedBox(height: 32),
            BotonPrincipal(
              key: const Key('boton_cancelar_solicitud'),
              texto: 'Cancelar',
              variante: VarianteBoton.contorno,
              onPressed: () =>
                  ref.read(sincronizacionProvider.notifier).cancelarSolicitud(),
            ),
          ],
        ),
      ),
    );
  }
}
