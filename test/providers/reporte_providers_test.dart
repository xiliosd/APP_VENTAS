import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/reporte_providers.dart';
import 'package:app_ventas/util/periodo.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Descartados extends ProviderObserver {
  final nombres = <String?>[];

  @override
  void didDisposeProvider(
          ProviderBase<Object?> provider, ProviderContainer container) =>
      nombres.add(provider.name);
}

void main() {
  test('al cerrar Reportes se deja de escuchar la base', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final observador = _Descartados();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
      observers: [observador],
    );
    addTearDown(container.dispose);
    final hoy = DateTime(2026, 10, 8);
    final consulta =
        (periodo: Periodo.actual(TipoPeriodo.semana, hoy), hoy: hoy);

    final escucha =
        container.listen(comparacionReporteProvider(consulta), (_, _) {});
    await container.read(comparacionReporteProvider(consulta).future);
    escucha.close();
    await container.pump();
    await container.pump();

    expect(observador.nombres, contains('cambiosReporte'));
  });
}
