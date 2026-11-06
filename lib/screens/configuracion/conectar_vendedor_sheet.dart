import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../respaldo/respaldo_screen.dart';

/// Lleva al admin a dejar listo el celular de [vendedor]: comparte la tienda
/// si hace falta y le muestra qué dictarle (código, número y su PIN).
Future<void> conectarCelularVendedor(
  BuildContext context,
  WidgetRef ref,
  Usuario vendedor,
) async {
  final titulo = 'Para que ${vendedor.nombre} entre desde su celular';
  final sincronizacion = ref.read(sincronizacionProvider.notifier);
  if (!await sincronizacion.esCompartida()) {
    if (!context.mounted) return;
    // Compartir la tienda necesita la sesión del correo del respaldo.
    if (ref.read(respaldoProvider).fase != FaseRespaldo.activo) {
      await mostrarHojaInferior<void>(
        context,
        titulo: titulo,
        builder: (contexto) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Primero activa el respaldo en Ajustes → Respaldo.'),
            const SizedBox(height: 16),
            BotonPrincipal(
              key: const Key('abrir_respaldo'),
              texto: 'Abrir Respaldo',
              onPressed: () {
                Navigator.of(contexto).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RespaldoScreen()),
                );
              },
            ),
          ],
        ),
      );
      return;
    }
    if (!await compartirTiendaConConfirmacion(context, ref)) return;
  }
  final repo = ref.read(usuarioRepositoryProvider);
  final teniaNumero = vendedor.numeroVendedor != null;
  final numero = await repo.asegurarNumeroVendedor(vendedor.id);
  ref.invalidate(listaUsuariosProvider);
  final String codigo;
  try {
    // El número recién dado debe llegar a la nube antes de que lo escriba.
    if (!teniaNumero) await sincronizacion.sincronizarAhora();
    codigo = await sincronizacion.codigoTienda();
  } catch (error) {
    if (context.mounted) {
      avisar(context, mensajeErrorTienda(error), error: true);
    }
    return;
  }
  if (!context.mounted) return;
  await mostrarHojaInferior<void>(
    context,
    titulo: titulo,
    builder: (contexto) => _Instrucciones(codigo: codigo, numero: numero),
  );
}

class _Instrucciones extends StatelessWidget {
  const _Instrucciones({required this.codigo, required this.numero});

  final String codigo;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    return Column(
      key: const Key('hoja_conectar_vendedor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colores.primarioSuave,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                codigo,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              Text('Vendedor $numero', style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '1. Instala VeciTienda.\n'
          '2. Toca "Unirme a una tienda".\n'
          '3. Escribe: Código $codigo · Vendedor $numero · su PIN.',
        ),
        const SizedBox(height: 8),
        Text(
          'Luego apruebas su celular en el aviso que te llega aquí.',
          style: TextStyle(color: colores.textoSecundario),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('cerrar_conectar_vendedor'),
          texto: 'Entendido',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
