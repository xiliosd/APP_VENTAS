/// Claves de Supabase, pasadas al compilar:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// Nunca se guardan en el repositorio. Sin ellas la app funciona igual y el
/// respaldo aparece como "No configurado".
abstract final class ConfigRespaldo {
  static const url = String.fromEnvironment('SUPABASE_URL');
  /// La "publishable key" del proyecto (o la anon key heredada; sirven igual).
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configurado => url.isNotEmpty && anonKey.isNotEmpty;
}
