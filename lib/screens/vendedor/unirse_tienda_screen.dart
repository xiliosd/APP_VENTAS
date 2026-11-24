import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../servicios/lector_codigo.dart';
import '../../ui/colores_app.dart';
import '../../util/codigo_unirse.dart';
import '../../util/pin_hash.dart';

/// El vendedor escanea el QR del dueño (o escribe el código y su número) y
/// escribe su PIN para pedir entrar desde su propio celular. El administrador
/// lo aprueba en el suyo. El PIN nunca viaja en el QR.
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
  final _foroPin = FocusNode();
  bool _enviando = false;
  bool _escribirAMano = false;
  DatosUnirse? _escaneado;
  String? _errorEscaneo;

  static final _formatoCodigo = RegExp(r'^[A-Z0-9]{6}$');

  @override
  void dispose() {
    _codigoController.dispose();
    _numeroController.dispose();
    _pinController.dispose();
    _foroPin.dispose();
    super.dispose();
  }

  Future<void> _escanear() async {
    final texto = await ref
        .read(lectorCodigoProvider)
        .leer(context, uso: UsoEscaner.unirse);
    if (!mounted || texto == null) return;
    final datos = leerCodigoUnirse(texto);
    setState(() {
      _escaneado = datos;
      _errorEscaneo = datos == null
          ? 'Ese código no es de una tienda VeciTienda'
          : null;
      if (datos != null) _escribirAMano = false;
    });
    if (datos != null) _foroPin.requestFocus();
  }

  Future<void> _pedirEntrada() async {
    if (_enviando) return;
    final escaneado = _escaneado;
    final codigo =
        escaneado?.codigo ?? _codigoController.text.trim().toUpperCase();
    final numero =
        escaneado?.numero ?? int.tryParse(_numeroController.text.trim());
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
              'Escanea el código que te muestra el administrador en su '
              'celular y escribe tu PIN.',
              style: TextStyle(color: colores.textoSecundario),
            ),
            const SizedBox(height: 16),
            BotonPrincipal(
              key: const Key('boton_escanear_dueno'),
              texto: 'Escanear el código del dueño',
              icono: Icons.qr_code_scanner_rounded,
              onPressed: _enviando ? null : _escanear,
            ),
            if (_errorEscaneo != null) ...[
              const SizedBox(height: 8),
              Text(_errorEscaneo!, style: TextStyle(color: colores.sale)),
            ],
            if (_escaneado != null) ...[
              const SizedBox(height: 16),
              Card(
                key: const Key('tienda_encontrada'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tienda encontrada · Eres el vendedor '
                    'N.º ${_escaneado!.numero}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (_escaneado == null && !_escribirAMano)
              TextButton(
                key: const Key('escribir_a_mano'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => setState(() => _escribirAMano = true),
                child: const Text('Escribir los datos a mano'),
              ),
            if (_escaneado == null && _escribirAMano) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('campo_codigo_tienda'),
                controller: _codigoController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (_, nuevo) =>
                        nuevo.copyWith(text: nuevo.text.toUpperCase()),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Código de la tienda',
                  hintText: 'Ej.: K7M2QX',
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Número de vendedor',
                  hintText: 'Ej.: 3',
                  errorText: _errorNumero,
                ),
              ),
            ],
            if (_escaneado != null || _escribirAMano) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('campo_pin_vendedor'),
                controller: _pinController,
                focusNode: _foroPin,
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
          ],
        ),
      ),
    );
  }
}
