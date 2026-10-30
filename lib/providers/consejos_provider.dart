import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

/// Consejos de primera vez que se muestran una sola vez por celular.
enum Consejo { escanearVenta, escanearProducto }

class ConsejosVistos extends Notifier<Set<Consejo>> {
  static String _clave(Consejo consejo) => 'consejo_visto_${consejo.name}';

  @override
  Set<Consejo> build() {
    final preferencias = ref.read(preferenciasProvider);
    return {
      for (final c in Consejo.values)
        if (preferencias.getBool(_clave(c)) ?? false) c,
    };
  }

  Future<void> marcarVisto(Consejo consejo) async {
    state = {...state, consejo};
    await ref.read(preferenciasProvider).setBool(_clave(consejo), true);
  }
}

/// Consejos que ya se mostraron en este celular.
final consejosVistosProvider = NotifierProvider<ConsejosVistos, Set<Consejo>>(
  ConsejosVistos.new,
);
