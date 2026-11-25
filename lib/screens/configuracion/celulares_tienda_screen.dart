import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/pildora.dart';
import '../agregar_celular/agregar_celular_screen.dart';
import 'atender_solicitudes.dart';

/// Quién entra a la tienda compartida desde su celular: el admin aprueba,
/// rechaza o quita el acceso a cada celular de vendedor.
class CelularesTiendaScreen extends ConsumerStatefulWidget {
  const CelularesTiendaScreen({super.key});

  @override
  ConsumerState<CelularesTiendaScreen> createState() =>
      _CelularesTiendaScreenState();
}

class _CelularesTiendaScreenState extends ConsumerState<CelularesTiendaScreen> {
  late Future<(String?, List<CelularTienda>)> _datos = _cargar();

  /// Sin tienda compartida no hay código ni celulares: no es un error.
  Future<(String?, List<CelularTienda>)> _cargar() async {
    final tienda = ref.read(sincronizacionProvider.notifier);
    if (!await tienda.esCompartida()) return (null, <CelularTienda>[]);
    return (await tienda.codigoTienda(), await tienda.celulares());
  }

  Future<void> _agregarCelular() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AgregarCelularScreen()),
    );
    // El asistente puede haber compartido la tienda o aprobado un celular.
    if (mounted) _recargar();
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _responder(
    CelularTienda celular, {
    required bool aprobar,
  }) async {
    await responderSolicitudConAviso(context, ref, celular, aprobar: aprobar);
    if (mounted) _recargar();
  }

  Future<void> _quitarAcceso(CelularTienda celular) async {
    final nombre = celular.nombreVendedor ?? 'este vendedor';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Quitarle el acceso al celular de $nombre?'),
        content: const Text(
          'Ese celular entrega lo que tenga pendiente y deja de tener los '
          'datos de la tienda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar_quitar_acceso'),
            style: FilledButton.styleFrom(
              backgroundColor: ColoresApp.of(contexto).sale,
              foregroundColor: ColoresApp.of(contexto).sobreSale,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await ref
          .read(sincronizacionProvider.notifier)
          .revocarCelular(celular.usuarioAuth);
      if (mounted) avisar(context, 'Acceso quitado');
    } catch (error) {
      if (mounted) avisar(context, mensajeErrorTienda(error), error: true);
    }
    if (mounted) _recargar();
  }

  (String, Color) _etiquetaEstado(BuildContext context, EstadoMiembro estado) {
    final colores = ColoresApp.of(context);
    return switch (estado) {
      EstadoMiembro.pendiente => ('Esperando', colores.fiado),
      EstadoMiembro.aprobado => ('Con acceso', colores.entra),
      EstadoMiembro.rechazado => ('Rechazado', colores.sale),
      EstadoMiembro.revocado => ('Sin acceso', colores.textoSecundario),
    };
  }

  Widget _fila(CelularTienda celular) {
    if (celular.rol == 'admin') {
      return const ListTile(
        leading: Icon(Icons.admin_panel_settings_rounded),
        title: Text('Tú (administrador)'),
      );
    }
    final (texto, color) = _etiquetaEstado(context, celular.estado);
    final id = celular.usuarioAuth;
    return ListTile(
      key: Key('celular_$id'),
      leading: const Icon(Icons.smartphone_rounded),
      title: Text(celular.nombreVendedor ?? 'Vendedor'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(celular.nombreCelular ?? 'Celular'),
            Pildora(texto: texto, color: color),
          ],
        ),
      ),
      trailing: switch (celular.estado) {
        EstadoMiembro.pendiente => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('rechazar_$id'),
              tooltip: 'Rechazar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _responder(celular, aprobar: false),
            ),
            IconButton(
              key: Key('aprobar_$id'),
              tooltip: 'Aprobar',
              icon: const Icon(Icons.check_rounded),
              onPressed: () => _responder(celular, aprobar: true),
            ),
          ],
        ),
        EstadoMiembro.aprobado => TextButton(
          key: Key('quitar_acceso_$id'),
          onPressed: () => _quitarAcceso(celular),
          child: const Text('Quitar acceso'),
        ),
        _ => null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Celulares de la tienda')),
      body: FutureBuilder(
        future: _datos,
        builder: (context, datos) {
          if (datos.hasError) {
            // Sin internet es lo común aquí: se dice eso, no "No se pudo cargar".
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  mensajeErrorTienda(datos.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!datos.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (codigo, celulares) = datos.data!;
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BotonPrincipal(
                  key: const Key('boton_agregar_celular'),
                  texto: 'Agregar un celular',
                  onPressed: _agregarCelular,
                ),
                const SizedBox(height: 16),
                if (codigo == null)
                  const Text(
                    'Aún no hay otros celulares.',
                    style: TextStyle(fontSize: 18),
                  )
                else ...[
                  Text(
                    'Código de la tienda: $codigo',
                    key: const Key('codigo_tienda'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Es el código de tu tienda. Para sumar un celular usa '
                    '"Agregar un celular".',
                    style: TextStyle(
                      color: ColoresApp.of(context).textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        for (final celular in celulares) _fila(celular),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
