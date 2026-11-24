import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/respaldo_provider.dart';
import '../../ui/boton_principal.dart';

/// Paso para el dueño que usará la tienda también en otro celular suyo.
class PasoSoyYo extends ConsumerWidget {
  const PasoSoyYo({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correo = ref.watch(respaldoProvider).correo ?? '';
    const estilo = TextStyle(fontSize: 18, height: 1.4);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'En el otro celular',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        const Text('1. Instala VeciTienda en el otro celular.', style: estilo),
        const SizedBox(height: 12),
        const Text(
          '2. Toca "Ya tengo una tienda (soy el dueño)".',
          style: estilo,
        ),
        const SizedBox(height: 12),
        const Text('3. Escribe este correo:', style: estilo),
        const SizedBox(height: 4),
        Text(
          correo,
          key: const Key('correo_dueno'),
          style: estilo.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          '4. Escribe el código que te llega al correo.',
          style: estilo,
        ),
        const SizedBox(height: 24),
        BotonPrincipal(
          key: const Key('boton_listo_soy_yo'),
          texto: 'Listo',
          onPressed: alTerminar,
        ),
      ],
    );
  }
}
