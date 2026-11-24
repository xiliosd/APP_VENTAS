import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/boton_principal.dart';
import '../respaldo/respaldo_screen.dart';
import '../respaldo/verificar_correo_screen.dart';
import 'paso_mostrar.dart';
import 'paso_quien.dart';
import 'paso_soy_yo.dart';

enum _Paso { cargando, correo, quien, soyYo, mostrar }

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
    if (vendedor != null) {
      final cambia = await _tieneCelular(vendedor);
      if (!mounted) return;
      setState(() {
        _cambiaCelular = cambia;
        _paso = _Paso.mostrar;
      });
      return;
    }
    final lista = await _tiendaLista();
    if (mounted) setState(() => _paso = lista ? _Paso.quien : _Paso.correo);
  }

  /// Si no se puede saber (sin internet), se asume que no tiene celular.
  Future<bool> _tieneCelular(Usuario vendedor) async {
    try {
      final celulares = await ref
          .read(sincronizacionProvider.notifier)
          .celulares();
      return celulares.any(
        (celular) =>
            celular.rol == 'vendedor' &&
            celular.estado == EstadoMiembro.aprobado &&
            celular.usuarioIdGlobal == vendedor.idGlobal,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmarCorreo() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const VerificarCorreoScreen(modo: ModoVerificacion.activar),
      ),
    );
    if (!mounted || ref.read(respaldoProvider).fase != FaseRespaldo.activo) {
      return;
    }
    if (!await ref.read(sincronizacionProvider.notifier).esCompartida()) {
      if (!mounted) return;
      await compartirTiendaConConfirmacion(context, ref, preguntar: false);
    }
    if (!mounted) return;
    if (await _tiendaLista() && mounted) setState(() => _paso = _Paso.quien);
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
        _Paso.correo => _PasoCorreo(alConfirmar: _confirmarCorreo),
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
  const _PasoCorreo({required this.alConfirmar});

  final VoidCallback alConfirmar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Confirma tu correo',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Para que los celulares compartan las ventas, la tienda se guarda '
          'en la nube con tu correo.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        const SizedBox(height: 24),
        BotonPrincipal(
          key: const Key('boton_confirmar_correo'),
          texto: 'Confirmar mi correo',
          onPressed: alConfirmar,
        ),
      ],
    );
  }
}
