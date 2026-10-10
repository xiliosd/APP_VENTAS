import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

/// Paso del recorrido de primer uso. `ninguno`: nunca empezó (instalaciones
/// previas o restauradas); `hecho`: terminado u omitido.
enum PasoRecorrido { ninguno, productos, venta, inicio, hecho }

extension PasoRecorridoX on PasoRecorrido {
  bool get enCurso =>
      this == PasoRecorrido.productos ||
      this == PasoRecorrido.venta ||
      this == PasoRecorrido.inicio;
}

const _clave = 'recorrido_paso';

class RecorridoNotifier extends Notifier<PasoRecorrido> {
  @override
  PasoRecorrido build() {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return PasoRecorrido.values
            .where((p) => p.name == guardado)
            .firstOrNull ??
        PasoRecorrido.ninguno;
  }

  /// Avisa aunque el paso no cambie: así "Ver el recorrido otra vez" abre el
  /// paso 3 también si quedó guardado en `venta` tras salir con atrás.
  @override
  bool updateShouldNotify(PasoRecorrido anterior, PasoRecorrido nuevo) => true;

  Future<void> iniciar() => irA(PasoRecorrido.productos);

  Future<void> saltar() => irA(PasoRecorrido.hecho);

  Future<void> irA(PasoRecorrido paso) async {
    state = paso;
    await ref.read(preferenciasProvider).setString(_clave, paso.name);
  }
}

final recorridoProvider =
    NotifierProvider<RecorridoNotifier, PasoRecorrido>(RecorridoNotifier.new);
