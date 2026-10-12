# Renovación R3b — Reportes, historial, corrección y QR — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reportes con tarjeta principal, etiquetas de cambio en píldora, tarjeta de fiado con
tendencia, barras horizontales del top y hora pico destacada; Historial con filtro por tipo,
tarjeta de resumen, agrupación por hora e íconos por tipo; corrección y cobro QR con el estilo
nuevo.

**Architecture:** Cambios de presentación sobre los datos actuales (`ComparacionReporte`,
`Reporte`, `historialProvider`, `MovimientoEditable`). El filtro por tipo del Historial es una
función pura (`filtrarPorTipo`) con su prueba. Sin cambios de repositorios ni de esquema.

**Tech Stack:** Flutter 3.47, Riverpod 2, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-12-vecitienda-renovacion-r3b-design.md`

## Global Constraints

- Sin dependencias nuevas, sin cambios de esquema ni de repositorios.
- Colores con `ColoresApp.of(context)`; animaciones con `Movimiento` (reducir movimiento).
- Contraste ≥ 4,5:1; toques ≥ 48 dp; letra grande y modo oscuro sin errores.
- **Se conservan las claves y los textos ya probados**: en Reportes todas las de la spec §1 y
  los textos "↑ N % vs. semana pasada", "Hora pico: 6 p. m. · $X", "Fiaste $X · Cobraste $Y";
  en Historial `total_ventas`, `total_gastos`, `lista_movimientos`, `movimiento_{tipo}_{id}` y
  los detalles "Contado · Ana", "Fiado · Ana", "Hielo · Beto", "Gasto · Ana"; en corrección y
  QR todas las actuales. (La spec proponía "vs. semana anterior", "Tu hora pico",
  `horaCorta` y `total_*_filtro`: se usan los textos/funciones/claves existentes —
  `etiquetaHora` de `barras_por_dia.dart` ya da "6 p. m." / "12 m." / "12 a. m.".)
- `.when` que se recargan: `skipLoadingOnReload: true`.
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- No aplicar `dart format` a archivos enteros.
- Rama `renovacion-r3b` desde `master`.

## Review Focus

- Filtro "Gastos" con el vendedor "Beto" en un día sin gastos de Beto: estado vacío "Sin gastos
  este día" y resumen solo con la línea de gastos en $0 — Task 2.
- Un movimiento anulado a las 6 p. m. como único de esa hora: el encabezado "6 p. m." aparece y
  la fila sale tachada, sin sumar — Task 2.
- Reporte con un solo producto en el top: su barra ocupa el ancho completo y no hay división
  por cero — Task 1.
- Cambio de ventas negativo grande (−100 %): la píldora roja "↓ 100 % vs. semana pasada" —
  Task 1.
- Cobro QR en modo oscuro con letra grande en un celular de 360 dp: sin desbordes y el QR
  sobre blanco — Task 4.

---

### Task 1: Reportes

**Files:**
- Modify: `lib/screens/reportes/reportes_screen.dart`, `lib/screens/reportes/barras_por_dia.dart`
- Test: `test/screens/reportes/reportes_screen_test.dart`

**Interfaces — Produces:** claves nuevas `tarjeta_fiado_reporte`, `tendencia_deuda`,
`barra_ranking_{i}`; `_TextoCambio` pasa a `_EtiquetaCambio({required int? cambio, required
String contra, bool enTarjeta = false})`.

- [ ] **Step 1: Crear la rama** — `git checkout -b renovacion-r3b`

- [ ] **Step 2: Tests (fallan)** — en `reportes_screen_test.dart` (usar los helpers existentes
para crear ventas y montar; leer el archivo antes):

```dart
testWidgets('la tarjeta de ventas es la principal y la etiqueta es una píldora',
    (tester) async {
  // mismo arreglo del test que espera '↑ 25 % vs. semana pasada'
  final tarjeta = tester.widget<Container>(find.byKey(const Key('reporte_ventas')));
  expect((tarjeta.decoration! as BoxDecoration).color, ColoresApp.claro.tarjetaPrincipal);
  expect(find.descendant(of: find.byKey(const Key('reporte_ventas')),
      matching: find.text('↑ 25 % vs. semana pasada')), findsOneWidget);
});

testWidgets('barras del top proporcionales al primero', (tester) async {
  // dos productos: A con $10.000 y B con $5.000 vendidos en la semana
  final a = tester.getSize(find.byKey(const Key('barra_ranking_0'))).width;
  final b = tester.getSize(find.byKey(const Key('barra_ranking_1'))).width;
  expect(b, closeTo(a / 2, 2));
});

testWidgets('un solo producto: su barra ocupa todo el ancho disponible',
    (tester) async {
  // un producto con ventas
  final barra = tester.getSize(find.byKey(const Key('barra_ranking_0'))).width;
  final fila = tester.getSize(find.byKey(const Key('ranking_0'))).width;
  expect(barra, closeTo(fila, 2));
});

testWidgets('la tarjeta de fiado muestra si la deuda subió', (tester) async {
  // arreglo del test existente que espera 'Fiaste $3.000 · Cobraste $1.000'
  expect(find.descendant(of: find.byKey(const Key('tarjeta_fiado_reporte')),
      matching: find.byKey(const Key('texto_fiado'))), findsOneWidget);
  final icono = tester.widget<Icon>(find.byKey(const Key('tendencia_deuda')));
  expect(icono.icon, Icons.trending_up_rounded);
  expect(icono.color, ColoresApp.claro.sale);
});
```

Para los arreglos, reutilizar las funciones auxiliares del archivo (crear producto y venta con
líneas en la semana actual; en "barras del top" vender A por 10.000 y B por 5.000).
Ajustar los tests existentes que leían `TarjetaMonto` en `reporte_ventas` (ahora es un
`Container`): el helper `en('reporte_ventas', …)` busca descendientes y sigue sirviendo.

- [ ] **Step 3: Run** `flutter test test/screens/reportes` — Expected: FAIL.

- [ ] **Step 4: Implementar** en `reportes_screen.dart` (`_Contenido`):

- `reporte_ventas` pasa a:

```dart
EntradaEscalonada(
  indice: 0,
  child: Container(
    key: const Key('reporte_ventas'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.tarjetaPrincipal,
      borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ventas', style: estiloTitulo(tamano: 14, color: suave)),
        const SizedBox(height: 4),
        Monto(r.ventas, tamano: 36, tono: TonoMonto.claro, animado: true),
        _EtiquetaCambio(
            key: const Key('cambio_ventas'),
            cambio: comparacion.cambioVentas,
            contra: contra,
            enTarjeta: true),
        const SizedBox(height: 4),
        Text('${plural(r.cantidadVentas, 'venta', 'ventas')} · '
            'promedio ${formatoMoneda(r.ventaPromedio)}',
            key: const Key('texto_promedio'),
            style: TextStyle(color: suave, fontSize: 12)),
      ],
    ),
  ),
),
```

  (se quita el `Text` de `texto_promedio` que estaba debajo de la fila de gastos/ganancia y el
  título "¿Cómo te fue?").
- `_EtiquetaCambio`: mismo texto que `_TextoCambio` (`'↑ N % $contra'`, `'↓ N % $contra'`,
  `'= $contra'`); con `enTarjeta` es una píldora (`StadiumBorder`, padding 8×2, fondo
  `entra`/`sale` al 22 % según signo, texto `sobreTarjetaPrincipal` 12 w700; `=` sin píldora,
  texto `sobreTarjetaPrincipal` al 75 %); sin `enTarjeta` es texto 12 w700 en `entra`/`sale`/
  `textoSecundario`. `null` → `SizedBox.shrink()`.
- Fila Gastos/Ganancia y fila Efectivo/Transferencia: `TarjetaMonto` como hoy (con
  `animado` heredado). Envolver cada fila en `EntradaEscalonada(indice: 1/2)`.
- Tarjeta de fiado:

```dart
Card(
  key: const Key('tarjeta_fiado_reporte'),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fiado', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Fiaste ${formatoMoneda(r.fiado)} · Cobraste ${formatoMoneda(r.cobrado)}',
            key: const Key('texto_fiado')),
        const SizedBox(height: 4),
        Row(children: [
          Flexible(
            child: Text('Deuda: ${formatoMoneda(r.deudaInicio)} → '
                '${formatoMoneda(r.deudaFin)}', key: const Key('texto_deuda')),
          ),
          if (r.deudaFin != r.deudaInicio) ...[
            const SizedBox(width: 6),
            Icon(
              r.deudaFin > r.deudaInicio
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              key: const Key('tendencia_deuda'),
              size: 18,
              color: r.deudaFin > r.deudaInicio ? c.sale : c.entra,
            ),
          ],
        ]),
      ],
    ),
  ),
),
```

  (reemplaza el título "Fiado" y los dos textos sueltos).
- Ranking: cada fila `ranking_{i}` pasa a `Column`: el texto actual (mismo contenido y
  clave en un `Container` que envuelve todo — usar `Padding(key: Key('ranking_$i'), …)` con el
  `Text` dentro, para que `getSize` mida la fila) y debajo
  `LayoutBuilder(builder: (_, l) => Align(alignment: centerLeft, child: Container(key:
  Key('barra_ranking_$i'), height: 6, width: max(4, l.maxWidth * p.dinero / r.ranking.first.dinero),
  decoration: BoxDecoration(color: i == 0 ? c.marcaVerde : c.primario, borderRadius: 99))))`.
  Si `r.ranking.first.dinero == 0`, ancho 4.
  **Nota:** el test existente busca `find.byKey(Key('ranking_$i'))` como `Text`; si lo lee
  como `Text` (`tester.widget<Text>`), mantener la clave en el `Text` y poner la barra en un
  `Column` hermano dentro de un `Padding` sin clave; en ese caso el test "un solo producto"
  compara contra el ancho del `Column` padre (`find.ancestor(of: ranking_0, matching:
  find.byType(Column)).first`).
- Hora pico: `Card` alrededor del texto `texto_hora_pico` (mismo texto) con ícono
  `Icons.schedule_rounded` en `c.primario`; las `Barras` por hora siguen debajo.
- `BarrasPorDia`/`Barras` (`barras_por_dia.dart`): envolver el ancho de cada barra en un
  `TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration:
  Movimiento.duracion(context, Movimiento.larga), curve: Movimiento.resorte)` que multiplica
  la fracción (clamp 0..1) — solo la primera vez (el builder no se re-dispara si `end` no
  cambia).
- `comparacionAsync.when(skipLoadingOnReload: true, …)`.

- [ ] **Step 5: Run** `flutter test test/screens/reportes` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/reportes test/screens/reportes
git commit -m "Renew reports with a hero sales card, change pills, debt trend and ranking bars"
```

---

### Task 2: Historial

**Files:**
- Create: `lib/screens/historial/filtro_historial.dart`, `test/screens/historial/filtro_historial_test.dart`
- Modify: `lib/screens/historial/historial_screen.dart`, `test/screens/historial/historial_screen_test.dart`

**Interfaces — Produces:**
- `enum FiltroTipo { todo, contado, fiado, gastos }`
- `List<MovimientoHistorial> filtrarPorTipo(List<MovimientoHistorial> movimientos, FiltroTipo filtro)`
- Claves `filtro_tipo_{todo|contado|fiado|gastos}`, `resumen_historial`, `texto_cantidad_movimientos`, `hora_{h}`, `icono_movimiento_{tipo}_{id}`.

- [ ] **Step 1: Tests (fallan)**

`test/screens/historial/filtro_historial_test.dart`:

```dart
import 'package:app_ventas/repositories/historial_repository.dart';
import 'package:app_ventas/screens/historial/filtro_historial.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoHistorial m(TipoMovimientoHistorial tipo, int id, {bool fiado = false}) =>
    MovimientoHistorial(
        tipo: tipo, id: id, monto: 1000, fecha: DateTime(2026, 10, 12, 10),
        usuarioId: 1, esFiado: fiado);

void main() {
  final lista = [
    m(TipoMovimientoHistorial.venta, 1),
    m(TipoMovimientoHistorial.venta, 2, fiado: true),
    m(TipoMovimientoHistorial.gasto, 3),
  ];
  test('cada filtro deja lo suyo', () {
    expect(filtrarPorTipo(lista, FiltroTipo.todo).map((x) => x.id), [1, 2, 3]);
    expect(filtrarPorTipo(lista, FiltroTipo.contado).map((x) => x.id), [1]);
    expect(filtrarPorTipo(lista, FiltroTipo.fiado).map((x) => x.id), [2]);
    expect(filtrarPorTipo(lista, FiltroTipo.gastos).map((x) => x.id), [3]);
  });
}
```

(Leer el constructor real de `MovimientoHistorial` y ajustar los parámetros obligatorios.)

En `historial_screen_test.dart` (usar el arreglo existente con venta de contado de Ana
$5.000, gasto "Hielo" de Beto $1.500 y gasto de Ana):

```dart
testWidgets('el filtro Gastos deja solo gastos y el resumen sin ventas', (tester) async {
  // arreglo de 'muestra ventas y gastos del día con usuario y totales'
  await tester.tap(find.byKey(const Key('filtro_tipo_gastos')));
  await tester.pumpAndSettle();
  expect(enLista('Contado · Ana'), findsNothing);
  expect(enLista('Hielo · Beto'), findsOneWidget);
  expect(find.byKey(const Key('total_ventas')), findsNothing);
  expect(find.byKey(const Key('total_gastos')), findsOneWidget);
});

testWidgets('Gastos + vendedor sin gastos muestra el vacío del filtro', (tester) async {
  // arreglo con solo una venta de Ana
  await tester.tap(find.byKey(const Key('filtro_tipo_gastos')));
  await tester.pumpAndSettle();
  expect(find.text('Sin gastos este día'), findsOneWidget);
  expect(enTotal('total_gastos', r'$0'), findsOneWidget);
});

testWidgets('agrupa por hora y cuenta los movimientos', (tester) async {
  // venta a las 18:10, gasto a las 18:40 y venta a las 9:05 del mismo día
  expect(find.byKey(const Key('hora_18')), findsOneWidget);
  expect(find.byKey(const Key('hora_9')), findsOneWidget);
  expect(tester.getTopLeft(find.byKey(const Key('hora_18'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('hora_9'))).dy));
  expect(find.text('3 movimientos'), findsOneWidget);
});

testWidgets('el ícono depende del tipo', (tester) async {
  // venta de contado (id v), venta fiada (id f), gasto (id g)
  Color color(String clave) => (tester.widget<Container>(find.byKey(Key(clave)))
          .decoration! as BoxDecoration).color!;
  final c = ColoresApp.claro;
  expect(color('icono_movimiento_venta_$v'), c.entra.withValues(alpha: 0.15));
  expect(color('icono_movimiento_venta_$f'), c.fiado.withValues(alpha: 0.15));
  expect(color('icono_movimiento_gasto_$g'), c.sale.withValues(alpha: 0.15));
});
```

(Insertar las ventas/gastos con `db.into(db.ventas)` / `db.into(db.gastos)` como hace el
archivo; para la venta fiada crear un cliente.)

- [ ] **Step 2: Run** `flutter test test/screens/historial` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`lib/screens/historial/filtro_historial.dart`:

```dart
import '../../repositories/historial_repository.dart';

/// Qué tipo de movimientos muestra el Historial.
enum FiltroTipo { todo, contado, fiado, gastos }

List<MovimientoHistorial> filtrarPorTipo(
        List<MovimientoHistorial> movimientos, FiltroTipo filtro) =>
    [
      for (final m in movimientos)
        if (switch (filtro) {
          FiltroTipo.todo => true,
          FiltroTipo.contado =>
            m.tipo == TipoMovimientoHistorial.venta && !m.esFiado,
          FiltroTipo.fiado =>
            m.tipo == TipoMovimientoHistorial.venta && m.esFiado,
          FiltroTipo.gastos => m.tipo == TipoMovimientoHistorial.gasto,
        })
          m,
    ];
```

`historial_screen.dart`:
- Estado `FiltroTipo _tipo = FiltroTipo.todo;`.
- Bajo el `SelectorFecha`, una fila horizontal de `ChoiceChip`s de tipo (`filtro_tipo_*`:
  "Todo", "Contado", "Fiado", "Gastos") antes de la fila de vendedores actual.
- En `data:`: `final visibles = filtrarPorTipo(movimientos, _tipo);` y los totales se calculan
  sobre `visibles` (sin anulados, como hoy).
- Tarjeta de resumen (reemplaza la `Row` de dos `TarjetaMonto`):

```dart
Card(
  key: const Key('resumen_historial'),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tipo != FiltroTipo.gastos)
          Row(key: const Key('total_ventas'), children: [
            const Expanded(child: Text('Ventas')),
            Monto(totalVentas, tamano: 18, tono: TonoMonto.entra, animado: true),
          ]),
        if (_tipo == FiltroTipo.todo || _tipo == FiltroTipo.gastos)
          Row(key: const Key('total_gastos'), children: [
            const Expanded(child: Text('Gastos')),
            Monto(totalGastos, tamano: 18, tono: TonoMonto.sale, animado: true),
          ]),
        const SizedBox(height: 4),
        Text(plural(visibles.length, 'movimiento', 'movimientos'),
            key: const Key('texto_cantidad_movimientos'),
            style: TextStyle(fontSize: 12, color: c.textoSecundario)),
      ],
    ),
  ),
),
```

- Vacío según filtro: `titulo` = todo "Sin movimientos este día", contado "Sin ventas de
  contado este día", fiado "Sin ventas fiadas este día", gastos "Sin gastos este día".
- Lista (`lista_movimientos`, ahora `Column` dentro de `Card`): recorrer `visibles` (ya vienen
  del más reciente al más antiguo; si no, ordenarlas por `fecha` descendente) e insertar un
  encabezado `Padding(key: Key('hora_${m.fecha.hour}'), child: Text(etiquetaHora(hora), 13
  w700 secundario))` cuando cambia la hora; filas en `EntradaEscalonada(indice: i)`.
- `_MovimientoTile`: `leading` = `Container(key: Key('icono_movimiento_${tipo}_${id}'),
  width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape:
  circle), child: Icon(icono, color: color, size: 20))` con (color, icono): gasto
  `(c.sale, Icons.call_made_rounded)`, fiado `(c.fiado, Icons.menu_book_rounded)`, contado
  `(c.entra, Icons.shopping_cart_rounded)`; anulado: color `c.textoSecundario` con el mismo
  ícono. `title`: el texto de detalle actual (`'$detalle · vendedor'`), con la etiqueta QR si
  aplica; si es fiado y hay `nombreCliente`, una línea más con el nombre (12 px secundario);
  la corrección como hoy. `trailing`: `Monto(monto, tamano: 16, tono: …, tachado: anulado)`.
- Importar `etiquetaHora` de `../reportes/barras_por_dia.dart`.
- `movimientosAsync.when(skipLoadingOnReload: true, …)`.

Ajustar los tests existentes que usan `enTotal('total_ventas', …)`: siguen funcionando
(descendientes de la `Row` con esa clave). Los que esperan el monto dentro de
`lista_movimientos` también (ahora en `trailing`).

- [ ] **Step 4: Run** `flutter test test/screens/historial` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/historial test/screens/historial
git commit -m "Add type filters, a summary card, hourly groups and type icons to the history"
```

---

### Task 3: Hoja de corrección

**Files:**
- Modify: `lib/screens/correccion/hoja_movimiento.dart`
- Test: `test/screens/correccion/` (archivo existente de la hoja)

**Interfaces:** sin nuevas; clave nueva `cabecera_movimiento` (ícono).

- [ ] **Step 1: Test (falla)** en el archivo de pruebas de la hoja:

```dart
testWidgets('la cabecera lleva el ícono y el color del tipo', (tester) async {
  // abrir la hoja de un gasto con el helper existente
  final cabecera = tester.widget<Container>(find.byKey(const Key('cabecera_movimiento')));
  expect((cabecera.decoration! as BoxDecoration).color,
      ColoresApp.claro.sale.withValues(alpha: 0.15));
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar** en el `build` de la vista de detalle (línea ~337): arriba del
`Monto(_m.monto, tamano: 32, …)`, una `Row` con
`Container(key: cabecera_movimiento, 40×40, círculo, color del tipo al 15 %, Icon del tipo)` —
tipo `gasto` → `(c.sale, call_made_rounded)`, `abono` → `(c.entra, payments_rounded)`, `venta`
fiada → `(c.fiado, menu_book_rounded)`, `venta` de contado → `(c.entra,
shopping_cart_rounded)` (leer en `MovimientoEditable` el campo que indica fiado) — y el `Monto`
con `tono` del tipo (`sale`/`entra`/`fiado`). El botón `boton_anular` pasa a
`BotonPrincipal(key: boton_anular, texto: 'Anular', variante: VarianteBoton.peligro, …)`
conservando su `onPressed`; separación 12 entre botones.

- [ ] **Step 4: Run** `flutter test test/screens/correccion test/screens/historial test/screens/fiado` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/correccion test/screens/correccion
git commit -m "Give the correction sheet a typed header and themed buttons"
```

---

### Task 4: Cobro QR

**Files:**
- Modify: `lib/screens/qr/cobro_qr_screen.dart`
- Test: `test/screens/qr/cobro_qr_screen_test.dart`

**Interfaces:** claves nuevas `tarjeta_monto_qr`, `tarjeta_imagen_qr`.

- [ ] **Step 1: Tests (fallan)**

```dart
testWidgets('el monto y el QR van en tarjetas; el QR sobre blanco', (tester) async {
  await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
  await abrir(tester, tema: temaOscuro());
  expect(find.descendant(of: find.byKey(const Key('tarjeta_monto_qr')),
      matching: find.text(r'$12.000')), findsOneWidget);
  final qr = tester.widget<Container>(find.byKey(const Key('tarjeta_imagen_qr')));
  expect((qr.decoration! as BoxDecoration).color, ColoresApp.blancoMarca);
});

testWidgets('con letra grande en 360 dp no se desborda', (tester) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
  await abrir(tester, tema: temaOscuro());
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**: el `Monto(widget.monto, tamano: 44)` dentro de
`Container(key: tarjeta_monto_qr, padding: 16, decoration: BoxDecoration(color:
c.primarioSuave, borderRadius: radioTarjeta))`; la imagen del QR dentro de
`Container(key: tarjeta_imagen_qr, padding: 16, decoration: BoxDecoration(color:
ColoresApp.blancoMarca, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color:
c.texto.withValues(alpha: 0.08), blurRadius: 16, offset: Offset(0, 4))]))`; "Recibido"
`BotonPrincipal` variante `entra`, "Cancelar" variante `contorno` (conservar claves y
resultados). La pantalla sigue con `Theme(data: temaClaro())`, así que `c` es la paleta clara.

- [ ] **Step 4: Run** `flutter test test/screens/qr test/screens/venta test/screens/fiado` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/qr test/screens/qr
git commit -m "Frame the QR payment amount and code in cards"
```

---

### Task 5: Modo oscuro, cierre y APK

**Files:**
- Modify: `test/screens/modo_oscuro_test.dart`, `docs/hoja-de-ruta.md`,
  `docs/superpowers/specs/2026-10-12-vecitienda-renovacion-r3b-design.md` (Estado)

- [ ] **Step 1:** En `modo_oscuro_test.dart`: `HistorialScreen` (envuelta en `Scaffold`) con
una venta y un gasto, también con `escalaLetra: 1.6`; `ReportesScreen` ya existe — agregar
una venta con producto para que se vean ranking y hora pico.

- [ ] **Step 2: Run** `flutter test test/screens/modo_oscuro_test.dart` — Expected: PASS.

- [ ] **Step 3: Verificación completa** — `flutter analyze`, `flutter test`,
`flutter build apk --release`.

- [ ] **Step 4: Documentación** — hoja de ruta: "Hecho" + `- Renovación R3b — reportes
renovados, historial con filtros por tipo y por hora, corrección y cobro QR con el estilo nuevo.`;
"En curso": `- Renovación: R4 (administración).`; "Pendiente de verificar": agregar
`renovación R3b`. Spec: `**Estado:** Implementado (falta el recorrido manual en un celular real)`.

- [ ] **Step 5: Commit**

```bash
git add test docs
git commit -m "Check reports and history in dark mode and mark R3b as implemented"
```
