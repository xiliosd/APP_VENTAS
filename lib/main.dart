import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/raiz_app.dart';
import 'ui/tema_app.dart';

void main() {
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
