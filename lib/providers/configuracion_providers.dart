import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/configuracion_repository.dart';
import 'database_provider.dart';

final configuracionRepositoryProvider = Provider(
  (ref) => ConfiguracionRepository(ref.watch(databaseProvider)),
);

/// QR de cobro cargado por el admin; null si no hay.
final imagenQrProvider = StreamProvider.autoDispose<Uint8List?>(
  (ref) => ref.watch(configuracionRepositoryProvider).observarImagenQr(),
);
