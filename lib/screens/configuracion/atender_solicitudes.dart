import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';

/// En el celular del admin: cuando un celular de vendedor pide entrar,
/// muestra un aviso para aprobarlo o rechazarlo (una vez por solicitud).
class AtenderSolicitudes extends ConsumerStatefulWidget {
  const AtenderSolicitudes({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AtenderSolicitudes> createState() => _AtenderSolicitudesState();
}

class _AtenderSolicitudesState extends ConsumerState<AtenderSolicitudes> {
  final _vistas = <String>{};
  bool _mostrando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _atenderSiguiente());
  }

  String _clave(CelularTienda solicitud) =>
      '${solicitud.usuarioAuth}/${solicitud.solicitadoEn.toIso8601String()}';

  Future<void> _atenderSiguiente() async {
    if (_mostrando || !mounted) return;
    final solicitud = ref
        .read(sincronizacionProvider)
        .solicitudes
        .where((s) => !_vistas.contains(_clave(s)))
        .firstOrNull;
    if (solicitud == null) return;
    _vistas.add(_clave(solicitud));
    _mostrando = true;
    try {
      await _preguntar(solicitud);
    } finally {
      _mostrando = false;
    }
    await _atenderSiguiente();
  }

  Future<void> _preguntar(CelularTienda solicitud) async {
    final nombre = solicitud.nombreVendedor ?? 'un vendedor';
    final aprobar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Un celular nuevo quiere entrar como $nombre'),
        content: Text(
          'Celular: ${solicitud.nombreCelular ?? 'Celular'}. Apruébalo solo '
          'si es el celular de $nombre.',
        ),
        actions: [
          TextButton(
            key: const Key('rechazar_solicitud'),
            style: TextButton.styleFrom(
              foregroundColor: ColoresApp.of(contexto).sale,
            ),
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Rechazar'),
          ),
          FilledButton(
            key: const Key('aprobar_solicitud'),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    // Cerrado sin responder: la solicitud sigue en "Celulares de la tienda".
    if (aprobar == null || !mounted) return;
    await responderSolicitudConAviso(context, ref, solicitud, aprobar: aprobar);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EstadoTiendaCompartida>(
      sincronizacionProvider,
      (_, _) => _atenderSiguiente(),
    );
    return widget.child;
  }
}

/// Aprueba o rechaza [solicitud] y lo confirma con un aviso.
Future<void> responderSolicitudConAviso(
  BuildContext context,
  WidgetRef ref,
  CelularTienda solicitud, {
  required bool aprobar,
}) async {
  try {
    await ref
        .read(sincronizacionProvider.notifier)
        .responderSolicitud(solicitud, aprobar: aprobar);
    if (context.mounted) {
      avisar(context, aprobar ? 'Celular aprobado' : 'Celular rechazado');
    }
  } catch (error) {
    if (context.mounted) {
      avisar(context, mensajeErrorTienda(error), error: true);
    }
  }
}
