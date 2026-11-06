import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/correo.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../sincronizacion/sincronizador.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../util/fecha_util.dart';
import 'dialogos_tienda_compartida.dart';
import 'verificar_correo_screen.dart';

class RespaldoScreen extends ConsumerWidget {
  const RespaldoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(respaldoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo')),
      body: switch (estado.fase) {
        FaseRespaldo.noConfigurado => const EstadoVacio(
          icono: Icons.cloud_off_rounded,
          titulo: 'Respaldo no configurado',
          mensaje: 'Esta versión de la app no tiene conexión a la nube.',
        ),
        FaseRespaldo.desactivado => const _Desactivado(),
        FaseRespaldo.activo => _Activo(estado: estado),
        FaseRespaldo.requiereReconexion => const _Reconectar(),
      },
    );
  }
}

void _abrirVerificacion(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          const VerificarCorreoScreen(modo: ModoVerificacion.activar),
    ),
  );
}

class _Desactivado extends StatelessWidget {
  const _Desactivado();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const EstadoVacio(
          icono: Icons.cloud_upload_outlined,
          titulo: 'Tus datos solo están en este celular',
          mensaje:
              'Activa el respaldo para guardar una copia en la nube y '
              'recuperarla si pierdes o cambias el celular.',
        ),
        BotonPrincipal(
          key: const Key('boton_activar_respaldo'),
          texto: 'Activar respaldo',
          onPressed: () => _abrirVerificacion(context),
        ),
      ],
    );
  }
}

class _Activo extends ConsumerWidget {
  const _Activo({required this.estado});

  final EstadoRespaldo estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tienda = ref.watch(sincronizacionProvider);
    if (tienda.fase != FaseSincronizacion.noCompartida) {
      return _TiendaCompartida(estado: tienda);
    }
    final puedeCompartir = ref.read(sincronizacionProvider.notifier).disponible;
    final notifier = ref.read(respaldoProvider.notifier);
    final ultimo = estado.ultimoRespaldo;
    final textoEstado = estado.respaldando
        ? 'Respaldando…'
        : ultimo == null
        ? 'Aún no hay respaldo'
        : 'Último respaldo: ${textoUltimoRespaldo(ultimo, DateTime.now())}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          key: const Key('tarjeta_estado_respaldo'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ColoresApp.of(context).entra.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_done_rounded,
                    size: 28,
                    color: ColoresApp.of(context).entra,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Respaldo activo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estado.correo == null
                            ? 'Correo conectado'
                            : 'Correo: ${correoEnmascarado(estado.correo!)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        textoEstado,
                        key: const Key('texto_ultimo_respaldo'),
                        style: TextStyle(
                          color: ColoresApp.of(context).textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_respaldar_ahora'),
          texto: 'Respaldar ahora',
          onPressed: estado.respaldando
              ? null
              : () async {
                  final ok = await notifier.respaldarAhora();
                  if (context.mounted) {
                    avisar(
                      context,
                      ok ? 'Respaldo guardado' : 'No se pudo respaldar',
                      error: !ok,
                    );
                  }
                },
        ),
        if (puedeCompartir) ...[
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_compartir_tienda'),
            texto: 'Usar la tienda en varios celulares',
            variante: VarianteBoton.contorno,
            onPressed: () => compartirTiendaConConfirmacion(context, ref),
          ),
        ],
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_desconectar'),
          texto: 'Desconectar',
          variante: VarianteBoton.contorno,
          onPressed: () async {
            final confirmado = await showDialog<bool>(
              context: context,
              builder: (contexto) => AlertDialog(
                title: const Text('¿Desconectar el respaldo?'),
                content: const Text(
                  'Tus datos se quedan en este celular, pero ya no se '
                  'guardará una copia en la nube.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(contexto, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('confirmar_desconectar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresApp.of(context).sale,
                      foregroundColor: ColoresApp.of(context).sobreSale,
                    ),
                    onPressed: () => Navigator.pop(contexto, true),
                    child: const Text('Desconectar'),
                  ),
                ],
              ),
            );
            if (confirmado == true) await notifier.desconectar();
          },
        ),
      ],
    );
  }
}

/// Pide confirmación y deja la tienda compartida. Devuelve true si este
/// celular quedó con su tienda en la nube.
Future<bool> compartirTiendaConConfirmacion(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Usar la tienda en varios celulares?'),
      content: const Text(
        'Los datos de la tienda se guardarán en la nube y se mantendrán al '
        'día en cada celular de la tienda. El respaldo por archivo se '
        'reemplaza por esto.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar_compartir'),
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (confirmado != true) return false;
  final tienda = ref.read(sincronizacionProvider.notifier);
  try {
    await tienda.compartirTienda();
    if (context.mounted) avisar(context, 'La tienda ya está en la nube');
    return true;
  } on TiendaCompartidaExistente catch (existente) {
    // El correo ya compartió su tienda desde otro celular: se usa esa.
    if (!context.mounted ||
        !await preguntarUsarTiendaCompartida(context) ||
        !context.mounted ||
        !await confirmarDescargaTienda(
          context,
          mensajeReemplazarPorTiendaCompartida,
        )) {
      return false;
    }
    try {
      await tienda.descargarTienda(existente.tiendaId, reemplazarDatos: true);
      if (!context.mounted) return false;
      avisar(context, 'Tienda recuperada. Entra con tu PIN.');
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } catch (error) {
      if (context.mounted) {
        avisar(context, mensajeErrorTienda(error), error: true);
      }
    }
  } catch (error) {
    if (context.mounted) {
      avisar(context, mensajeErrorTienda(error), error: true);
    }
  }
  return false;
}

/// Estado de la tienda compartida: reemplaza al respaldo por archivo.
class _TiendaCompartida extends ConsumerWidget {
  const _TiendaCompartida({required this.estado});

  final EstadoTiendaCompartida estado;

  String _textoFase() {
    final ultima = estado.ultimaSincronizacion;
    return switch (estado.fase) {
      FaseSincronizacion.alDia =>
        ultima == null
            ? 'Al día'
            : 'Al día · última vez '
                  '${textoUltimoRespaldo(ultima, DateTime.now())}',
      FaseSincronizacion.sincronizando => 'Sincronizando…',
      FaseSincronizacion.sinConexion =>
        'Sin internet: se sube cuando vuelva la conexión',
      FaseSincronizacion.actualizarApp =>
        'Actualiza la app para seguir sincronizando',
      FaseSincronizacion.requiereReconexion =>
        'La sesión venció: vuelve a entrar con el código del correo',
      FaseSincronizacion.error =>
        'No se pudo sincronizar; se reintenta en un minuto',
      FaseSincronizacion.noCompartida => '',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colores = ColoresApp.of(context);
    final textoFase = _textoFase();
    final pendientes = estado.pendientes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          container: true,
          label: 'Tienda compartida. $textoFase',
          child: Card(
            key: const Key('tarjeta_sincronizacion'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colores.entra.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.devices_rounded,
                      size: 28,
                      color: colores.entra,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tienda compartida',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(textoFase),
                        if (pendientes > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            pendientes == 1
                                ? '1 cambio por subir'
                                : '$pendientes cambios por subir',
                            style: TextStyle(color: colores.textoSecundario),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (estado.fase == FaseSincronizacion.requiereReconexion)
          BotonPrincipal(
            key: const Key('boton_reconectar'),
            texto: 'Reconectar',
            onPressed: () => _abrirVerificacion(context),
          )
        else
          BotonPrincipal(
            key: const Key('boton_sincronizar_ahora'),
            texto: 'Sincronizar ahora',
            onPressed: estado.fase == FaseSincronizacion.sincronizando
                ? null
                : () => ref
                      .read(sincronizacionProvider.notifier)
                      .sincronizarAhora(),
          ),
      ],
    );
  }
}

class _Reconectar extends StatelessWidget {
  const _Reconectar();

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.sync_problem_rounded,
      titulo: 'Reconecta el respaldo',
      mensaje: 'La sesión del respaldo venció. Verifica de nuevo tu correo.',
      accion: BotonPrincipal(
        key: const Key('boton_reconectar'),
        texto: 'Reconectar',
        onPressed: () => _abrirVerificacion(context),
      ),
    );
  }
}
