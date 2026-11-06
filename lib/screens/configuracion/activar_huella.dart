import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/huella_provider.dart';
import '../../servicios/autenticacion_huella.dart';

/// Avisa qué significa entrar con huella y la activa para [usuario] solo si
/// quien tiene el celular la confirma. Devuelve true si quedó activa.
Future<bool> activarHuella(
  BuildContext context,
  WidgetRef ref,
  Usuario usuario,
) async {
  final acepta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Entrar con huella?'),
      content: const Text(
        // El rostro también cuenta como biometría en muchos celulares.
        'Cualquier huella o rostro registrado en este celular podrá abrir '
        'tu usuario. Actívalo solo si el celular es tuyo.',
      ),
      actions: [
        TextButton(
          key: const Key('cancelar_huella'),
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('activar_huella'),
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Activar'),
        ),
      ],
    ),
  );
  if (acepta != true) return false;
  // Solo se activa si quien está aquí confirma con su huella.
  final resultado = await ref
      .read(autenticacionHuellaProvider)
      .confirmar('Confirma que eres ${usuario.nombre}');
  if (resultado != ResultadoHuella.aprobada) return false;
  await ref.read(usuariosConHuellaProvider.notifier).activar(usuario.id);
  return true;
}
