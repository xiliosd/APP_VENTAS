import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../servicios/lector_codigo.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/vibracion.dart';

/// Diálogo para escribir el código cuando la cámara no lo lee. Devuelve el
/// código recortado, o null si se canceló o quedó vacío.
Future<String?> pedirCodigoEscrito(BuildContext context) async {
  final codigo = await showDialog<String>(
    context: context,
    builder: (_) => const _DialogoCodigo(),
  );
  final limpio = codigo?.trim();
  return limpio == null || limpio.isEmpty ? null : limpio;
}

/// Dueño de su controlador: se libera cuando el diálogo termina de cerrarse.
class _DialogoCodigo extends StatefulWidget {
  const _DialogoCodigo();

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escribir código'),
      content: TextField(
        key: const Key('campo_codigo_escrito'),
        controller: _controlador,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Código de barras'),
        onSubmitted: (t) => Navigator.pop(context, t),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_usar_codigo'),
          onPressed: () => Navigator.pop(context, _controlador.text),
          child: const Text('Usar'),
        ),
      ],
    );
  }
}

/// Cámara a pantalla completa que se cierra con el primer código leído.
class EscanerScreen extends StatefulWidget {
  const EscanerScreen({super.key, this.uso = UsoEscaner.venta});

  final UsoEscaner uso;

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  final _controlador = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  bool _leido = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    final codigo = captura.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .firstOrNull;
    if (codigo == null) return;
    _leido = true;
    Vibracion.exito();
    Navigator.of(context).pop(codigo);
  }

  Future<void> _escribir() async {
    final codigo = await pedirCodigoEscrito(context);
    if (codigo != null && mounted) Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Scaffold(
      backgroundColor: c.velo,
      appBar: AppBar(
        title: const Text('Escanear'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controlador.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controlador,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No podemos usar la cámara',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.blancoMarca, fontSize: 18),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: ColoresApp.blancoMarca, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: PieEscaner(
                uso: widget.uso,
                onEscribir: _escribir,
                onSeguirSinCamara: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parte baja del escáner: instrucción, qué hará la app con el código y las
/// salidas sin cámara. Separada para poder probarla sin abrir la cámara.
class PieEscaner extends StatelessWidget {
  const PieEscaner({
    super.key,
    required this.uso,
    required this.onEscribir,
    required this.onSeguirSinCamara,
  });

  final UsoEscaner uso;
  final VoidCallback onEscribir;
  final VoidCallback onSeguirSinCamara;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Apunta al código de barras',
          textAlign: TextAlign.center,
          style: TextStyle(color: ColoresApp.blancoMarca, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          uso.ayuda,
          textAlign: TextAlign.center,
          style: TextStyle(color: ColoresApp.blancoMarca, fontSize: 14),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_escribir_codigo'),
          texto: 'Escribir código',
          icono: Icons.keyboard_rounded,
          onPressed: onEscribir,
        ),
        if (uso.conSeguirSinCamara)
          TextButton(
            key: const Key('boton_seguir_sin_camara'),
            style: TextButton.styleFrom(
              foregroundColor: ColoresApp.blancoMarca,
              minimumSize: const Size(48, 48),
            ),
            onPressed: onSeguirSinCamara,
            child: const Text('Seguir sin cámara'),
          ),
      ],
    );
  }
}
