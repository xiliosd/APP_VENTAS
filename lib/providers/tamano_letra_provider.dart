import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

const _clave = 'tamano_letra';
const _escalaMaxima = 2.0;

/// Tamaño de letra de la app; se multiplica por el del sistema.
enum TamanoLetra {
  normal('normal', 1.0),
  grande('grande', 1.3),
  muyGrande('muy_grande', 1.6);

  const TamanoLetra(this.valorGuardado, this.factor);

  final String valorGuardado;
  final double factor;
}

/// Combina la escala del sistema con la elegida en la app, sin pasar de 2,0×
/// para que las pantallas no se rompan. Con Normal no altera nada.
TextScaler escalaCombinada(TextScaler sistema, TamanoLetra tamano) {
  if (tamano == TamanoLetra.normal) return sistema;
  // Se muestrea en 14 y se vuelve lineal: el peor caso probado es 2,0× lineal.
  final escalaSistema = sistema.scale(14) / 14;
  return TextScaler.linear(
    math.min(escalaSistema * tamano.factor, _escalaMaxima),
  );
}

/// Tamaño de letra elegido en este celular. Sin elección o ilegible, Normal.
class TamanoLetraNotifier extends Notifier<TamanoLetra> {
  @override
  TamanoLetra build() {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return TamanoLetra.values
            .where((tamano) => tamano.valorGuardado == guardado)
            .firstOrNull ??
        TamanoLetra.normal;
  }

  Future<void> elegir(TamanoLetra tamano) async {
    state = tamano;
    await ref
        .read(preferenciasProvider)
        .setString(_clave, tamano.valorGuardado);
  }
}

final tamanoLetraProvider = NotifierProvider<TamanoLetraNotifier, TamanoLetra>(
  TamanoLetraNotifier.new,
);

/// Aplica [tamano] al texto de toda la app (rutas y hojas incluidas).
Widget aplicarTamanoLetra(
  BuildContext context,
  Widget? child,
  TamanoLetra tamano,
) {
  final datos = MediaQuery.of(context);
  return MediaQuery(
    data: datos.copyWith(textScaler: escalaCombinada(datos.textScaler, tamano)),
    child: child!,
  );
}
