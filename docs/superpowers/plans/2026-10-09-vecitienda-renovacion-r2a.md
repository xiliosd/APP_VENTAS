# Renovación R2a — Pantallas de demo renovadas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inicio tipo tablero (mini gráfica de 7 días y comparación con el día anterior,
botones fijos), Nueva venta con buscador y hoja "¿Cómo paga?", "¿Quién eres?" en grilla y PIN
con indicadores animados.

**Architecture:** Un método liviano `ResumenRepository.ventasDiarias` + provider alimenta la
mini gráfica y la comparación (función pura `comparacionVentas`). Nueva venta deja de elegir
el medio de pago arriba: la hoja `mostrarHojaComoPaga` devuelve la forma de pago y la pantalla
fija `esFiado`/`medioPago` en el `TicketNotifier` justo antes del `_cobrar` existente. El
efecto "aplastar" se extrae a `lib/ui/aplastable.dart` para reutilizarlo.

**Tech Stack:** Flutter 3.47, Riverpod 2, Drift, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-vecitienda-renovacion-r2a-design.md`

## Global Constraints

- Sin cambios de esquema ni dependencias nuevas; lo que se guarda de cada venta no cambia.
- Colores solo con `ColoresApp.of(context)` (prueba `colores_sueltos_test` vigente).
- Duraciones/curvas solo de `Movimiento`; con `MediaQuery.disableAnimationsOf` todo instantáneo.
- Contraste texto/fondo ≥ 4,5:1 en ambos modos; áreas de toque ≥ 48 dp; letra grande sin
  desbordes.
- Se conservan las claves `boton_nueva_venta`, `boton_nuevo_gasto`, `boton_ver_reportes`,
  `tarjeta_ventas`, `tarjeta_gastos`, `tarjeta_ganancia`, `tarjeta_por_cobrar`, `boton_cobrar`,
  `boton_ver_ticket`, `boton_vaciar`, `boton_otro_monto`, `producto_{id}`, `usuario_{id}`,
  `tecla_{n}`, `tecla_⌫`.
- `.when(...)` de datos que se recargan por cambios de la base: `skipLoadingOnReload: true`.
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- No aplicar `dart format` a archivos enteros.
- Rama `renovacion-r2a` desde `master`.

## Review Focus

- Elegir Fiado en la hoja, escribir un cliente y cerrar la hoja sin fiar: el ticket vuelve a
  contado y el siguiente "Efectivo" registra de contado sin cliente — Task 5.
- Doble toque en una opción de la hoja (o en "Fiar"): una sola venta — Task 5.
- Día elegido distinto de hoy: la gráfica termina en ese día y la etiqueta dice "el día
  anterior" — Task 3.
- Ventas anuladas o de otro día en el borde de medianoche no entran en `ventasDiarias` — Task 1.
- PIN incorrecto dos veces seguidas: la sacudida se repite la segunda vez — Task 7.

---

### Task 1: Ventas diarias y comparación

**Files:**
- Modify: `lib/repositories/resumen_repository.dart`, `lib/providers/resumen_providers.dart`
- Create: `lib/util/comparacion_ventas.dart`, `test/util/comparacion_ventas_test.dart`
- Test: `test/repositories/resumen_repository_test.dart`

**Interfaces — Produces:**
- `Future<List<int>> ResumenRepository.ventasDiarias(DateTime hasta, {int dias = 7})`
- `final ventasDiariasProvider = FutureProvider.autoDispose.family<List<int>, DateTime>`
  (clave normalizada con `inicioDelDia`)
- `enum TendenciaVentas { sube, baja, igual, casiIgual, sinAnterior }`
- `class ComparacionVentas { final TendenciaVentas tendencia; final int porcentaje; String texto; }`
- `ComparacionVentas? comparacionVentas(int dia, int anterior, {required bool esHoy})`

- [ ] **Step 1: Crear la rama** — `git checkout -b renovacion-r2a`

- [ ] **Step 2: Tests (fallan)**

`test/util/comparacion_ventas_test.dart`:

```dart
import 'package:app_ventas/util/comparacion_ventas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin ventas ni ayer ni hoy no hay comparación', () {
    expect(comparacionVentas(0, 0, esHoy: true), isNull);
  });

  test('sin ventas ayer y con ventas hoy', () {
    final c = comparacionVentas(5000, 0, esHoy: true)!;
    expect(c.tendencia, TendenciaVentas.sinAnterior);
    expect(c.texto, 'Ayer no hubo ventas');
    expect(comparacionVentas(5000, 0, esHoy: false)!.texto,
        'El día anterior no hubo ventas');
  });

  test('sube y baja con porcentaje redondeado', () {
    final sube = comparacionVentas(112000, 100000, esHoy: true)!;
    expect(sube.tendencia, TendenciaVentas.sube);
    expect(sube.texto, '▲ 12 % vs. ayer');
    final baja = comparacionVentas(92000, 100000, esHoy: false)!;
    expect(baja.tendencia, TendenciaVentas.baja);
    expect(baja.texto, '▼ 8 % vs. el día anterior');
  });

  test('igual y casi igual', () {
    expect(comparacionVentas(5000, 5000, esHoy: true)!.texto, 'Igual que ayer');
    final casi = comparacionVentas(100400, 100000, esHoy: true)!;
    expect(casi.tendencia, TendenciaVentas.casiIgual);
    expect(casi.texto, 'Casi igual que ayer');
    expect(comparacionVentas(5000, 5000, esHoy: false)!.texto,
        'Igual que el día anterior');
  });

  test('de algo a cero baja 100 %', () {
    expect(comparacionVentas(0, 8000, esHoy: true)!.texto, '▼ 100 % vs. ayer');
  });
}
```

En `test/repositories/resumen_repository_test.dart` agregar (usar el `setUp` y helpers del
archivo; si no hay helper de venta, insertar con `db.into(db.ventas).insert(VentasCompanion.insert(...))`):

```dart
test('ventasDiarias da los 7 días que terminan en el día pedido', () async {
  final hoy = DateTime(2026, 10, 9);
  Future<void> venta(DateTime fecha, int monto,
      {bool fiado = false, bool anulada = false}) async {
    final id = await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: monto, fecha: fecha, esFiado: Value(fiado), usuarioId: usuario));
    if (anulada) {
      await (db.update(db.ventas)..where((v) => v.id.equals(id)))
          .write(const VentasCompanion(anulado: Value(true)));
    }
  }

  await venta(DateTime(2026, 10, 9, 10), 3000);
  await venta(DateTime(2026, 10, 9, 23, 59), 1000, fiado: true);
  await venta(DateTime(2026, 10, 9, 11), 9999, anulada: true);
  await venta(DateTime(2026, 10, 8, 0, 0), 2000);
  await venta(DateTime(2026, 10, 3, 12), 500);
  await venta(DateTime(2026, 10, 2, 23, 59), 7777); // fuera de la ventana
  await venta(DateTime(2026, 10, 10, 0, 0), 8888); // día siguiente

  final valores = await repo.ventasDiarias(hoy);
  expect(valores, [500, 0, 0, 0, 0, 2000, 4000]);
});
```

(Usar los nombres reales de las variables del archivo: la base, el id del usuario y el
repositorio; leer el `setUp` antes.)

- [ ] **Step 3: Run** `flutter test test/util/comparacion_ventas_test.dart test/repositories/resumen_repository_test.dart` — Expected: FAIL de compilación.

- [ ] **Step 4: Implementar**

`lib/util/comparacion_ventas.dart`:

```dart
/// Cómo van las ventas de un día frente al día anterior.
enum TendenciaVentas { sube, baja, igual, casiIgual, sinAnterior }

class ComparacionVentas {
  const ComparacionVentas(this.tendencia, this.porcentaje, this.texto);
  final TendenciaVentas tendencia;
  final int porcentaje;
  final String texto;
}

/// Compara las ventas de [dia] con las del día [anterior]. Null si ninguno
/// de los dos tuvo ventas. [esHoy] decide si se dice "ayer" o "el día anterior".
ComparacionVentas? comparacionVentas(int dia, int anterior, {required bool esHoy}) {
  final cuando = esHoy ? 'ayer' : 'el día anterior';
  if (anterior == 0) {
    if (dia == 0) return null;
    final sujeto = esHoy ? 'Ayer' : 'El día anterior';
    return ComparacionVentas(
        TendenciaVentas.sinAnterior, 0, '$sujeto no hubo ventas');
  }
  if (dia == anterior) {
    return ComparacionVentas(TendenciaVentas.igual, 0, 'Igual que $cuando');
  }
  final porcentaje = ((dia - anterior) / anterior * 100).round().abs();
  if (porcentaje == 0) {
    return ComparacionVentas(
        TendenciaVentas.casiIgual, 0, 'Casi igual que $cuando');
  }
  return dia > anterior
      ? ComparacionVentas(
          TendenciaVentas.sube, porcentaje, '▲ $porcentaje % vs. $cuando')
      : ComparacionVentas(
          TendenciaVentas.baja, porcentaje, '▼ $porcentaje % vs. $cuando');
}
```

`ResumenRepository` (mismo criterio que `ventasDelDia`: rango `inicioDelDia`..`finDelDia`,
sin anuladas, contado + fiado):

```dart
/// Total vendido (contado + fiado, sin anuladas) de cada uno de los [dias]
/// días que terminan en [hasta], del más antiguo al más reciente.
Future<List<int>> ventasDiarias(DateTime hasta, {int dias = 7}) async {
  final fin = finDelDia(hasta);
  final inicio = inicioDelDia(hasta).subtract(Duration(days: dias - 1));
  final ventas = await (_db.select(_db.ventas)
        ..where((v) =>
            v.fecha.isBiggerOrEqualValue(inicioDelDia(inicio)) &
            v.fecha.isSmallerOrEqualValue(fin) &
            v.anulado.equals(false)))
      .get();
  final totales = List<int>.filled(dias, 0);
  final primerDia = inicioDelDia(inicio);
  for (final v in ventas) {
    final indice = inicioDelDia(v.fecha).difference(primerDia).inDays;
    if (indice >= 0 && indice < dias) totales[indice] += v.monto;
  }
  return totales;
}
```

Nota: `difference().inDays` entre dos `inicioDelDia` es exacto salvo cambios de horario
(Colombia no tiene); importar `../util/fecha_util.dart` si no está.

`lib/providers/resumen_providers.dart`:

```dart
/// Totales de los 7 días que terminan en [dia] (mismo contrato de clave que
/// [resumenDelDiaProvider]).
final ventasDiariasProvider =
    FutureProvider.autoDispose.family<List<int>, DateTime>((ref, dia) {
  ref.watch(_cambiosResumenProvider);
  return ref.watch(resumenRepositoryProvider).ventasDiarias(dia);
});
```

- [ ] **Step 5: Run** los mismos tests — Expected: PASS. `flutter analyze` limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/util/comparacion_ventas.dart lib/repositories/resumen_repository.dart lib/providers/resumen_providers.dart test/util/comparacion_ventas_test.dart test/repositories/resumen_repository_test.dart
git commit -m "Add daily sales totals and the day-over-day comparison"
```

---

### Task 2: Mini gráfica de la semana

**Files:**
- Create: `lib/screens/home/mini_grafica_semana.dart`, `test/screens/home/mini_grafica_semana_test.dart`

**Interfaces:**
- Consumes: `Movimiento` (`lib/ui/movimiento.dart`), `ColoresApp`.
- Produces: `MiniGraficaSemana({required List<int> valores, required DateTime hasta, VoidCallback? onTap})`.
  Cada barra tiene clave `barra_dia_{i}` (i = 0..6); la del día elegido (i = 6) usa
  `marcaVerde`, las demás `sobreTarjetaPrincipal` al 30 %.

- [ ] **Step 1: Tests (fallan)**

```dart
import 'package:app_ventas/screens/home/mini_grafica_semana.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) => MaterialApp(
    theme: temaClaro(),
    home: Scaffold(body: Center(child: SizedBox(width: 240, child: hijo))));

Color colorBarra(WidgetTester tester, int i) =>
    (tester.widget<Container>(find.byKey(Key('barra_dia_$i'))).decoration!
            as BoxDecoration)
        .color!;

void main() {
  final jueves = DateTime(2026, 10, 9);

  testWidgets('7 barras con iniciales y el día elegido resaltado', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [1, 2, 3, 4, 5, 6, 7], hasta: jueves)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(Key('barra_dia_$i')), findsOneWidget);
    }
    // 3 oct (viernes) .. 9 oct (jueves)
    expect(find.text('V'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
    expect(colorBarra(tester, 6), ColoresApp.claro.marcaVerde);
    expect(colorBarra(tester, 0), isNot(ColoresApp.claro.marcaVerde));
  });

  testWidgets('la barra más alta es la del valor máximo', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [10, 50, 0, 0, 0, 0, 20], hasta: jueves)));
    await tester.pumpAndSettle();
    final alto1 = tester.getSize(find.byKey(const Key('barra_dia_1'))).height;
    final alto6 = tester.getSize(find.byKey(const Key('barra_dia_6'))).height;
    final alto2 = tester.getSize(find.byKey(const Key('barra_dia_2'))).height;
    expect(alto1, greaterThan(alto6));
    expect(alto2, 4); // sin ventas: barra mínima
  });

  testWidgets('todo en cero no falla', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [0, 0, 0, 0, 0, 0, 0], hasta: jueves)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocarla llama onTap y tiene semántica', (tester) async {
    var tocada = false;
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [1, 2, 3, 4, 5, 6, 7],
        hasta: jueves,
        onTap: () => tocada = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniGraficaSemana));
    expect(tocada, isTrue);
    expect(find.bySemanticsLabel(RegExp('Ventas de los últimos 7 días')),
        findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/screens/home/mini_grafica_semana_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar**

```dart
import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../ui/movimiento.dart';
import '../../util/formato_moneda.dart';

const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Barras de las ventas de los 7 días que terminan en [hasta]; la del día
/// elegido va en verde. Va sobre la tarjeta del día (fondo azul).
class MiniGraficaSemana extends StatelessWidget {
  const MiniGraficaSemana(
      {super.key, required this.valores, required this.hasta, this.onTap});

  final List<int> valores;
  final DateTime hasta;
  final VoidCallback? onTap;

  static const _altoMaximo = 44.0;
  static const _altoMinimo = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final maximo = valores.fold<int>(0, (m, v) => v > m ? v : m);
    final dias = [
      for (var i = 0; i < valores.length; i++)
        hasta.subtract(Duration(days: valores.length - 1 - i)),
    ];
    final descripcion = [
      for (var i = 0; i < valores.length; i++)
        '${_iniciales[dias[i].weekday - 1]} ${formatoMoneda(valores[i])}',
    ].join(', ');
    return Semantics(
      label: 'Ventas de los últimos 7 días: $descripcion',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Movimiento.duracion(context, Movimiento.larga),
          curve: Movimiento.resorte,
          builder: (context, avance, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _altoMaximo,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < valores.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            key: Key('barra_dia_$i'),
                            height: (maximo == 0 || valores[i] == 0
                                    ? _altoMinimo
                                    : (_altoMinimo +
                                        (valores[i] / maximo) *
                                            (_altoMaximo - _altoMinimo)) *
                                        avance.clamp(0.0, 1.2))
                                .clamp(_altoMinimo, _altoMaximo),
                            decoration: BoxDecoration(
                              color: i == valores.length - 1
                                  ? c.marcaVerde
                                  : c.sobreTarjetaPrincipal
                                      .withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                  bottom: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final d in dias)
                    Expanded(
                      child: Text(
                        _iniciales[d.weekday - 1],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.sobreTarjetaPrincipal.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Nota del test "V"/"J": del 3 al 9 de octubre de 2026 las iniciales son V S D L M M J, así
que "V" y "J" aparecen una vez y "M" dos veces.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/mini_grafica_semana.dart test/screens/home/mini_grafica_semana_test.dart
git commit -m "Add the seven-day mini chart for the home card"
```

---

### Task 3: Inicio tipo tablero

**Files:**
- Modify: `lib/screens/home/resumen_screen.dart`, `lib/widgets/selector_fecha.dart`
- Test: `test/screens/home/resumen_screen_test.dart`, `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `ventasDiariasProvider`, `comparacionVentas`, `TendenciaVentas` (Task 1),
  `MiniGraficaSemana` (Task 2).
- Produces: claves `comparacion_ventas`, `mini_grafica`, `barra_acciones_inicio`,
  `tarjeta_por_vendedor`.

- [ ] **Step 1: Tests (fallan)** en `resumen_screen_test.dart` (usar `montar`, `vender` y
`enTarjeta` existentes; `vender` acepta `fecha:`):

```dart
testWidgets('la tarjeta del día compara con ayer y muestra la mini gráfica',
    (tester) async {
  final hoy = DateTime.now();
  await vender(11200, fecha: hoy);
  await vender(10000, fecha: hoy.subtract(const Duration(days: 1)));
  await montar(tester);
  expect(find.text('Ventas de hoy'), findsOneWidget);
  expect(enTarjeta('tarjeta_ventas', '▲ 12 % vs. ayer'), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('tarjeta_ventas')),
      matching: find.byKey(const Key('mini_grafica'))), findsOneWidget);
});

testWidgets('otro día: título con fecha y "el día anterior"', (tester) async {
  final hoy = inicioDelDia(DateTime.now());
  await vender(5000, fecha: hoy.subtract(const Duration(days: 1)));
  await montar(tester);
  await tester.tap(find.byTooltip('Día anterior'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Ventas del '), findsOneWidget);
  expect(enTarjeta('tarjeta_ventas', 'El día anterior no hubo ventas'),
      findsOneWidget);
});

testWidgets('sin ventas ni ayer ni hoy no hay etiqueta de comparación',
    (tester) async {
  await montar(tester);
  expect(find.byKey(const Key('comparacion_ventas')), findsNothing);
});

testWidgets('Venta y Gasto quedan fijos abajo, fuera de la lista',
    (tester) async {
  await montar(tester);
  final barra = find.byKey(const Key('barra_acciones_inicio'));
  expect(find.descendant(of: barra, matching: find.byKey(const Key('boton_nueva_venta'))),
      findsOneWidget);
  expect(find.descendant(of: barra, matching: find.byKey(const Key('boton_nuevo_gasto'))),
      findsOneWidget);
  expect(find.descendant(of: find.byType(ListView),
      matching: find.byKey(const Key('boton_nueva_venta'))), findsNothing);
});

testWidgets('el admin ve Por vendedor con el enlace a reportes', (tester) async {
  await montar(tester); // ana es admin
  final tarjeta = find.byKey(const Key('tarjeta_por_vendedor'));
  await tester.scrollUntilVisible(tarjeta, 200);
  expect(find.descendant(of: tarjeta,
      matching: find.byKey(const Key('boton_ver_reportes'))), findsOneWidget);
});
```

Leer `lib/widgets/selector_fecha.dart` para usar el tooltip o la clave real del botón de día
anterior (si no tiene tooltip, buscar por `find.byIcon(Icons.chevron_left_rounded)`).
Si `montar` no tiene sesión de admin (no usa `containerConSesion`), agregar la sesión con
`sesionProvider` como en `home_screen_test.dart` para el último test.

- [ ] **Step 2: Run** `flutter test test/screens/home/` — Expected: FAIL.

- [ ] **Step 3: Implementar** en `resumen_screen.dart`:

- `build` devuelve:

```dart
return Column(
  children: [
    Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [ /* SelectorFecha, tarjetas, por vendedor */ ],
      ),
    ),
    _BarraAcciones(),
  ],
);
```

- `_BarraAcciones` (`Key('barra_acciones_inicio')`): `Material` con color `c.fondo`,
  `SafeArea(top: false)`, `Padding(fromLTRB(16, 8, 16, 8))`, `Row` con
  `Expanded(flex: 5, BotonPrincipal(key: boton_nueva_venta, texto: '+ Venta', variante: entra, …))`,
  `SizedBox(width: 12)`, `Expanded(flex: 3, BotonPrincipal(key: boton_nuevo_gasto, texto: '− Gasto', variante: peligro, …))`
  con las mismas navegaciones de hoy; sombra superior
  `BoxShadow(color: c.texto.withValues(alpha: 0.08), blurRadius: 12, offset: Offset(0, -2))`.
- `_Tarjetas` recibe además `List<int>? semana`, `bool esHoy`, `DateTime dia`,
  `VoidCallback? onVerReportes`:
  - Título: `esHoy ? 'Ventas de hoy' : 'Ventas del ${formatoFechaCorta(dia)}'` (usar el
    formateador de fecha corta que ya use `SelectorFecha`; si no existe uno con "7 oct",
    crear `String fechaCorta(DateTime d)` en `lib/util/fecha_util.dart` con meses
    `ene feb mar abr may jun jul ago sep oct nov dic`).
  - Debajo del monto, si `semana != null` y `comparacionVentas(semana[6], semana[5], esHoy:)`
    no es null: `_EtiquetaComparacion(comparacion)` con `Key('comparacion_ventas')`: para
    `sube`/`baja` una píldora (`StadiumBorder`, padding 8×2) con fondo
    `(sube ? c.entra : c.sale).withValues(alpha: 0.22)`; para el resto solo texto. Texto
    siempre `c.sobreTarjetaPrincipal` (píldora) o `suave` (75 %), 12 px w700.
  - El detalle actual ("N ventas · M fiadas", "Recibido…") se conserva.
  - Al final de la tarjeta, si `semana != null`:
    `MiniGraficaSemana(key: Key('mini_grafica'), valores: semana, hasta: dia, onTap: onVerReportes)`.
  - Ganancia y Gastos sin cambios; Por cobrar igual (ya es a todo el ancho).
- `ResumenScreen.build`: `final semanaAsync = ref.watch(ventasDiariasProvider(_dia));` y pasar
  `semana: semanaAsync.valueOrNull`, `esHoy: _dia == inicioDelDia(DateTime.now())`,
  `onVerReportes: esAdmin ? abrirReportes : null`.
- Por vendedor (solo admin, como hoy; envolver lo existente en `if (esAdmin)` si hoy se
  muestra a todos — leer el código y conservar la visibilidad actual): `Card(key: tarjeta_por_vendedor)`
  con una fila de título "Por vendedor" + `TextButton(key: boton_ver_reportes, 'Ver reportes ›')`
  y debajo la lista actual. `porVendedorAsync.when(skipLoadingOnReload: true, …)`.
- Quitar de la lista la fila de botones Venta/Gasto y el `BotonPrincipal` "Ver reportes".

`selector_fecha.dart`: envolver la fila en un contenedor píldora
(`DecoratedBox(decoration: ShapeDecoration(shape: StadiumBorder(), color: c.superficie))`),
sin cambiar su comportamiento ni sus claves.

- [ ] **Step 4: Run** `flutter test test/screens/home/` — Expected: PASS. Ajustar pruebas
existentes que buscaban "Ver reportes" como `BotonPrincipal` o los botones dentro de la lista
(deben seguir encontrándolos por clave).

- [ ] **Step 5:** `flutter test` completo y `flutter analyze` — Expected: verde / limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home lib/widgets/selector_fecha.dart lib/util test/screens/home
git commit -m "Turn the home tab into a dashboard with weekly bars and fixed sale buttons"
```

---

### Task 4: Buscador de productos

**Files:**
- Modify: `lib/util/texto_util.dart`, `lib/screens/venta/registrar_venta_screen.dart`
- Test: `test/util/texto_util_test.dart` (crear si no existe), `test/screens/venta/registrar_venta_screen_test.dart`

**Interfaces — Produces:** `String sinTildes(String texto)` (minúsculas, sin tildes, conserva ñ);
claves `buscador_productos`, `texto_sin_resultados`.

- [ ] **Step 1: Tests (fallan)**

```dart
test('sinTildes quita tildes y mayúsculas pero conserva la ñ', () {
  expect(sinTildes('Café ÁRBOL Pingüino Ñame'), 'cafe arbol pinguino ñame');
});
```

En `registrar_venta_screen_test.dart` (crear 7 productos en el test con
`db.into(db.productos).insert(ProductosCompanion.insert(nombre: …, precio: …))` antes de
`montar`; leer el helper de productos del archivo si existe):

```dart
testWidgets('el buscador filtra sin importar tildes y mayúsculas', (tester) async {
  // productos: Café, Pan, Leche, Arroz, Huevos, Azúcar, Sal
  await montar(tester);
  await tester.enterText(find.byKey(const Key('buscador_productos')), 'CAFE');
  await tester.pump();
  expect(find.text('Café'), findsOneWidget);
  expect(find.text('Pan'), findsNothing);
  expect(find.byKey(const Key('boton_otro_monto')), findsOneWidget);
});

testWidgets('sin coincidencias muestra Sin resultados', (tester) async {
  await montar(tester);
  await tester.enterText(find.byKey(const Key('buscador_productos')), 'zzz');
  await tester.pump();
  expect(find.byKey(const Key('texto_sin_resultados')), findsOneWidget);
  expect(find.byKey(const Key('boton_otro_monto')), findsOneWidget);
});

testWidgets('vaciar el ticket limpia la búsqueda', (tester) async {
  await montar(tester);
  await tester.tap(find.text('Pan'));
  await tester.enterText(find.byKey(const Key('buscador_productos')), 'caf');
  await tester.pump();
  await tester.tap(find.byKey(const Key('boton_vaciar')));
  await tester.pump();
  expect(find.text('Pan'), findsOneWidget);
});

testWidgets('con 6 productos o menos no hay buscador', (tester) async {
  // solo 3 productos
  await montar(tester);
  expect(find.byKey(const Key('buscador_productos')), findsNothing);
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**

`texto_util.dart`:

```dart
const _sinTilde = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

/// Minúsculas y sin tildes (la ñ se conserva), para buscar "cafe" y hallar "Café".
String sinTildes(String texto) => texto
    .toLowerCase()
    .split('')
    .map((letra) => _sinTilde[letra] ?? letra)
    .join();
```

`registrar_venta_screen.dart`:
- Estado `final _busqueda = TextEditingController();` (dispose) y `String _filtro = ''`.
- Antes de "PRODUCTOS", si `productos.length > 6`: `TextField(key: buscador_productos,
  controller: _busqueda, decoration: InputDecoration(hintText: 'Buscar producto…',
  prefixIcon: Icon(Icons.search_rounded)), onChanged: (t) => setState(() => _filtro = sinTildes(t.trim())))`.
  Como `productos` llega del `when`, poner el campo dentro del `data:` arriba de la grilla
  (`Column`).
- La grilla usa `productos.where((p) => _filtro.isEmpty || sinTildes(p.nombre).contains(_filtro))`.
- Si hay filtro y ningún producto coincide: `Text('Sin resultados', key: texto_sin_resultados)`
  arriba de la grilla (que solo tiene "+ Otro monto").
- `onVaciar`: `notifier.vaciar(); _busqueda.clear(); setState(() => _filtro = '');`.

- [ ] **Step 4: Run** `flutter test test/util test/screens/venta` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/util/texto_util.dart lib/screens/venta/registrar_venta_screen.dart test/util test/screens/venta
git commit -m "Add an accent-insensitive product search to the sale screen"
```

---

### Task 5: Hoja "¿Cómo paga?" y barra de cobro

**Files:**
- Create: `lib/screens/venta/hoja_como_paga.dart`, `test/screens/venta/hoja_como_paga_test.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart`, `lib/ui/mosaico.dart` (rebote de la insignia)
- Test: `test/screens/venta/registrar_venta_screen_test.dart` (migración)

**Interfaces:**
- Consumes: `TicketNotifier` (`cambiarFiado`, `cambiarMedioPago`, `elegirCliente`,
  `escribirCliente`), `Ticket` (`total`, `cantidadArticulos`, `clienteParaCobrar`),
  `SelectorCliente`, `mostrarHojaInferior`.
- Produces: `enum FormaPago { efectivo, transferencia, fiado }`,
  `Future<FormaPago?> mostrarHojaComoPaga(BuildContext context)`; claves `hoja_como_paga`,
  `pago_efectivo`, `pago_transferencia`, `pago_fiado`, `boton_fiar`.

- [ ] **Step 1: Helper de prueba y tests (fallan)**

En `registrar_venta_screen_test.dart` agregar:

```dart
/// Toca Cobrar y elige la forma de pago en la hoja.
Future<void> cobrarCon(WidgetTester tester, String clave) async {
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

/// Cobra fiado al cliente escrito.
Future<void> fiarA(WidgetTester tester, String nombre) async {
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pago_fiado')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo_cliente')), nombre);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_fiar')));
  await tester.pumpAndSettle();
}
```

Migración de los tests existentes (mismo propósito, nuevo flujo):
- Todo `tap(boton_cobrar)` que esperaba registrar de contado → `cobrarCon(tester, 'pago_efectivo')`.
- `tap(find.text('Transferencia'))` + `tap(boton_cobrar)` → `cobrarCon(tester, 'pago_transferencia')`.
- `tap(find.text('Fiado'))` + cliente + `tap(boton_cobrar)` → `fiarA(tester, nombre)` o, para
  cliente existente, abrir la hoja, `pago_fiado`, tocar `cliente_sugerido_…` y `boton_fiar`.
- "fiado sin cliente no deja cobrar": abrir hoja → `pago_fiado` → `boton_fiar` deshabilitado
  (`tester.widget<BotonPrincipal>(find.byKey(const Key('boton_fiar'))).onPressed` es null).
- "con Fiado no aparece el selector de medio de pago": reemplazar por "Nueva venta ya no muestra
  selectores arriba": `selector_tipo_venta` y `selector_medio_pago` `findsNothing`.

Tests nuevos en `registrar_venta_screen_test.dart`:

```dart
testWidgets('la hoja ofrece Efectivo, Transferencia y Fiado con el total',
    (tester) async {
  await montar(tester);
  await tester.tap(find.byKey(const Key('monto_rapido_5000')));
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  final hoja = find.byKey(const Key('hoja_como_paga'));
  expect(find.descendant(of: hoja, matching: find.text(r'Cobrar $5.000')), findsOneWidget);
  for (final k in ['pago_efectivo', 'pago_transferencia', 'pago_fiado']) {
    expect(find.byKey(Key(k)), findsOneWidget);
  }
});

testWidgets('cerrar la hoja tras escoger Fiado deja el ticket de contado',
    (tester) async {
  await montar(tester);
  await tester.tap(find.byKey(const Key('monto_rapido_5000')));
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pago_fiado')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(10, 10)); // fuera de la hoja
  await tester.pumpAndSettle();
  expect(await db.select(db.ventas).get(), isEmpty);

  await cobrarCon(tester, 'pago_efectivo');
  final venta = (await db.select(db.ventas).get()).single;
  expect(venta.esFiado, isFalse);
  expect(venta.clienteId, isNull);
});

testWidgets('doble toque en Efectivo registra una sola venta', (tester) async {
  await montar(tester);
  await tester.tap(find.byKey(const Key('monto_rapido_5000')));
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pago_efectivo')));
  await tester.tap(find.byKey(const Key('pago_efectivo')), warnIfMissed: false);
  await tester.pumpAndSettle();
  expect(await db.select(db.ventas).get(), hasLength(1));
});
```

(Usar los nombres reales de la base y de `montar` del archivo.)

- [ ] **Step 2: Run** `flutter test test/screens/venta` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`lib/screens/venta/hoja_como_paga.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ticket_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_cliente.dart';

enum FormaPago { efectivo, transferencia, fiado }

/// Pregunta cómo paga el cliente. Con Fiado, el cliente se elige dentro de la
/// hoja (queda en el ticket). Null si se cierra sin elegir.
Future<FormaPago?> mostrarHojaComoPaga(BuildContext context) {
  final ticket = ProviderScope.containerOf(context).read(ticketProvider);
  return mostrarHojaInferior<FormaPago>(
    context,
    titulo: 'Cobrar ${formatoMoneda(ticket.total)}',
    builder: (_) => const _ComoPaga(),
  );
}

class _ComoPaga extends ConsumerStatefulWidget {
  const _ComoPaga();
  @override
  ConsumerState<_ComoPaga> createState() => _ComoPagaState();
}

class _ComoPagaState extends ConsumerState<_ComoPaga> {
  var _fiado = false;
  var _elegido = false; // evita doble toque

  void _elegir(FormaPago forma) {
    if (_elegido) return;
    _elegido = true;
    Navigator.of(context).pop(forma);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final cliente = ticket.clienteParaCobrar;
    return Column(
      key: const Key('hoja_como_paga'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${plural(ticket.cantidadArticulos, 'artículo', 'artículos')} · ¿Cómo paga?',
          style: TextStyle(color: c.textoSecundario),
        ),
        const SizedBox(height: 12),
        _Opcion(
          key: const Key('pago_efectivo'),
          icono: Icons.payments_rounded,
          texto: 'Efectivo',
          color: c.entra,
          onTap: () => _elegir(FormaPago.efectivo),
        ),
        _Opcion(
          key: const Key('pago_transferencia'),
          icono: Icons.qr_code_2_rounded,
          texto: 'Transferencia (mostrar QR)',
          color: c.primario,
          onTap: () => _elegir(FormaPago.transferencia),
        ),
        _Opcion(
          key: const Key('pago_fiado'),
          icono: Icons.edit_note_rounded,
          texto: 'Fiado',
          color: c.fiado,
          seleccionada: _fiado,
          onTap: () {
            notifier.cambiarFiado(true);
            setState(() => _fiado = true);
          },
        ),
        if (_fiado) ...[
          const SizedBox(height: 8),
          SelectorCliente(
            elegido: ticket.cliente,
            onElegir: notifier.elegirCliente,
            onEscribir: notifier.escribirCliente,
            exigir: true,
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_fiar'),
            texto: cliente == null
                ? 'Fiar ${formatoMoneda(ticket.total)}'
                : 'Fiar ${formatoMoneda(ticket.total)} a ${cliente.nombre}',
            variante: VarianteBoton.entra,
            onPressed: cliente == null ? null : () => _elegir(FormaPago.fiado),
          ),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({super.key, required this.icono, required this.texto,
      required this.color, required this.onTap, this.seleccionada = false});
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: seleccionada ? color : c.borde, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(texto,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}
```

Usar el nombre real del parámetro de cliente elegido del `Ticket` (leer
`ticket_provider.dart`: `cliente` / `clienteParaCobrar`).

`registrar_venta_screen.dart`:
- Quitar `SelectorSegmentado` de tipo y medio de pago y el `SelectorCliente` de arriba (y sus
  imports si quedan sin uso).
- `_alCobrar()`:

```dart
Future<void> _alCobrar() async {
  if (_cobrando) return;
  final notifier = ref.read(ticketProvider.notifier);
  final forma = await mostrarHojaComoPaga(context);
  if (!mounted) return;
  if (forma == null) {
    notifier.cambiarFiado(false); // cerrar sin elegir no cambia el ticket
    return;
  }
  if (forma != FormaPago.fiado) {
    notifier.cambiarFiado(false);
    notifier.cambiarMedioPago(forma == FormaPago.transferencia
        ? MedioPago.transferencia
        : MedioPago.efectivo);
  }
  await _cobrar();
}
```

- `_BarraCobro`: texto fijo `'Cobrar $total'`; sin el aviso "Falta elegir el cliente"
  (queda "Agrega algo para cobrar" con el ticket vacío); `onPressed: !ticket.estaVacio &&
  !cobrando ? onCobrar : null`; `onCobrar: _alCobrar`. Contenedor flotante:
  `Material(color: c.superficie, elevation: 0, shape: RoundedRectangleBorder(borderRadius:
  BorderRadius.vertical(top: Radius.circular(24))))` con sombra
  `BoxShadow(color: c.texto.withValues(alpha: 0.08), blurRadius: 14, offset: Offset(0, -4))`,
  sin el borde superior.

`mosaico.dart`: la insignia de cantidad se envuelve en
`TweenAnimationBuilder<double>(key: ValueKey(cantidad), tween: Tween(begin: 1.25, end: 1),
duration: Movimiento.duracion(context, Movimiento.media), curve: Movimiento.resorte,
builder: (_, s, hijo) => Transform.scale(scale: s, child: hijo), child: insignia)`.

`hoja_como_paga_test.dart`: test unitario de la hoja montando `RegistrarVentaScreen` no es
necesario (cubierto arriba); crear el archivo solo con el test "Fiar deshabilitado sin
cliente y habilitado al escribir uno" montando la hoja desde un `Builder` dentro de un
`ProviderScope` con un ítem en el ticket.

- [ ] **Step 4: Run** `flutter test test/screens/venta test/ui` — Expected: PASS.

- [ ] **Step 5:** `flutter test` completo y `flutter analyze` — Expected: verde / limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/venta lib/ui/mosaico.dart test/screens/venta
git commit -m "Ask how the customer pays in a sheet after building the ticket"
```

---

### Task 6: Aplastable y "¿Quién eres?" en grilla

**Files:**
- Create: `lib/ui/aplastable.dart`, `test/ui/aplastable_test.dart`
- Modify: `lib/ui/boton_principal.dart` (usar `Aplastable`), `lib/screens/login/seleccionar_usuario_screen.dart`
- Test: `test/screens/login/seleccionar_usuario_screen_test.dart`

**Interfaces — Produces:** `Aplastable({required Widget child, bool habilitado = true})`
(público; escala 0,94 al presionar, resorte al soltar); `Hero(tag: 'avatar_{id}')` alrededor
del avatar de cada tarjeta.

- [ ] **Step 1: Tests (fallan)**

`test/ui/aplastable_test.dart`:

```dart
testWidgets('Aplastable se encoge al presionar y vuelve al soltar', (tester) async {
  await tester.pumpWidget(const MaterialApp(
      home: Center(child: Aplastable(child: SizedBox(width: 80, height: 80, child: Text('x'))))));
  double escala() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
  final g = await tester.startGesture(tester.getCenter(find.text('x')));
  await tester.pump();
  expect(escala(), 0.94);
  await g.up();
  await tester.pumpAndSettle();
  expect(escala(), 1.0);
});
```

En `seleccionar_usuario_screen_test.dart` agregar:

```dart
testWidgets('dos usuarios van en 2 columnas y uno solo a todo el ancho',
    (tester) async {
  // montar con Ana y Beto (como el test existente)
  final ana = tester.getRect(find.byKey(const Key('usuario_1')));
  final beto = tester.getRect(find.byKey(const Key('usuario_2')));
  expect(ana.top, beto.top);           // misma fila
  expect(ana.left, lessThan(beto.left));
});

testWidgets('con un solo usuario la tarjeta ocupa el ancho', (tester) async {
  // montar solo con Ana
  final ancho = tester.getSize(find.byKey(const Key('usuario_1'))).width;
  final pantalla = tester.getSize(find.byType(Scaffold)).width;
  expect(ancho, greaterThan(pantalla * 0.8));
});

testWidgets('con letra grande no se desborda', (tester) async {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  // montar con 'María Fernanda de los Ángeles' y 'Beto'
  expect(tester.takeException(), isNull);
});

testWidgets('tocar una tarjeta abre el PIN con el avatar animado', (tester) async {
  // montar con Ana
  await tester.tap(find.byKey(const Key('usuario_1')));
  await tester.pumpAndSettle();
  expect(find.text('Hola, Ana'), findsOneWidget);
  expect(find.byType(Hero), findsWidgets);
});
```

(Extraer un `montar(tester, nombres)` en el archivo con la base en memoria y
`ProviderScope` como el test actual; usar `temaClaro()` en el `MaterialApp`.)

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**

- Mover `_Aplastable`/`_AplastableState` de `boton_principal.dart` a `lib/ui/aplastable.dart`
  como `Aplastable` (con `habilitado` por defecto `true`), y que `BotonPrincipal` lo importe.
- `seleccionar_usuario_screen.dart`: reemplazar el `for … Card(ListTile)` por
  `LayoutBuilder` → si hay 1 usuario o `MediaQuery.textScalerOf(context).scale(18) > 27`
  (letra ≥ 1,5×), una columna; si no, `Wrap` de 2 columnas con ancho
  `(limites.maxWidth - 12) / 2` y `spacing/runSpacing: 12`. Cada tarjeta:

```dart
EntradaEscalonada(
  indice: i,
  child: Aplastable(
    child: Material(
      key: Key('usuario_${u.id}'),
      color: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta)),
      child: InkWell(
        borderRadius: BorderRadius.circular(radioTarjeta),
        onTap: () {
          Vibracion.toque();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => IngresarPinScreen(usuario: u)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(children: [
            Hero(tag: 'avatar_${u.id}',
                child: AvatarInicial(id: u.id, nombre: u.nombre, radio: 36)),
            const SizedBox(height: 10),
            Text(u.nombre, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(etiquetaRol(u.rol), style: TextStyle(color: c.textoSecundario)),
          ]),
        ),
      ),
    ),
  ),
)
```

- [ ] **Step 4: Run** `flutter test test/ui test/screens/login` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/aplastable.dart lib/ui/boton_principal.dart lib/screens/login/seleccionar_usuario_screen.dart test/ui/aplastable_test.dart test/screens/login/seleccionar_usuario_screen_test.dart
git commit -m "Show users as tappable cards in a grid with a hero avatar"
```

---

### Task 7: PIN con indicadores animados

**Files:**
- Create: `lib/widgets/indicadores_pin.dart`, `test/widgets/indicadores_pin_test.dart`
- Modify: `lib/screens/login/ingresar_pin_screen.dart`, `lib/widgets/teclado_numerico.dart`
- Test: `test/screens/login/ingresar_pin_screen_test.dart`

**Interfaces:**
- Consumes: `Aplastable` (Task 6), `Movimiento`, `Hero(tag: 'avatar_{id}')` (Task 6).
- Produces: `IndicadoresPin({required int llenos, int errores = 0})` — cada cambio de
  `errores` dispara la sacudida y el color `sale`; claves `indicador_pin_{i}`.

- [ ] **Step 1: Tests (fallan)**

`test/widgets/indicadores_pin_test.dart`:

```dart
Widget _app(Widget hijo, {bool reducir = false}) => MaterialApp(
    theme: temaClaro(),
    home: MediaQuery(data: MediaQueryData(disableAnimations: reducir),
        child: Scaffold(body: Center(child: hijo))));

Color colorDe(WidgetTester t, int i) =>
    (t.widget<Container>(find.byKey(Key('indicador_pin_$i'))).decoration! as BoxDecoration).color!;

testWidgets('los llenos usan el primario', (tester) async {
  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 2)));
  await tester.pumpAndSettle();
  expect(colorDe(tester, 0), ColoresApp.claro.primario);
  expect(colorDe(tester, 3), isNot(ColoresApp.claro.primario));
});

testWidgets('un error sacude y pinta de rojo, y se repite con el siguiente',
    (tester) async {
  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0)));
  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0, errores: 1)));
  await tester.pump(const Duration(milliseconds: 50));
  final x1 = tester.getTopLeft(find.byKey(const Key('indicador_pin_0'))).dx;
  expect(colorDe(tester, 0), ColoresApp.claro.sale);
  await tester.pumpAndSettle();
  final x0 = tester.getTopLeft(find.byKey(const Key('indicador_pin_0'))).dx;
  expect(x1, isNot(x0));
  expect(colorDe(tester, 0), isNot(ColoresApp.claro.sale));

  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0, errores: 2)));
  await tester.pump(const Duration(milliseconds: 50));
  expect(colorDe(tester, 0), ColoresApp.claro.sale);
  await tester.pumpAndSettle();
});

testWidgets('con reducir movimiento no se sacude pero sí se pinta de rojo',
    (tester) async {
  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0), reducir: true));
  final x0 = tester.getTopLeft(find.byKey(const Key('indicador_pin_0'))).dx;
  await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0, errores: 1), reducir: true));
  await tester.pump();
  expect(tester.getTopLeft(find.byKey(const Key('indicador_pin_0'))).dx, x0);
  expect(colorDe(tester, 0), ColoresApp.claro.sale);
});
```

En `ingresar_pin_screen_test.dart`, en el test existente tras el PIN incorrecto:
`expect(find.byType(IndicadoresPin), findsOneWidget);` y que la tecla `tecla_1` mida 76 px:
`expect(tester.getSize(find.byKey(const Key('tecla_1'))).width, 76);`.

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**

`lib/widgets/indicadores_pin.dart`:

```dart
import 'package:flutter/material.dart';

import '../ui/colores_app.dart';
import '../ui/movimiento.dart';

/// Los 4 puntos del PIN. Un llenado rebota; cada aumento de [errores] los
/// sacude y los pinta de rojo un momento.
class IndicadoresPin extends StatefulWidget {
  const IndicadoresPin({super.key, required this.llenos, this.errores = 0});
  final int llenos;
  final int errores;
  @override
  State<IndicadoresPin> createState() => _IndicadoresPinState();
}

class _IndicadoresPinState extends State<IndicadoresPin>
    with SingleTickerProviderStateMixin {
  late final _sacudida = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  var _enError = false;

  static const _pasos = [0.0, -12.0, 12.0, -8.0, 8.0, -4.0, 4.0, 0.0];

  @override
  void didUpdateWidget(IndicadoresPin anterior) {
    super.didUpdateWidget(anterior);
    if (widget.errores > anterior.errores) {
      setState(() => _enError = true);
      if (Movimiento.reducido(context)) {
        // Sin sacudida: el rojo dura lo mismo que la sacudida.
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _enError = false);
        });
      } else {
        _sacudida.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _enError = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _sacudida.dispose();
    super.dispose();
  }

  double _desplazamiento(double t) {
    final pos = t * (_pasos.length - 1);
    final i = pos.floor().clamp(0, _pasos.length - 2);
    return _pasos[i] + (_pasos[i + 1] - _pasos[i]) * (pos - i);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return AnimatedBuilder(
      animation: _sacudida,
      builder: (context, hijo) => Transform.translate(
          offset: Offset(_desplazamiento(_sacudida.value), 0), child: hijo),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${i < widget.llenos}'),
                tween: Tween(begin: i < widget.llenos ? 1.3 : 1, end: 1),
                duration: Movimiento.duracion(context, Movimiento.media),
                curve: Movimiento.resorte,
                builder: (_, s, hijo) => Transform.scale(scale: s, child: hijo),
                child: Container(
                  key: Key('indicador_pin_$i'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _enError
                        ? c.sale
                        : i < widget.llenos
                            ? c.primario
                            : c.superficie,
                    border: Border.all(
                        color: _enError ? c.sale : (i < widget.llenos ? c.primario : c.borde),
                        width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

Nota: el test "con reducir movimiento" deja un `Future.delayed` pendiente; terminar el test con
`await tester.pump(const Duration(milliseconds: 400));` para no dejar temporizadores.

`ingresar_pin_screen.dart`: estado `int _errores = 0;` que se incrementa junto a
`Vibracion.error()`; reemplazar la `Row` de puntos por
`IndicadoresPin(llenos: _pin.length, errores: _errores)`; avatar
`Hero(tag: 'avatar_${usuario.id}', child: AvatarInicial(..., radio: 44))`; el texto de error se
conserva.

`teclado_numerico.dart`: tamaño 76 (`SizedBox(width: 76, height: 76)`, el hueco vacío
`SizedBox(width: 92, height: 84)`) y envolver cada `ElevatedButton` en `Aplastable(child: …)`.

- [ ] **Step 4: Run** `flutter test test/widgets test/screens/login` — Expected: PASS.

- [ ] **Step 5:** `flutter test` completo y `flutter analyze` — Expected: verde / limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets lib/screens/login/ingresar_pin_screen.dart test/widgets test/screens/login
git commit -m "Animate the PIN dots, shake them on a wrong PIN and enlarge the keypad"
```

---

### Task 8: Modo oscuro, cierre y APK

**Files:**
- Modify: `test/screens/modo_oscuro_test.dart`, `docs/hoja-de-ruta.md`,
  `docs/superpowers/specs/2026-10-09-vecitienda-renovacion-r2a-design.md` (Estado)

- [ ] **Step 1:** En `modo_oscuro_test.dart` agregar casos con `montarOscuro`:
`SeleccionarUsuarioScreen()` y, en "Nueva venta se dibuja en oscuro", abrir la hoja
(`tap(boton_cobrar)` tras agregar `monto_rapido_5000`, luego `pago_fiado`) y verificar sin
excepciones. En el de Inicio, verificar que existen `mini_grafica` y `barra_acciones_inicio`.

- [ ] **Step 2: Run** `flutter test test/screens/modo_oscuro_test.dart` — Expected: PASS.

- [ ] **Step 3: Verificación completa** — `flutter analyze` (sin problemas), `flutter test`
(todo verde), `flutter build apk --release` (Built …app-release.apk).

- [ ] **Step 4: Documentación** — hoja de ruta: en "Hecho"
`- Renovación R2a — Inicio tipo tablero, Nueva venta con "¿Cómo paga?", "¿Quién eres?" y PIN renovados.`;
"En curso": `- Renovación: R2b (recorrido de primer uso), R3 (dinero), R4 (administración).`;
"Pendiente de verificar": agregar `renovación R2a`. Spec: `**Estado:** Implementado (falta el
recorrido manual en un celular real)`.

- [ ] **Step 5: Commit**

```bash
git add test/screens/modo_oscuro_test.dart docs
git commit -m "Check the renewed screens in dark mode and mark R2a as implemented"
```
