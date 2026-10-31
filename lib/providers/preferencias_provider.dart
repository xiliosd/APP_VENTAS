import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del celular; se cargan en `main` antes de arrancar la app.
final preferenciasProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('preferenciasProvider se sobrescribe en main()');
});
