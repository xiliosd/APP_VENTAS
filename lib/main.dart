import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/apariencia_provider.dart';
import 'respaldo/config_respaldo.dart';
import 'respaldo/respaldo_provider.dart';
import 'screens/raiz_app.dart';
import 'ui/tema_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (ConfigRespaldo.configurado) {
    await Supabase.initialize(
      url: ConfigRespaldo.url,
      publishableKey: ConfigRespaldo.anonKey,
    );
  }
  final preferencias = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferenciasProvider.overrideWithValue(preferencias)],
      child: const AppVentas(),
    ),
  );
}

class AppVentas extends ConsumerWidget {
  const AppVentas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'VeciTienda',
      theme: temaClaro(),
      darkTheme: temaOscuro(),
      themeMode: ref.watch(aparienciaProvider),
      home: const RaizApp(),
    );
  }
}
