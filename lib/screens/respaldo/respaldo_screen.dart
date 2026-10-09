import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/respaldo_provider.dart';
import '../../respaldo/telefono.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../util/fecha_util.dart';
import 'verificar_telefono_screen.dart';

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
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) =>
        const VerificarTelefonoScreen(modo: ModoVerificacion.activar),
  ));
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
          mensaje: 'Activa el respaldo para guardar una copia en la nube y '
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: ColoresApp.of(context).entra),
                    SizedBox(width: 8),
                    Text('Respaldo activo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(estado.telefono == null
                    ? 'Celular conectado'
                    : 'Celular: ${telefonoEnmascarado(estado.telefono!)}'),
                const SizedBox(height: 4),
                Text(
                  textoEstado,
                  key: const Key('texto_ultimo_respaldo'),
                  style: TextStyle(color: ColoresApp.of(context).textoSecundario),
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
                    avisar(context,
                        ok ? 'Respaldo guardado' : 'No se pudo respaldar');
                  }
                },
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_desconectar'),
          texto: 'Desconectar',
          variante: VarianteBoton.peligro,
          onPressed: () => notifier.desconectar(),
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
      mensaje: 'La sesión del respaldo venció. Verifica de nuevo el celular '
          'de la tienda.',
      accion: BotonPrincipal(
        key: const Key('boton_reconectar'),
        texto: 'Reconectar',
        onPressed: () => _abrirVerificacion(context),
      ),
    );
  }
}
