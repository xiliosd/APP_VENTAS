import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../providers/repository_providers.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../util/codigo_unirse.dart';
import '../respaldo/respaldo_screen.dart';
import '../respaldo/verificar_correo_screen.dart';
import 'asegurar_numero_vendedor.dart';
import 'paso_mostrar.dart';
import 'paso_quien.dart';
import 'paso_soy_yo.dart';

enum _Paso { cargando, errorAbrir, correo, quien, soyYo, mostrar }

/// Asistente del dueño para dejar listo el celular de alguien: confirma el
/// correo y la tienda compartida, elige quién lo usará y le muestra qué hacer.
/// Con [vendedor] abre directo en el último paso.
class AgregarCelularScreen extends ConsumerStatefulWidget {
  const AgregarCelularScreen({super.key, this.vendedor});

  final Usuario? vendedor;

  @override
  ConsumerState<AgregarCelularScreen> createState() =>
      _AgregarCelularScreenState();
}

class _AgregarCelularScreenState extends ConsumerState<AgregarCelularScreen> {
  _Paso _paso = _Paso.cargando;
  Usuario? _vendedor;
  bool _cambiaCelular = false;
  String? _errorAbrir;

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedor;
    _decidirPasoInicial();
  }

  Future<bool> _tiendaLista() async =>
      ref.read(respaldoProvider).fase == FaseRespaldo.activo &&
      await ref.read(sincronizacionProvider.notifier).esCompartida();

  Future<void> _decidirPasoInicial() async {
    final vendedor = widget.vendedor;
    if (vendedor != null) return _abrirConVendedor(vendedor);
    final lista = await _tiendaLista();
    if (mounted) setState(() => _paso = lista ? _Paso.quien : _Paso.correo);
  }

  /// Abierto desde Usuarios: deja la tienda lista y el número del vendedor en
  /// la nube antes de mostrar el QR. Sin internet no se adivina: se avisa y se
  /// puede reintentar.
  Future<void> _abrirConVendedor(Usuario vendedor) async {
    setState(() => _paso = _Paso.cargando);
    try {
      if (!await _tiendaLista()) {
        if (mounted) setState(() => _paso = _Paso.correo);
        return;
      }
      await asegurarNumeroVendedorEnNube(ref, vendedor, sincronizar: true);
      final conNumero = await ref
          .read(usuarioRepositoryProvider)
          .buscar(vendedor.id);
      final celulares = await ref
          .read(sincronizacionProvider.notifier)
          .celulares();
      if (!mounted) return;
      setState(() {
        _vendedor = conNumero ?? vendedor;
        _cambiaCelular = tieneCelularAprobado(
          celulares,
          (conNumero ?? vendedor).idGlobal,
        );
        _paso = _Paso.mostrar;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorAbrir = mensajeErrorTienda(error);
        _paso = _Paso.errorAbrir;
      });
    }
  }

  /// Con el respaldo ya activo el correo está confirmado: pasar otra vez por
  /// la verificación podría apagarlo, así que se pasa directo a compartir.
  Future<void> _confirmarCorreo() async {
    if (ref.read(respaldoProvider).fase != FaseRespaldo.activo) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const VerificarCorreoScreen(modo: ModoVerificacion.activar),
        ),
      );
    }
    if (!mounted || ref.read(respaldoProvider).fase != FaseRespaldo.activo) {
      return;
    }
    if (!await ref.read(sincronizacionProvider.notifier).esCompartida()) {
      if (!mounted) return;
      await compartirTiendaConConfirmacion(context, ref, preguntar: false);
    }
    if (!mounted) return;
    if (!await _tiendaLista() || !mounted) return;
    final vendedor = widget.vendedor;
    if (vendedor != null) return _abrirConVendedor(vendedor);
    setState(() => _paso = _Paso.quien);
  }

  void _elegirVendedor(Usuario vendedor, bool cambiaCelular) => setState(() {
    _vendedor = vendedor;
    _cambiaCelular = cambiaCelular;
    _paso = _Paso.mostrar;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar un celular')),
      body: switch (_paso) {
        _Paso.cargando => const Center(child: CircularProgressIndicator()),
        _Paso.errorAbrir => _ErrorAbrir(
          mensaje: _errorAbrir ?? '',
          alReintentar: () => _abrirConVendedor(widget.vendedor!),
        ),
        _Paso.correo => _PasoCorreo(
          correoConfirmado:
              ref.watch(respaldoProvider).fase == FaseRespaldo.activo,
          alConfirmar: _confirmarCorreo,
        ),
        _Paso.quien => PasoQuien(
          alElegirVendedor: _elegirVendedor,
          alSoyYo: () => setState(() => _paso = _Paso.soyYo),
        ),
        _Paso.soyYo => PasoSoyYo(alTerminar: () => Navigator.of(context).pop()),
        _Paso.mostrar => PasoMostrar(
          vendedor: _vendedor!,
          cambiaCelular: _cambiaCelular,
        ),
      },
    );
  }
}

class _PasoCorreo extends StatelessWidget {
  const _PasoCorreo({
    required this.correoConfirmado,
    required this.alConfirmar,
  });

  final bool correoConfirmado;
  final VoidCallback alConfirmar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          correoConfirmado ? 'Comparte la tienda' : 'Confirma tu correo',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          correoConfirmado
              ? 'Tu correo ya está confirmado. Falta guardar la tienda en la '
                    'nube para que los celulares compartan las ventas.'
              : 'Para que los celulares compartan las ventas, la tienda se '
                    'guarda en la nube con tu correo.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        const SizedBox(height: 24),
        BotonPrincipal(
          key: const Key('boton_confirmar_correo'),
          texto: correoConfirmado
              ? 'Compartir la tienda'
              : 'Confirmar mi correo',
          onPressed: alConfirmar,
        ),
      ],
    );
  }
}

class _ErrorAbrir extends StatelessWidget {
  const _ErrorAbrir({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          mensaje,
          key: const Key('error_abrir'),
          style: TextStyle(
            fontSize: 18,
            height: 1.4,
            color: ColoresApp.of(context).sale,
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('reintentar_abrir'),
          texto: 'Reintentar',
          variante: VarianteBoton.contorno,
          onPressed: alReintentar,
        ),
      ],
    );
  }
}
