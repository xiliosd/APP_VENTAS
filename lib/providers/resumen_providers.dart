import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/resumen_repository.dart';
import 'repository_providers.dart';

final resumenDelDiaProvider = FutureProvider.autoDispose<ResumenDia>((ref) {
  return ref.watch(resumenRepositoryProvider).resumenDelDia(DateTime.now());
});

final resumenPorVendedorProvider =
    FutureProvider.autoDispose<Map<Usuario, ResumenDia>>((ref) {
  return ref.watch(resumenRepositoryProvider).resumenPorVendedor(DateTime.now());
});
