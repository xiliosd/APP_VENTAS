import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../util/pin_hash.dart';

/// El vendedor escribe el código de la tienda, su número y su PIN para pedir
/// entrar desde su propio celular. El administrador lo aprueba en el suyo.
class UnirseTiendaScreen extends ConsumerStatefulWidget {
  const UnirseTiendaScreen({super.key});

  @override
  ConsumerState<UnirseTiendaScreen> createState() => _UnirseTiendaScreenState();
}

class _UnirseTiendaScreenState extends ConsumerState<UnirseTiendaScreen> {
  final _codigoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pinController = TextEditingController();
  String? _errorCodigo;
  String? _errorNumero;
  String? _errorPin;
  String? _error;
  bool _enviando = false;

  static final _formatoCodigo = RegExp(r'^[A-Z0-9]{6}$');

  @override
  void dispose() {
    _codigoController.dispose();
    _numeroController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pedirEntrada() async {
    if (_enviando) return;
    final codigo = _codigoController.text.trim().toUpperCase();
    final numero = int.tryParse(_numeroController.text.trim());
    final pin = _pinController.text.trim();
    setState(() {
      _error = null;
      _errorCodigo = _formatoCodigo.hasMatch(codigo)
          ? null
          : 'Escribe el código de 6 letras y números';
      _errorNumero = numero == null || numero < 1
          ? 'Escribe tu número de vendedor'
          : null;
      _errorPin = esPinValido(pin) ? null : 'El PIN debe tener 4 dígitos';
    });
    if (_errorCodigo != null || _errorNumero != null || _errorPin != null) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final respuesta = await ref
          .read(sincronizacionProvider.notifier)
          .unirse(codigo: codigo, numeroVendedor: numero!, pin: pin);
      if (!mounted) return;
      if (respuesta.resultado == ResultadoPin.ok) {
        // La raíz ya muestra "Esperando aprobación" debajo de esta pantalla.
        Navigator.of(context).pop();
        return;
      }
      setState(
        () => _error = respuesta.resultado == ResultadoPin.bloqueado
            ? 'Demasiados intentos. Espera 15 minutos.'
            : 'Código, número o PIN incorrectos.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = mensajeErrorTienda(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a una tienda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'El administrador te da el código de la tienda y tu número de '
              'vendedor.',
              style: TextStyle(color: colores.textoSecundario),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_codigo_tienda'),
              controller: _codigoController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                TextInputFormatter.withFunction(
                  (_, nuevo) => nuevo.copyWith(text: nuevo.text.toUpperCase()),
                ),
              ],
              decoration: InputDecoration(
                labelText: 'Código de la tienda',
                errorText: _errorCodigo,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo_numero_vendedor'),
              controller: _numeroController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              decoration: InputDecoration(
                labelText: 'Tu número de vendedor',
                errorText: _errorNumero,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo_pin_vendedor'),
              controller: _pinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Tu PIN de 4 dígitos',
                errorText: _errorPin,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('error_unirse_tienda'),
                style: TextStyle(color: colores.sale),
              ),
            ],
            const SizedBox(height: 16),
            BotonPrincipal(
              key: const Key('boton_pedir_entrada'),
              texto: 'Pedir entrada',
              onPressed: _enviando ? null : _pedirEntrada,
            ),
          ],
        ),
      ),
    );
  }
}
