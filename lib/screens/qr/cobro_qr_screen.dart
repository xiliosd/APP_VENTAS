import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/monto.dart';
import '../../ui/tema_app.dart';
import 'configurar_qr_screen.dart';

/// Abre el cobro por QR de [monto]. true solo si el tendero tocó "Recibido".
Future<bool> abrirCobroQr(BuildContext context, {required int monto}) async {
  final recibido = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => CobroQrScreen(monto: monto)));
  return recibido == true;
}

class CobroQrScreen extends ConsumerStatefulWidget {
  const CobroQrScreen({super.key, required this.monto});

  final int monto;

  @override
  ConsumerState<CobroQrScreen> createState() => _CobroQrScreenState();
}

class _CobroQrScreenState extends ConsumerState<CobroQrScreen> {
  /// Evita que un doble toque cierre también la pantalla de abajo.
  bool _cerrando = false;

  void _cerrar(bool recibido) {
    if (_cerrando) return;
    _cerrando = true;
    Navigator.of(context).pop(recibido);
  }

  @override
  Widget build(BuildContext context) {
    final imagen = ref.watch(imagenQrProvider);
    final esAdmin = ref.watch(sesionProvider).esAdmin;

    // Siempre en claro: el código debe verse sobre blanco para escanearse.
    return Theme(
      data: temaClaro(),
      child: Scaffold(
        backgroundColor: ColoresApp.blancoMarca,
        appBar: AppBar(
          title: const Text('Cobro por QR'),
          backgroundColor: ColoresApp.blancoMarca,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Monto(widget.monto, tamano: 44)),
                const SizedBox(height: 4),
                Text(
                  'Pide al cliente que escanee y digite este valor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // Este context está fuera del Theme claro de la pantalla.
                    color: ColoresApp.claro.textoSecundario,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: imagen.when(
                    data: (bytes) => bytes == null
                        ? _SinQr(esAdmin: esAdmin)
                        : _ImagenQr(bytes),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const _QrIlegible(),
                  ),
                ),
                const SizedBox(height: 16),
                BotonPrincipal(
                  key: const Key('boton_qr_recibido'),
                  texto: 'Recibido',
                  variante: VarianteBoton.entra,
                  onPressed: () => _cerrar(true),
                ),
                const SizedBox(height: 8),
                BotonPrincipal(
                  key: const Key('boton_qr_cancelar'),
                  texto: 'Cancelar',
                  variante: VarianteBoton.contorno,
                  onPressed: () => _cerrar(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagenQr extends StatelessWidget {
  const _ImagenQr(this.bytes);

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.memory(
        bytes,
        key: const Key('imagen_qr'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _QrIlegible(),
      ),
    );
  }
}

class _QrIlegible extends StatelessWidget {
  const _QrIlegible();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No se pudo mostrar el QR',
        textAlign: TextAlign.center,
        style: TextStyle(color: ColoresApp.of(context).textoSecundario),
      ),
    );
  }
}

class _SinQr extends StatelessWidget {
  const _SinQr({required this.esAdmin});

  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 64,
              color: ColoresApp.of(context).textoSecundario,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aún no has cargado tu QR',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (esAdmin) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('boton_configurar_qr'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConfigurarQrScreen()),
                ),
                child: const Text('Configurar QR'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
