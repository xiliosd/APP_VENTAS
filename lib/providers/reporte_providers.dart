import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reporte_repository.dart';
import '../util/periodo.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Periodo a mostrar y el día que cuenta como hoy (normalizado con
/// `inicioDelDia`). Los records se comparan por valor.
typedef ConsultaReporte = ({Periodo periodo, DateTime hoy});

/// Emite con cada cambio en la base, para recalcular el reporte abierto
/// (mismo patrón que resumen_providers.dart).
final _cambiosReporteProvider = StreamProvider.autoDispose<void>(
  (ref) => ref.watch(databaseProvider).tableUpdates().map((_) {}),
  name: 'cambiosReporte',
);

final comparacionReporteProvider = FutureProvider.autoDispose
    .family<ComparacionReporte, ConsultaReporte>((ref, consulta) {
  ref.watch(_cambiosReporteProvider);
  return ref
      .watch(reporteRepositoryProvider)
      .comparar(consulta.periodo, hoy: consulta.hoy);
});
