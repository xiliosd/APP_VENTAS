import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import 'selector_imagen.dart';

class ConfigurarQrScreen extends ConsumerStatefulWidget {
  const ConfigurarQrScreen({super.key});

  @override
  ConsumerState<ConfigurarQrScreen> createState() =>
      _ConfigurarQrScreenState();
}

class _ConfigurarQrScreenState extends ConsumerState<ConfigurarQrScreen> {
  bool _ocupado = false;

  Future<void> _cargar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await ref.read(selectorImagenProvider).elegir();
      if (bytes == null) return;
      await ref.read(configuracionRepositoryProvider).guardarImagenQr(bytes);
      if (mounted) avisar(context, 'QR guardado');
    } catch (_) {
      if (mounted) {
        avisar(context, 'No se pudo cargar la imagen, prueba con otra');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _quitar() async {
    await ref.read(configuracionRepositoryProvider).quitarImagenQr();
    if (mounted) avisar(context, 'QR quitado');
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ref.watch(imagenQrProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobro por QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Descarga tu QR desde la app de Nequi, Daviplata o tu banco y '
            'cárgalo aquí.',
            style: TextStyle(color: ColoresApp.textoSecundario),
          ),
          const SizedBox(height: 16),
          if (bytes == null)
            const EstadoVacio(
              icono: Icons.qr_code_2_rounded,
              titulo: 'Aún no has cargado tu QR',
            )
          else
            SizedBox(
              key: const Key('vista_qr'),
              height: 280,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text('No se pudo mostrar el QR'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_cargar_qr'),
            texto: bytes == null ? 'Cargar QR' : 'Cambiar QR',
            onPressed: _ocupado ? null : _cargar,
          ),
          if (bytes != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('boton_quitar_qr'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
              onPressed: _quitar,
              child: const Text('Quitar QR'),
            ),
          ],
        ],
      ),
    );
  }
}
