import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'respaldo/config_respaldo.dart';
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
  runApp(const ProviderScope(child: AppVentas()));
}

class AppVentas extends StatelessWidget {
  const AppVentas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Ventas',
      theme: temaApp(),
      home: const RaizApp(),
    );
  }
}
