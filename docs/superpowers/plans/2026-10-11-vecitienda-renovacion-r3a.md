# Renovación R3a — Fiado y gasto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lista de fiado con tarjeta principal, buscador, orden y antigüedad por colores;
detalle del cliente con tarjeta de deuda, línea de tiempo con saldo acumulado y abono rápido;
nuevo gasto con categorías.

**Architecture:** Tres funciones puras nuevas (`saldosAcumulados`, `nivelAntiguedad` y
`aplicarCategoria`) con sus pruebas, y tres pantallas reescritas sobre los datos que ya
existen (`clientesConDeudaProvider`, `clientesAlDiaProvider`, `movimientosClienteProvider`,
`saldoClienteProvider`). Sin cambios de repositorios ni de esquema.

**Tech Stack:** Flutter 3.47, Riverpod 2, Drift, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-11-vecitienda-renovacion-r3a-design.md`

## Global Constraints

- Sin dependencias nuevas ni cambios de esquema; los repositorios no cambian.
- Colores solo con `ColoresApp.of(context)`; duraciones de `Movimiento`; reducir movimiento.
- Contraste ≥ 4,5:1; toques ≥ 48 dp; letra grande y modo oscuro sin errores.
- Se conservan las claves `tarjeta_te_deben`, `cliente_deuda_{id}`, `cliente_al_dia_{id}`,
  `tarjeta_saldo_cliente` (la spec la llama `tarjeta_deuda_cliente`; se conserva la existente),
  `boton_registrar_abono`, `boton_confirmar_abono`, `selector_medio_abono`,
  `movimiento_fiado_{venta|abono}_{id}`, `campo_descripcion_gasto`, `boton_registrar_gasto`.
- `.when` de datos que se recargan: `skipLoadingOnReload: true`.
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- No aplicar `dart format` a archivos enteros.
- Rama `renovacion-r3a` desde `master`.

## Review Focus

- Un abono que deja al cliente en 0 mientras se ve su detalle: la tarjeta pasa a "Al día", el
  botón desaparece y el cliente se va a "Al día" en la lista — Task 4.
- Buscar en la lista y luego cambiar el orden: el filtro se mantiene — Task 2.
- Escribir una descripción, elegir "Mercancía" y luego "Servicios": queda
  "Servicios · {texto}", sin acumular categorías — Task 1/Task 5.
- Movimientos el mismo día de un cliente con abonos mayores que una venta (saldo a favor a
  mitad de la historia): "Quedó debiendo" muestra "Saldo a favor" en ese punto — Task 1.
- Deuda muy pequeña ($100): el chip "Mitad" no aparece y "Todo" funciona — Task 4.

---

### Task 1: Funciones puras (saldos, antigüedad, categorías)

**Files:**
- Create: `lib/util/saldos_fiado.dart`, `lib/util/categorias_gasto.dart`,
  `test/util/saldos_fiado_test.dart`, `test/util/categorias_gasto_test.dart`
- Modify: `lib/util/fecha_util.dart`, `test/util/fecha_util_test.dart`

**Interfaces — Produces:**
- `Map<(TipoMovimientoFiado, int), int> saldosAcumulados(List<MovimientoFiado> movimientos)`
- `enum NivelAntiguedad { reciente, media, vieja }`;
  `NivelAntiguedad nivelAntiguedad(DateTime desde, DateTime hoy)`;
  `int diasDesde(DateTime desde, DateTime hoy)`
- `const categoriasGasto = ['Mercancía', 'Servicios', 'Arriendo', 'Transporte']` (+ "Otro" en la UI);
  `String? categoriaDe(String descripcion)`;
  `String aplicarCategoria(String descripcion, String? categoria)` (null = quitar)
- `String fechaCortaConAnio(DateTime fecha, DateTime hoy)` ("7 oct" o "7 oct 2025")

- [ ] **Step 1: Crear la rama** — `git checkout -b renovacion-r3a`

- [ ] **Step 2: Tests (fallan)**

`test/util/saldos_fiado_test.dart`:

```dart
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/util/saldos_fiado.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoFiado mov(TipoMovimientoFiado tipo, int id, int monto, int dia,
        {bool anulado = false}) =>
    MovimientoFiado(
        tipo: tipo,
        id: id,
        monto: monto,
        fecha: DateTime(2026, 10, dia, 10),
        usuarioId: 1,
        anulado: anulado);

const venta = TipoMovimientoFiado.venta;
const abono = TipoMovimientoFiado.abono;

void main() {
  test('acumula del más antiguo al más reciente, sin importar el orden dado', () {
    final saldos = saldosAcumulados([
      mov(abono, 2, 3000, 3),
      mov(venta, 1, 5000, 1),
      mov(venta, 3, 2000, 5),
    ]);
    expect(saldos[(venta, 1)], 5000);
    expect(saldos[(abono, 2)], 2000);
    expect(saldos[(venta, 3)], 4000);
  });

  test('los anulados no cuentan ni tienen saldo', () {
    final saldos = saldosAcumulados([
      mov(venta, 1, 5000, 1),
      mov(venta, 2, 9000, 2, anulado: true),
      mov(abono, 3, 1000, 3),
    ]);
    expect(saldos.containsKey((venta, 2)), isFalse);
    expect(saldos[(abono, 3)], 4000);
  });

  test('puede quedar saldo a favor (negativo)', () {
    final saldos = saldosAcumulados([
      mov(venta, 1, 2000, 1),
      mov(abono, 2, 5000, 2),
    ]);
    expect(saldos[(abono, 2)], -3000);
  });

  test('misma fecha: venta antes que abono', () {
    final saldos = saldosAcumulados([
      MovimientoFiado(tipo: abono, id: 9, monto: 1000,
          fecha: DateTime(2026, 10, 1, 10), usuarioId: 1),
      MovimientoFiado(tipo: venta, id: 8, monto: 3000,
          fecha: DateTime(2026, 10, 1, 10), usuarioId: 1),
    ]);
    expect(saldos[(venta, 8)], 3000);
    expect(saldos[(abono, 9)], 2000);
  });
}
```

`test/util/categorias_gasto_test.dart`:

```dart
import 'package:app_ventas/util/categorias_gasto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poner categoría en descripción vacía o con texto', () {
    expect(aplicarCategoria('', 'Mercancía'), 'Mercancía');
    expect(aplicarCategoria('hielo', 'Mercancía'), 'Mercancía · hielo');
    expect(aplicarCategoria('  hielo ', 'Servicios'), 'Servicios · hielo');
  });

  test('cambiar de categoría reemplaza la anterior', () {
    expect(aplicarCategoria('Mercancía · hielo', 'Servicios'), 'Servicios · hielo');
    expect(aplicarCategoria('Mercancía', 'Arriendo'), 'Arriendo');
  });

  test('quitar la categoría deja el texto', () {
    expect(aplicarCategoria('Transporte · taxi', null), 'taxi');
    expect(aplicarCategoria('Transporte', null), '');
    expect(aplicarCategoria('taxi', null), 'taxi');
  });

  test('categoriaDe reconoce solo categorías al inicio', () {
    expect(categoriaDe('Mercancía · hielo'), 'Mercancía');
    expect(categoriaDe('Mercancía'), 'Mercancía');
    expect(categoriaDe('hielo'), isNull);
    expect(categoriaDe('Mercancías varias'), isNull);
  });
}
```

En `test/util/fecha_util_test.dart` agregar:

```dart
test('diasDesde y nivelAntiguedad en los bordes 7/8 y 30/31', () {
  final hoy = DateTime(2026, 10, 31, 18);
  DateTime hace(int d) => DateTime(2026, 10, 31 - d, 9);
  expect(diasDesde(hace(0), hoy), 0);
  expect(nivelAntiguedad(hace(7), hoy), NivelAntiguedad.reciente);
  expect(nivelAntiguedad(hace(8), hoy), NivelAntiguedad.media);
  expect(nivelAntiguedad(hace(30), hoy), NivelAntiguedad.media);
  expect(nivelAntiguedad(hace(31), hoy), NivelAntiguedad.vieja);
});

test('fechaCortaConAnio solo agrega el año si no es el actual', () {
  final hoy = DateTime(2026, 10, 11);
  expect(fechaCortaConAnio(DateTime(2026, 10, 7), hoy), '7 oct');
  expect(fechaCortaConAnio(DateTime(2025, 10, 7), hoy), '7 oct 2025');
});
```

- [ ] **Step 3: Run** `flutter test test/util` — Expected: FAIL de compilación.

- [ ] **Step 4: Implementar**

`lib/util/saldos_fiado.dart`:

```dart
import '../repositories/fiado_repository.dart';

/// Saldo del cliente después de cada movimiento no anulado, clave
/// (tipo, id). Recorre del más antiguo al más reciente; con la misma fecha,
/// la venta va antes que el abono. Negativo = saldo a favor.
Map<(TipoMovimientoFiado, int), int> saldosAcumulados(
    List<MovimientoFiado> movimientos) {
  final orden = [
    for (final m in movimientos)
      if (!m.anulado) m,
  ]..sort((a, b) {
      final porFecha = a.fecha.compareTo(b.fecha);
      if (porFecha != 0) return porFecha;
      return a.tipo.index.compareTo(b.tipo.index); // venta (0) antes que abono
    });
  var saldo = 0;
  return {
    for (final m in orden)
      (m.tipo, m.id): saldo +=
          m.tipo == TipoMovimientoFiado.venta ? m.monto : -m.monto,
  };
}
```

`lib/util/categorias_gasto.dart`:

```dart
/// Categorías rápidas de gasto; se guardan al inicio de la descripción
/// ("Mercancía · hielo"). "Otro" es la ausencia de categoría.
const categoriasGasto = ['Mercancía', 'Servicios', 'Arriendo', 'Transporte'];

const _separador = ' · ';

/// Categoría al inicio de [descripcion], o null.
String? categoriaDe(String descripcion) {
  for (final c in categoriasGasto) {
    if (descripcion == c || descripcion.startsWith('$c$_separador')) return c;
  }
  return null;
}

/// [descripcion] con [categoria] al inicio (reemplazando la que hubiera);
/// con null, sin categoría.
String aplicarCategoria(String descripcion, String? categoria) {
  final actual = categoriaDe(descripcion.trim());
  var resto = descripcion.trim();
  if (actual != null) {
    resto = resto == actual ? '' : resto.substring(actual.length + _separador.length);
  }
  resto = resto.trim();
  if (categoria == null) return resto;
  return resto.isEmpty ? categoria : '$categoria$_separador$resto';
}
```

`lib/util/fecha_util.dart` (debajo de `fechaCorta`):

```dart
/// "7 oct", o "7 oct 2025" si no es del año de [hoy].
String fechaCortaConAnio(DateTime fecha, DateTime hoy) => fecha.year == hoy.year
    ? fechaCorta(fecha)
    : '${fechaCorta(fecha)} ${fecha.year}';

/// Días calendario entre [desde] y [hoy].
int diasDesde(DateTime desde, DateTime hoy) =>
    inicioDelDia(hoy).difference(inicioDelDia(desde)).inDays;

/// Qué tan vieja es una deuda: hasta 7 días, de 8 a 30, o más de 30.
enum NivelAntiguedad { reciente, media, vieja }

NivelAntiguedad nivelAntiguedad(DateTime desde, DateTime hoy) {
  final dias = diasDesde(desde, hoy);
  if (dias <= 7) return NivelAntiguedad.reciente;
  if (dias <= 30) return NivelAntiguedad.media;
  return NivelAntiguedad.vieja;
}
```

Nota: `difference().inDays` entre dos `inicioDelDia` es exacto (Colombia sin horario de
verano); si `inDays` diera 30 por 23 h, usar `.round()` de `inHours / 24`.

- [ ] **Step 5: Run** `flutter test test/util` — Expected: PASS; `flutter analyze` limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/util test/util
git commit -m "Add running balances, debt age and expense category helpers"
```

---

### Task 2: Lista de fiado

**Files:**
- Modify: `lib/screens/fiado/lista_fiado_screen.dart`, `test/screens/fiado/lista_fiado_screen_test.dart`

**Interfaces:**
- Consumes: `nivelAntiguedad`, `NivelAntiguedad`, `diasDesde` (Task 1), `sinTildes`
  (`lib/util/texto_util.dart`), `SelectorSegmentado`, `EntradaEscalonada`, `Monto(animado:)`.
- Produces: claves `texto_mayor_deuda`, `buscador_fiado`, `texto_sin_resultados_fiado`,
  `selector_orden_fiado`, `antiguedad_{id}`, `boton_al_dia`.

- [ ] **Step 1: Tests (fallan)** — en `lista_fiado_screen_test.dart` agregar un helper

```dart
/// Crea un cliente con una venta fiada de [monto] hace [dias] días.
Future<int> deudor(String nombre, int monto, int dias) async {
  final ana = await usuario();
  final id = await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: nombre));
  final hoy = DateTime.now();
  await db.into(db.ventas).insert(VentasCompanion.insert(
      monto: monto,
      fecha: DateTime(hoy.year, hoy.month, hoy.day - dias, 10),
      esFiado: const Value(true),
      clienteId: Value(id),
      usuarioId: ana));
  return id;
}
```

(`usuario()` crea o reutiliza un usuario Ana; agregarlo con una variable `int? _ana`.)
Cambiar `montar` para usar `theme: temaClaro()` y la vista 1080×2400 a 2,625.

```dart
testWidgets('ordena por mayor deuda y por más antigua', (tester) async {
  await deudor('Ana María', 3000, 40);
  await deudor('Beto', 9000, 2);
  await deudor('Carla', 5000, 10);
  await montar(tester);
  List<String> orden() => tester
      .widgetList<Text>(find.descendant(
          of: find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('cliente_deuda_')),
          matching: find.byKey(const Key('nombre_cliente'))))
      .map((t) => t.data!)
      .toList();
  expect(orden(), ['Beto', 'Carla', 'Ana María']);
  expect(find.text(r'Mayor deuda: Beto $9.000'), findsOneWidget);
  await tester.tap(find.text('Más antigua'));
  await tester.pumpAndSettle();
  expect(orden(), ['Ana María', 'Carla', 'Beto']);
});

testWidgets('el buscador ignora tildes y se mantiene al cambiar el orden',
    (tester) async {
  for (final n in ['Ángela', 'Beto', 'Carla', 'Darío', 'Elsa', 'Fabio']) {
    await deudor(n, 1000, 1);
  }
  await montar(tester);
  await tester.enterText(find.byKey(const Key('buscador_fiado')), 'angel');
  await tester.pump();
  expect(find.text('Ángela'), findsOneWidget);
  expect(find.text('Beto'), findsNothing);
  await tester.tap(find.text('Más antigua'));
  await tester.pumpAndSettle();
  expect(find.text('Beto'), findsNothing);
  await tester.enterText(find.byKey(const Key('buscador_fiado')), 'zzz');
  await tester.pump();
  expect(find.byKey(const Key('texto_sin_resultados_fiado')), findsOneWidget);
});

testWidgets('con 5 clientes o menos no hay buscador', (tester) async {
  for (final n in ['A', 'B', 'C', 'D', 'E']) {
    await deudor(n, 1000, 1);
  }
  await montar(tester);
  expect(find.byKey(const Key('buscador_fiado')), findsNothing);
});

testWidgets('la etiqueta de antigüedad cambia de color con los días',
    (tester) async {
  final reciente = await deudor('Uno', 1000, 7);
  final media = await deudor('Dos', 1000, 8);
  final vieja = await deudor('Tres', 1000, 31);
  await montar(tester);
  Color fondo(int id) => (tester
          .widget<Container>(find.byKey(Key('antiguedad_$id')))
          .decoration! as BoxDecoration)
      .color!;
  final c = ColoresApp.claro;
  expect(fondo(reciente), c.primarioSuave);
  expect(fondo(media), c.fiadoSuave);
  expect(fondo(vieja), c.sale.withValues(alpha: 0.15));
});
```

En el test existente `'quien ya pagó todo aparece en Al día y abre su detalle'`, antes de
tocar `cliente_al_dia_$pedro`, insertar:

```dart
expect(find.byKey(Key('cliente_al_dia_$pedro')), findsNothing);
expect(find.text('Al día (1)'), findsOneWidget);
await tester.tap(find.byKey(const Key('boton_al_dia')));
await tester.pumpAndSettle();
```

(así ese test cubre que "Al día" empieza cerrado y se abre).

- [ ] **Step 2: Run** `flutter test test/screens/fiado/lista_fiado_screen_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar** — `ListaFiadoScreen` pasa a `ConsumerStatefulWidget`:

- Estado: `bool _porAntiguedad = false`, `String _filtro = ''`, `bool _verAlDia = false`,
  `TextEditingController _busqueda` (dispose).
- Orden:

```dart
List<ClienteConSaldo> _ordenar(List<ClienteConSaldo> clientes) {
  final lista = [
    for (final c in clientes)
      if (_filtro.isEmpty || sinTildes(c.cliente.nombre).contains(_filtro)) c,
  ];
  lista.sort(_porAntiguedad
      ? (a, b) {
          final f = a.fechaDeudaMasAntigua!.compareTo(b.fechaDeudaMasAntigua!);
          return f != 0 ? f : b.saldo.compareTo(a.saldo);
        }
      : (a, b) {
          final s = b.saldo.compareTo(a.saldo);
          return s != 0
              ? s
              : a.cliente.nombre.toLowerCase().compareTo(b.cliente.nombre.toLowerCase());
        });
  return lista;
}
```

- Tarjeta "Te deben" (`tarjeta_te_deben`): `Container` con `c.tarjetaPrincipal`, radio
  `radioTarjetaPrincipal`, padding 16: "Te deben" (estiloTitulo 14, 75 %),
  `Monto(total, tamano: 36, tono: TonoMonto.claro, animado: true)`, "N clientes" (12, 75 %) y,
  si hay clientes, `Text('Mayor deuda: ${mayor.cliente.nombre} ${formatoMoneda(mayor.saldo)}',
  key: texto_mayor_deuda)` donde `mayor` es el de saldo máximo (empate por nombre).
- Buscador si `clientes.length > 5`; orden si `clientes.length >= 2`
  (`SelectorSegmentado<bool>(key: selector_orden_fiado, opciones: {false: 'Mayor deuda',
  true: 'Más antigua'})`).
- Si el filtro no deja nadie: `Text('Sin resultados', key: texto_sin_resultados_fiado)`.
- Cada cliente: `EntradaEscalonada(indice: i, child: Card(child: ListTile(key:
  cliente_deuda_{id}, leading: AvatarInicial, title: Text(nombre, key: const
  Key('nombre_cliente'), …), subtitle: _EtiquetaAntiguedad(id, fecha, hoy), trailing:
  Monto(saldo, tamano: 16, tono: fiado), onTap: abrir)))`.
- `_EtiquetaAntiguedad`: `Align(alignment: centerLeft, child: Container(key:
  antiguedad_{id}, margin: top 4, padding: 8×2, decoration: BoxDecoration(color: fondo,
  borderRadius: 99), child: Text(textoDebeDesde(fecha, hoy), style: 12 w600 color: texto)))`
  con `(fondo, texto)` = reciente `(c.primarioSuave, c.textoSecundario)`, media
  `(c.fiadoSuave, c.fiado)`, vieja `(c.sale.withValues(alpha: 0.15), c.sale)`.
- "Al día": `ListTile(key: boton_al_dia, title: Text('Al día (${alDia.length})'), trailing:
  Icon(_verAlDia ? expand_less : expand_more), onTap: () => setState(() => _verAlDia = !_verAlDia))`
  y las filas actuales solo si `_verAlDia`.
- `clientesAsync.when(skipLoadingOnReload: true, …)`.

- [ ] **Step 4: Run** `flutter test test/screens/fiado` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/fiado/lista_fiado_screen.dart test/screens/fiado/lista_fiado_screen_test.dart
git commit -m "Renew the credit list with a hero card, search, sorting and debt age"
```

---

### Task 3: Detalle del cliente — tarjeta y línea de tiempo

**Files:**
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart`, `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `saldosAcumulados`, `fechaCortaConAnio` (Task 1), `textoDebeDesde`, `formatoHora`.
- Produces: claves `linea_tiempo`, `encabezado_dia_{yyyy-mm-dd}`,
  `saldo_tras_{venta|abono}_{id}`; la tarjeta conserva `tarjeta_saldo_cliente`.

- [ ] **Step 1: Tests (fallan)** — ajustar y agregar en `detalle_cliente_screen_test.dart`
(el cliente del montaje debe $5.000 desde el 01/09/2026 10:00):

```dart
testWidgets('tarjeta de la deuda con desde cuándo y el botón dentro', (tester) async {
  await montarDetalle(tester);
  expect(saldo(r'$5.000'), findsOneWidget);
  expect(saldo('Don Pedro'), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('tarjeta_saldo_cliente')),
      matching: find.byKey(const Key('boton_registrar_abono'))), findsOneWidget);
});

testWidgets('línea de tiempo con encabezado de día y saldo tras cada movimiento',
    (tester) async {
  final clienteId = await montarDetalle(tester);
  final usuarioId = (await db.select(db.usuarios).getSingle()).id;
  final pagoId = await FiadoRepository(db).registrarPago(
      clienteId: clienteId, monto: 2000, usuarioId: usuarioId);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('linea_tiempo')), findsOneWidget);
  expect(find.text('Hoy'), findsOneWidget);           // el abono es de hoy
  expect(find.text('1 sep'), findsOneWidget);         // la venta
  expect(find.descendant(of: find.byKey(Key('saldo_tras_abono_$pagoId')),
      matching: find.text(r'Quedó debiendo $3.000')), findsOneWidget);
});
```

(Si `registrarPago` no devuelve el id, leerlo con `(await db.select(db.pagosFiado).get()).single.id`.)

Ajustes a pruebas existentes:
- `'muestra el saldo y los movimientos del cliente'`: quitar `find.text('Movimientos')` y
  `find.text('01/09/2026 10:00')`; esperar `find.text('Venta fiada')`, `find.text('10:00')` y
  `find.text('1 sep')`.
- `'con saldo a favor…'`: `saldo('Saldo a favor $3.000')` (texto completo) y que no haya
  `boton_registrar_abono`.
- Los que leen `onPressed` nulo de `boton_registrar_abono` con saldo 0 pasan a
  `findsNothing`.

- [ ] **Step 2: Run** `flutter test test/screens/fiado/detalle_cliente_screen_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar**

Tarjeta (reemplaza el `Container` actual y el `BotonPrincipal` de abajo):

```dart
Container(
  key: const Key('tarjeta_saldo_cliente'),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: c.tarjetaPrincipal,
    borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(cliente.nombre, style: estiloTitulo(tamano: 14, color: suave)),
      const SizedBox(height: 4),
      Monto(saldo.abs(), tamano: 36, tono: TonoMonto.claro, animado: true),
      const SizedBox(height: 4),
      Text(
        saldo > 0
            ? textoDebeDesde(fechaDeuda, DateTime.now())
            : saldo == 0
                ? 'Al día'
                : 'Saldo a favor ${formatoMoneda(-saldo)}',
        style: TextStyle(color: suave, fontSize: 13),
      ),
      if (saldo > 0) ...[
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_registrar_abono'),
          texto: 'Registrar abono',
          variante: VarianteBoton.entra,
          onPressed: () => _abrirAbono(context, saldo),
        ),
      ],
    ],
  ),
)
```

con `final c = ColoresApp.of(context); final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);`
y `fechaDeuda = clienteConSaldo.fechaDeudaMasAntigua ?? DateTime.now()` (si después de abonar
la fecha cambia, basta este valor; la deuda más antigua solo cambia al saldar).
Con saldo a favor, el `Monto` muestra el valor absoluto y el texto lo aclara.

Línea de tiempo (reemplaza "Movimientos" y la `Card`):

```dart
movimientosAsync.when(
  skipLoadingOnReload: true,
  data: (movimientos) {
    final saldos = saldosAcumulados(movimientos);
    final hoy = DateTime.now();
    String titulo(DateTime d) {
      final dias = diasDesde(d, hoy);
      if (dias == 0) return 'Hoy';
      if (dias == 1) return 'Ayer';
      return fechaCortaConAnio(d, hoy);
    }
    final filas = <Widget>[];
    DateTime? diaActual;
    for (final m in movimientos) { // ya vienen del más reciente al más antiguo
      final dia = inicioDelDia(m.fecha);
      if (dia != diaActual) {
        diaActual = dia;
        filas.add(Padding(
          key: Key('encabezado_dia_${dia.toIso8601String().substring(0, 10)}'),
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(titulo(dia),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: c.textoSecundario)),
        ));
      }
      filas.add(_FilaMovimiento(
        movimiento: m,
        nombres: nombres,
        saldoTras: saldos[(m.tipo, m.id)],
        onTap: () => abrirHojaMovimiento(context,
            MovimientoEditable.desdeFiado(m,
                clienteId: cliente.id, nombreCliente: cliente.nombre)),
      ));
    }
    return Column(key: const Key('linea_tiempo'),
        crossAxisAlignment: CrossAxisAlignment.stretch, children: filas);
  },
  …
)
```

`_FilaMovimiento` (se conserva su clave `movimiento_fiado_{tipo}_{id}`): `InkWell` con
`IntrinsicHeight(Row(children: [ SizedBox(width: 24, child: Stack(alignment: topCenter,
children: [ Positioned.fill(left: 11, right: 11, child: ColoredBox(color: c.borde)),
Padding(top: 18, Container(12×12, shape circle, color: esAbono ? c.entra : c.fiado)) ])),
SizedBox(8), Expanded(Padding(vertical 10, Column(start: [ Row([ Text(esAbono ? 'Abono ·
${medio}' : 'Venta fiada', w600), Spacer(), Text('${esAbono ? '−' : '+'} ${formatoMoneda(monto)}',
w800, color: anulado ? c.textoSecundario : (esAbono ? c.entra : c.fiado), decoration: anulado ?
lineThrough : null) ]), Text(formatoHora(fecha), 12 secundario), if corrección
Text(textoCorreccion…), if (!anulado && saldoTras != null) Text(saldoTras >= 0 ? 'Quedó
debiendo ${formatoMoneda(saldoTras)}' : 'Saldo a favor ${formatoMoneda(-saldoTras)}', key:
saldo_tras_{tipo}_{id}, 12, c.textoSecundario) ]))) ]))`. Se conserva la etiqueta QR existente
para abonos por transferencia (`EtiquetaQr`) junto al texto del abono.

- [ ] **Step 4: Run** `flutter test test/screens/fiado` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/fiado/detalle_cliente_screen.dart test/screens/fiado/detalle_cliente_screen_test.dart
git commit -m "Show the customer's debt card and a timeline with running balances"
```

---

### Task 4: Abono rápido

**Files:**
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart`, `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces — Produces:** `_HojaAbono({required int clienteId, required int saldo})`;
claves `abono_todo`, `abono_mitad`; `int mitadAbono(int saldo)` (pública en el mismo archivo o
en `lib/util/saldos_fiado.dart` — usar `saldos_fiado.dart`).

- [ ] **Step 1: Tests (fallan)**

En `test/util/saldos_fiado_test.dart`:

```dart
test('mitadAbono redondea a la centena y se anula con saldos pequeños', () {
  expect(mitadAbono(45000), 22500);
  expect(mitadAbono(12350), 6200);
  expect(mitadAbono(100), 0);
  expect(mitadAbono(150), 100);
  expect(mitadAbono(0), 0);
});
```

(Con 100 la mitad redondeada es 100 = el saldo → 0, oculto.)

En `detalle_cliente_screen_test.dart`:

```dart
testWidgets('Todo llena la deuda y deja al cliente al día', (tester) async {
  await montarDetalle(tester);
  await tester.tap(find.byKey(const Key('boton_registrar_abono')));
  await tester.pumpAndSettle();
  expect(find.text(r'Todo · $5.000'), findsOneWidget);
  expect(find.text(r'Mitad · $2.500'), findsOneWidget);
  await tester.tap(find.byKey(const Key('abono_todo')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
  await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
  await tester.pumpAndSettle();
  expect(saldo('Al día'), findsOneWidget);
  expect(find.byKey(const Key('boton_registrar_abono')), findsNothing);
});

testWidgets('Mitad llena la mitad y el teclado sigue editando', (tester) async {
  await montarDetalle(tester);
  await tester.tap(find.byKey(const Key('boton_registrar_abono')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('abono_mitad')));
  await tester.pump();
  // el monto de la hoja muestra $2.500; borrar un dígito deja $250
  await teclear(tester, ['borrar']);
  await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
  await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
  await tester.pumpAndSettle();
  expect(saldo(r'$4.750'), findsOneWidget);
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**

`saldos_fiado.dart`:

```dart
/// Mitad de [saldo] redondeada a la centena; 0 si no tiene sentido
/// ofrecerla (saldo pequeño o la mitad redondeada iguala al saldo).
int mitadAbono(int saldo) {
  if (saldo <= 0) return 0;
  final mitad = ((saldo / 2) / 100).round() * 100;
  return mitad <= 0 || mitad >= saldo ? 0 : mitad;
}
```

`_HojaAbono`: nuevo parámetro `final int saldo;` (pasado desde `_abrirAbono(context, saldo)`);
encima del teclado:

```dart
Wrap(
  spacing: 8,
  children: [
    ChoiceChip(
      key: const Key('abono_todo'),
      label: Text('Todo · ${formatoMoneda(widget.saldo)}'),
      selected: _monto == widget.saldo,
      onSelected: (_) => setState(() { _monto = widget.saldo; _error = null; }),
    ),
    if (mitadAbono(widget.saldo) > 0)
      ChoiceChip(
        key: const Key('abono_mitad'),
        label: Text('Mitad · ${formatoMoneda(mitadAbono(widget.saldo))}'),
        selected: _monto == mitadAbono(widget.saldo),
        onSelected: (_) => setState(() { _monto = mitadAbono(widget.saldo); _error = null; }),
      ),
  ],
),
```

(el teclado ya aplica `aplicarTecla` sobre `_monto`).

- [ ] **Step 4: Run** `flutter test test/util test/screens/fiado` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "Add quick payment chips for the full and half debt"
```

---

### Task 5: Gasto con categorías

**Files:**
- Modify: `lib/screens/gasto/registrar_gasto_screen.dart`, `test/screens/gasto/registrar_gasto_screen_test.dart`

**Interfaces:**
- Consumes: `categoriasGasto`, `categoriaDe`, `aplicarCategoria` (Task 1), `MontoAnimado`.
- Produces: claves `categoria_mercancia`, `categoria_servicios`, `categoria_arriendo`,
  `categoria_transporte`, `categoria_otro`, `monto_gasto`.

- [ ] **Step 1: Tests (fallan)**

```dart
testWidgets('una categoría llena la descripción y se guarda', (tester) async {
  await abrirGasto(tester);
  await tester.tap(find.byKey(const Key('tecla_monto_5')));
  await tester.tap(find.byKey(const Key('tecla_monto_000')));
  await tester.tap(find.byKey(const Key('categoria_mercancia')));
  await tester.pump();
  expect(find.widgetWithText(TextField, 'Mercancía'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('campo_descripcion_gasto')),
      'Mercancía · gaseosas');
  await tester.tap(find.byKey(const Key('categoria_servicios')));
  await tester.pump();
  expect(find.widgetWithText(TextField, 'Servicios · gaseosas'), findsOneWidget);
  await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
  await tester.pumpAndSettle();
  expect((await db.select(db.gastos).get()).single.descripcion,
      'Servicios · gaseosas');
});

testWidgets('Otro y volver a tocar la categoría la quitan', (tester) async {
  await abrirGasto(tester);
  await tester.enterText(find.byKey(const Key('campo_descripcion_gasto')), 'taxi');
  await tester.tap(find.byKey(const Key('categoria_transporte')));
  await tester.pump();
  expect(find.widgetWithText(TextField, 'Transporte · taxi'), findsOneWidget);
  await tester.tap(find.byKey(const Key('categoria_transporte')));
  await tester.pump();
  expect(find.widgetWithText(TextField, 'taxi'), findsOneWidget);
  await tester.tap(find.byKey(const Key('categoria_arriendo')));
  await tester.tap(find.byKey(const Key('categoria_otro')));
  await tester.pump();
  expect(find.widgetWithText(TextField, 'taxi'), findsOneWidget);
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar** en `registrar_gasto_screen.dart`:

- Encima del teclado: `MontoAnimado(_monto, key: monto_gasto, tamano: 36, tono: TonoMonto.sale)`
  centrado (si hoy hay otro widget de monto, reemplazarlo).
- Debajo del teclado y antes del campo de descripción:

```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final cat in [...categoriasGasto, 'Otro'])
      ChoiceChip(
        key: Key('categoria_${sinTildes(cat)}'),
        label: Text(cat),
        selected: cat == 'Otro'
            ? false
            : categoriaDe(_descripcionController.text.trim()) == cat,
        onSelected: (_) {
          final actual = categoriaDe(_descripcionController.text.trim());
          final nueva = (cat == 'Otro' || actual == cat) ? null : cat;
          final texto = aplicarCategoria(_descripcionController.text, nueva);
          setState(() => _descripcionController.value = TextEditingValue(
                text: texto,
                selection: TextSelection.collapsed(offset: texto.length),
              ));
        },
      ),
  ],
),
```

- El `TextField` agrega `onChanged: (_) => setState(() {})` para que el chip elegido se
  actualice al escribir.

- [ ] **Step 4: Run** `flutter test test/screens/gasto` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gasto test/screens/gasto
git commit -m "Add quick expense categories and an animated amount"
```

---

### Task 6: Modo oscuro, cierre y APK

**Files:**
- Modify: `test/screens/modo_oscuro_test.dart`, `docs/hoja-de-ruta.md`,
  `docs/superpowers/specs/2026-10-11-vecitienda-renovacion-r3a-design.md` (Estado)

- [ ] **Step 1:** En `modo_oscuro_test.dart` agregar casos con `montarOscuro` para
`ListaFiadoScreen` (con un deudor creado antes de montar), `RegistrarGastoScreen` y, con
`escalaLetra: 1.6`, la lista de fiado. Para el detalle: crear un cliente con venta fiada y
montar `DetalleClienteScreen(clienteConSaldo: ClienteConSaldo(cliente: …, saldo: …,
fechaDeudaMasAntigua: …))`.

- [ ] **Step 2: Run** `flutter test test/screens/modo_oscuro_test.dart` — Expected: PASS.

- [ ] **Step 3: Verificación completa** — `flutter analyze`, `flutter test`,
`flutter build apk --release`.

- [ ] **Step 4: Documentación** — hoja de ruta: "Hecho" + `- Renovación R3a — fiado (tarjeta,
buscador, orden, antigüedad, línea de tiempo, abono rápido) y gasto con categorías.`;
"En curso": `- Renovación: R3b (reportes, historial, corrección, QR), R4 (administración).`;
"Pendiente de verificar": agregar `renovación R3a`. Spec: `**Estado:** Implementado (falta el
recorrido manual en un celular real)`.

- [ ] **Step 5: Commit**

```bash
git add test docs
git commit -m "Check credit and expense screens in dark mode and mark R3a as implemented"
```
