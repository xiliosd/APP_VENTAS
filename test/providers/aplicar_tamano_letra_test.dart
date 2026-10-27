import 'package:app_ventas/providers/tamano_letra_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Misma configuración de MaterialApp que AppVentas, sin la pantalla raíz.
class _AppMinima extends ConsumerWidget {
  const _AppMinima();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tamano = ref.watch(tamanoLetraProvider);
    return MaterialApp(
      builder: (context, child) => aplicarTamanoLetra(context, child, tamano),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: _Medidor()),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
  }
}

class _Medidor extends StatelessWidget {
  const _Medidor();

  @override
  Widget build(BuildContext context) => Text(
    'escala ${MediaQuery.textScalerOf(context).scale(10).toStringAsFixed(1)}',
  );
}

void main() {
  testWidgets('aplica el tamaño guardado en rutas empujadas y se restaura', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'tamano_letra': 'grande'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _AppMinima(),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('escala 13.0'), findsOneWidget);

    await container
        .read(tamanoLetraProvider.notifier)
        .elegir(TamanoLetra.normal);
    await tester.pumpAndSettle();
    expect(find.text('escala 10.0'), findsOneWidget);
  });
}
