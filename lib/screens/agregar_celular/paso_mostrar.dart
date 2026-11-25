import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/database.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../util/codigo_unirse.dart';
import '../configuracion/atender_solicitudes.dart';

/// Mientras el asistente muestra el QR, el aviso global de solicitudes espera:
/// la aprobación se hace aquí mismo.
final asistenteCelularAbiertoProvider = StateProvider<bool>((ref) => false);

/// Cada cuánto se revisa la nube mientras se espera que el vendedor escanee.
const _intervaloRevision = Duration(seconds: 5);

/// Paso 3 del asistente: el QR y los datos que el vendedor necesita para
/// entrar, y la aprobación de su celular en cuanto lo pide.
class PasoMostrar extends ConsumerStatefulWidget {
  const PasoMostrar({
    super.key,
    required this.vendedor,
    required this.cambiaCelular,
  });

  final Usuario vendedor;
  final bool cambiaCelular;

  @override
  ConsumerState<PasoMostrar> createState() => _PasoMostrarState();
}

class _PasoMostrarState extends ConsumerState<PasoMostrar> {
  late final StateController<bool> _abierto;
  late Future<String> _codigo;
  Timer? _revision;
  bool _aprobando = false;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _abierto = ref.read(asistenteCelularAbiertoProvider.notifier);
    // No se puede cambiar un provider mientras se construye el árbol.
    Future.microtask(() {
      if (mounted) _abierto.state = true;
    });
    _codigo = ref.read(sincronizacionProvider.notifier).codigoTienda();
    _revision = Timer.periodic(_intervaloRevision, (_) => _revisarNube());
  }

  @override
  void dispose() {
    _revision?.cancel();
    // No se puede cambiar un provider mientras se desmonta el árbol.
    Future.microtask(() {
      try {
        _abierto.state = false;
      } catch (_) {
        // La app entera ya se cerró: no queda nada que avisar.
      }
    });
    super.dispose();
  }

  void _revisarNube() {
    if (_listo) return;
    // Sin internet se reintenta en la siguiente vuelta, sin molestar.
    unawaited(
      ref
          .read(sincronizacionProvider.notifier)
          .sincronizarAhora()
          .catchError((_) {}),
    );
  }

  void _reintentar() => setState(() {
    _codigo = ref.read(sincronizacionProvider.notifier).codigoTienda();
  });

  CelularTienda? _solicitudDelVendedor(List<CelularTienda> solicitudes) {
    for (final solicitud in solicitudes) {
      if (solicitud.usuarioIdGlobal == widget.vendedor.idGlobal) {
        return solicitud;
      }
    }
    return null;
  }

  Future<void> _aprobar(CelularTienda solicitud) async {
    setState(() => _aprobando = true);
    final aprobada = await responderSolicitudConAviso(
      context,
      ref,
      solicitud,
      aprobar: true,
    );
    if (!mounted) return;
    // Solo con la aprobación hecha deja de servir el celular anterior.
    if (aprobada) await _revocarAnterior(solicitud);
    if (!mounted) return;
    setState(() {
      _aprobando = false;
      _listo = aprobada;
    });
  }

  Future<void> _revocarAnterior(CelularTienda solicitud) async {
    if (!widget.cambiaCelular) return;
    final notificador = ref.read(sincronizacionProvider.notifier);
    try {
      final celulares = await notificador.celulares();
      final anteriores = celularesAReemplazar(
        celulares,
        idGlobal: widget.vendedor.idGlobal,
        usuarioAuthNuevo: solicitud.usuarioAuth,
      );
      for (final anterior in anteriores) {
        await notificador.revocarCelular(anterior.usuarioAuth);
      }
    } catch (error) {
      if (mounted) {
        avisar(
          context,
          'Se aprobó el celular nuevo, pero el anterior sigue activo. '
          '${mensajeErrorTienda(error)}',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _solicitudDelVendedor(
      ref.watch(sincronizacionProvider.select((estado) => estado.solicitudes)),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_listo)
          _Listo(nombre: widget.vendedor.nombre)
        else ...[
          // Arriba, para que Aprobar se vea sin bajar hasta el final.
          if (solicitud == null)
            Text(
              'Esperando que ${widget.vendedor.nombre} escanee…',
              key: const Key('esperando_vendedor'),
              style: const TextStyle(fontSize: 18, height: 1.4),
            )
          else
            _Solicitud(
              vendedor: widget.vendedor,
              solicitud: solicitud,
              cambiaCelular: widget.cambiaCelular,
              aprobando: _aprobando,
              alAprobar: () => _aprobar(solicitud),
            ),
          const SizedBox(height: 24),
          _Codigo(
            vendedor: widget.vendedor,
            codigo: _codigo,
            alReintentar: _reintentar,
          ),
        ],
      ],
    );
  }
}

/// El QR y, debajo, los mismos datos escritos por si la cámara no funciona.
class _Codigo extends StatelessWidget {
  const _Codigo({
    required this.vendedor,
    required this.codigo,
    required this.alReintentar,
  });

  final Usuario vendedor;
  final Future<String> codigo;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    return FutureBuilder<String>(
      future: codigo,
      builder: (context, instantanea) {
        final numero = vendedor.numeroVendedor;
        if (instantanea.hasError || (instantanea.hasData && numero == null)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                instantanea.hasError
                    ? mensajeErrorTienda(instantanea.error!)
                    : mensajeErrorTienda(StateError('Sin número de vendedor')),
                key: const Key('error_codigo'),
                style: TextStyle(fontSize: 18, color: colores.sale),
              ),
              const SizedBox(height: 12),
              BotonPrincipal(
                key: const Key('reintentar_codigo'),
                texto: 'Reintentar',
                variante: VarianteBoton.contorno,
                onPressed: alReintentar,
              ),
            ],
          );
        }
        if (!instantanea.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final codigoTienda = instantanea.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pídele a ${vendedor.nombre} que escanee este código con '
              'VeciTienda.',
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 16),
            Center(
              child: Semantics(
                label: 'Código QR para unir el celular de ${vendedor.nombre}',
                excludeSemantics: true,
                child: Container(
                  color: ColoresApp.blancoMarca,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: textoCodigoUnirse(
                      codigo: codigoTienda,
                      numero: numero!,
                    ),
                    size: 240,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¿No funciona la cámara?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _Dato(
              etiqueta: 'Código de la tienda',
              valor: codigoTienda,
              llave: const Key('dato_codigo'),
            ),
            const SizedBox(height: 12),
            _Dato(
              etiqueta: 'Número de vendedor',
              valor: '$numero',
              llave: const Key('dato_numero'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Su PIN es el que le diste (no se muestra aquí).',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.llave,
  });

  final String etiqueta;
  final String valor;
  final Key llave;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta, style: const TextStyle(fontSize: 16)),
      Text(
        valor,
        key: llave,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _Solicitud extends StatelessWidget {
  const _Solicitud({
    required this.vendedor,
    required this.solicitud,
    required this.cambiaCelular,
    required this.aprobando,
    required this.alAprobar,
  });

  final Usuario vendedor;
  final CelularTienda solicitud;
  final bool cambiaCelular;
  final bool aprobando;
  final VoidCallback alAprobar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${vendedor.nombre} pide entrar desde '
        '${solicitud.nombreCelular ?? 'un celular'}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      if (cambiaCelular) ...[
        const SizedBox(height: 8),
        const Text(
          'Su celular anterior dejará de tener los datos de la tienda.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
      ],
      const SizedBox(height: 16),
      BotonPrincipal(
        key: const Key('aprobar_aqui'),
        texto: 'Aprobar',
        onPressed: aprobando ? null : alAprobar,
      ),
    ],
  );
}

class _Listo extends StatelessWidget {
  const _Listo({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '¡Listo! $nombre ya puede vender desde su celular',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 24),
      BotonPrincipal(
        key: const Key('terminar_asistente'),
        texto: 'Terminar',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
