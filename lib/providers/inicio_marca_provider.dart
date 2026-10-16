import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preferencia: ya se vio la versión completa del inicio de marca.
const claveInicioCompletoVisto = 'inicio_completo_visto';

/// true hasta que el inicio de marca termina en este arranque de la app; así
/// cerrar sesión o restaurar un respaldo no lo vuelven a mostrar.
final inicioMarcaPendienteProvider = StateProvider<bool>((ref) => true);
