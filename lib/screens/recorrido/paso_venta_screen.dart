import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/recorrido_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../venta/registrar_venta_screen.dart';
import 'indicador_pasos.dart';

/// Paso 3 del recorrido: presenta la venta de práctica.
class PasoVentaScreen extends ConsumerWidget {
  const PasoVentaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresApp.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const IndicadorPasos(paso: 3),
              const Spacer(),
              Icon(Icons.point_of_sale_rounded, size: 72, color: c.primario),
              const SizedBox(height: 16),
              Text('Hagamos una venta de práctica',
                  textAlign: TextAlign.center, style: estiloTitulo()),
              const SizedBox(height: 8),
              Text(
                'Así aprendes a cobrar. No quedará en tus cuentas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textoSecundario),
              ),
              const Spacer(),
              BotonPrincipal(
                key: const Key('boton_empezar_practica'),
                texto: 'Empezar',
                variante: VarianteBoton.entra,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) =>
                          const RegistrarVentaScreen(practica: true)),
                ),
              ),
              TextButton(
                key: const Key('boton_omitir_practica'),
                onPressed: () {
                  final recorrido = ref.read(recorridoProvider.notifier);
                  Navigator.of(context).pop();
                  recorrido.irA(PasoRecorrido.inicio);
                },
                child: const Text('Omitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
