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

/// Paso del recorrido guardado en este celular.
const claveRecorrido = 'recorrido_paso';

class RecorridoNotifier extends Notifier<PasoRecorrido> {
  @override
  PasoRecorrido build() {
    final guardado = ref.read(preferenciasProvider).getString(claveRecorrido);
    return PasoRecorrido.values.where((p) => p.name == guardado).firstOrNull ??
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
    await ref.read(preferenciasProvider).setString(claveRecorrido, paso.name);
  }
}

final recorridoProvider = NotifierProvider<RecorridoNotifier, PasoRecorrido>(
  RecorridoNotifier.new,
);

/// Este celular es de un vendedor que acaba de unirse a la tienda y aún no ve
/// su recorrido corto. Se marca al bajar la tienda tras la aprobación.
const claveRecorridoVendedor = 'recorrido_vendedor_pendiente';

class RecorridoVendedorNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(preferenciasProvider).getBool(claveRecorridoVendedor) ?? false;

  Future<void> marcarPendiente() async {
    state = true;
    await ref.read(preferenciasProvider).setBool(claveRecorridoVendedor, true);
  }

  Future<void> terminar() async {
    state = false;
    await ref.read(preferenciasProvider).remove(claveRecorridoVendedor);
  }
}

final recorridoVendedorProvider =
    NotifierProvider<RecorridoVendedorNotifier, bool>(
      RecorridoVendedorNotifier.new,
    );
