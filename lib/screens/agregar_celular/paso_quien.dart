import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../configuracion/conectar_vendedor_sheet.dart';
import '../configuracion/formulario_usuario.dart';

/// Los vendedores activos y los celulares aprobados de la tienda.
typedef _DatosQuien = ({
  List<Usuario> vendedores,
  List<CelularTienda> celulares,
});

/// Paso 2: ¿quién va a usar el celular? Un vendedor que ya existe, una
/// persona nueva o el propio dueño en otro celular.
class PasoQuien extends ConsumerStatefulWidget {
  const PasoQuien({
    super.key,
    required this.alElegirVendedor,
    required this.alSoyYo,
  });

  /// Con `true` si ese vendedor ya tiene un celular y este lo reemplaza.
  final void Function(Usuario vendedor, bool cambiaCelular) alElegirVendedor;
  final VoidCallback alSoyYo;

  @override
  ConsumerState<PasoQuien> createState() => _PasoQuienState();
}

class _PasoQuienState extends ConsumerState<PasoQuien> {
  late Future<_DatosQuien> _datos = _cargar();

  Future<_DatosQuien> _cargar() async {
    final activos = await ref.read(usuarioRepositoryProvider).listarActivos();
    final celulares = await ref
        .read(sincronizacionProvider.notifier)
        .celulares();
    return (
      vendedores: [
        for (final usuario in activos)
          if (usuario.rol == 'vendedor') usuario,
      ],
      celulares: celulares,
    );
  }

  bool _tieneCelular(Usuario vendedor, List<CelularTienda> celulares) =>
      celulares.any(
        (celular) =>
            celular.rol == 'vendedor' &&
            celular.estado == EstadoMiembro.aprobado &&
            celular.usuarioIdGlobal == vendedor.idGlobal,
      );

  Future<void> _otraPersona() async {
    final id = await mostrarHojaInferior<int>(
      context,
      titulo: 'Nuevo vendedor',
      builder: (_) => const FormularioUsuario(soloVendedor: true),
    );
    if (id == null || !mounted) return;
    try {
      final vendedor = await ref.read(usuarioRepositoryProvider).buscar(id);
      if (vendedor == null) return;
      // El vendedor nuevo y su número deben estar en la nube antes de que
      // los escriba en su celular.
      await asegurarNumeroVendedorEnNube(ref, vendedor, sincronizar: true);
      final conNumero = await ref.read(usuarioRepositoryProvider).buscar(id);
      if (!mounted) return;
      widget.alElegirVendedor(conNumero ?? vendedor, false);
    } catch (error) {
      if (mounted) avisar(context, mensajeErrorTienda(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '¿Quién va a usar el celular?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FutureBuilder<_DatosQuien>(
          future: _datos,
          builder: (context, instantanea) {
            if (instantanea.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    mensajeErrorTienda(instantanea.error!),
                    key: const Key('error_quien'),
                    style: TextStyle(color: colores.sale),
                  ),
                  const SizedBox(height: 12),
                  BotonPrincipal(
                    key: const Key('reintentar_quien'),
                    texto: 'Reintentar',
                    variante: VarianteBoton.contorno,
                    onPressed: () {
                      setState(() {
                        _datos = _cargar();
                      });
                    },
                  ),
                ],
              );
            }
            final datos = instantanea.data;
            if (datos == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                for (final vendedor in datos.vendedores)
                  Card(
                    child: ListTile(
                      key: Key('quien_${vendedor.id}'),
                      leading: AvatarInicial(
                        id: vendedor.id,
                        nombre: vendedor.nombre,
                      ),
                      title: Text(
                        vendedor.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: _tieneCelular(vendedor, datos.celulares)
                          ? const Text('Cambiar su celular')
                          : null,
                      onTap: () => widget.alElegirVendedor(
                        vendedor,
                        _tieneCelular(vendedor, datos.celulares),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        BotonPrincipal(
          key: const Key('quien_otra_persona'),
          texto: 'Otra persona',
          variante: VarianteBoton.contorno,
          onPressed: _otraPersona,
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('quien_soy_yo'),
          texto: 'Soy yo, en otro celular',
          variante: VarianteBoton.contorno,
          onPressed: widget.alSoyYo,
        ),
      ],
    );
  }
}
