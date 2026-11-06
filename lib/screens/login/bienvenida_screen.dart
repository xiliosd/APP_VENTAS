import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/respaldo_provider.dart';
import '../../sincronizacion/supabase_nube_tienda.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../ui/tipografia.dart';
import '../respaldo/verificar_correo_screen.dart';
import '../recorrido/paso_tienda_screen.dart';
import '../vendedor/unirse_tienda_screen.dart';

/// Primera pantalla cuando el celular no tiene usuarios: crear la tienda o
/// restaurar un respaldo.
class BienvenidaScreen extends ConsumerWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayRespaldo =
        ref.watch(respaldoProvider).fase != FaseRespaldo.noConfigurado;
    final hayNube = ref.watch(nubeTiendaProvider) != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MarcaApp(conSlogan: true),
            const SizedBox(height: 32),
            Text('Bienvenido', style: estiloTitulo()),
            const SizedBox(height: 4),
            Text(
              'Registra ventas, fiados y gastos de tu tienda, incluso sin '
              'internet.',
              style: TextStyle(color: ColoresApp.of(context).textoSecundario),
            ),
            const SizedBox(height: 32),
            BotonPrincipal(
              key: const Key('boton_crear_tienda'),
              texto: 'Crear tienda nueva',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PasoTiendaScreen()),
              ),
            ),
            if (hayRespaldo) ...[
              const SizedBox(height: 12),
              BotonPrincipal(
                key: const Key('boton_restaurar_tienda'),
                texto: 'Ya tengo una tienda: restaurar respaldo',
                variante: VarianteBoton.contorno,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VerificarCorreoScreen(
                      modo: ModoVerificacion.restaurar,
                    ),
                  ),
                ),
              ),
            ],
            if (hayNube) ...[
              const SizedBox(height: 12),
              BotonPrincipal(
                key: const Key('boton_unirse_tienda'),
                texto: 'Unirme a una tienda (soy vendedor)',
                variante: VarianteBoton.contorno,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UnirseTiendaScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
