import 'dart:async';
import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/screens/agregar_celular/asegurar_numero_vendedor.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/sincronizacion/sincronizador.dart';
import 'package:app_ventas/sincronizacion/supabase_nube_tienda.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/nube_tienda_falsa.dart';

void main() {
  testWidgets('con un ciclo en curso espera a la repetición y juzga la fase '
      'final', (tester) async {
    await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final nube = NubeTiendaFalsa();
      await Sincronizador(db, nube).convertirEnCompartida('T');
      nube.ciclos = 0;
      final id = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(
              nombre: 'Beto',
              rol: 'vendedor',
              pinHash: 'x',
            ),
          );
      final vendedor = await (db.select(
        db.usuarios,
      )..where((u) => u.id.equals(id))).getSingle();

      SharedPreferences.setMockInitialValues({});
      final preferencias = await SharedPreferences.getInstance();
      final puerta = Completer<void>();
      nube.alBajar = () => puerta.future;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          preferenciasProvider.overrideWithValue(preferencias),
          nubeTiendaProvider.overrideWithValue(nube),
          nubeRespaldoProvider.overrideWithValue(null),
          copiadorProvider.overrideWithValue(
            () async => File('copia_de_prueba.sqlite'),
          ),
          retardoSincronizacionProvider.overrideWithValue(
            const Duration(seconds: 30),
          ),
          intervaloSincronizacionProvider.overrideWithValue(
            const Duration(seconds: 30),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(sincronizacionProvider, (_, _) {});

      late WidgetRef ref;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // El ciclo de apertura queda detenido en la bajada.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        container.read(sincronizacionProvider).fase,
        FaseSincronizacion.sincronizando,
      );

      var terminado = false;
      final futuro = asegurarNumeroVendedorEnNube(ref, vendedor).then((n) {
        terminado = true;
        return n;
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(terminado, isFalse);

      puerta.complete();
      final numero = await futuro;

      expect(numero, 1);
      expect(nube.ciclos, 2);
      expect(
        container.read(sincronizacionProvider).fase,
        FaseSincronizacion.alDia,
      );
    });
  });
}
