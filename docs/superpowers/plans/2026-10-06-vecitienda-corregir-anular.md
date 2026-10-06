# Fase 3A — Corregir y anular movimientos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El tendero puede corregir o anular una venta, un abono de fiado o un gasto mal registrado; lo anulado deja de contar en todos los totales y saldos, y queda el rastro de quién cambió qué y cómo estaba antes.

**Architecture:** El esquema Drift sube a v3: columna `anulado` en `ventas`, `pagos_fiado` y `gastos`, y tabla nueva `correcciones` (tipo de movimiento, id, acción, usuario, fecha, texto `antes`). Un `CorreccionRepository` es el único punto que anula o corrige, dentro de una transacción, después de comprobar el permiso con la función pura `puedeCorregir`. Las consultas que suman filtran `anulado = false`; el Historial y el detalle del cliente piden también lo anulado (`incluirAnulados: true`) y lo muestran tachado en una hoja de detalle compartida (`HojaMovimiento`) que permite corregir o anular.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ drift_dev/build_runner), sqlite3 3.5. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-06-vecitienda-corregir-anular-design.md`

## Global Constraints

- `schemaVersion = 3`. La migración solo agrega (`addColumn` ×3 y `createTable`); no reescribe datos. `CopiaBaseDatos.tablas` **no cambia**.
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Permiso: administrador (`rol == 'admin'`) cualquier movimiento de cualquier día; vendedor solo los suyos (`usuarioId` igual) del mismo día local que `ahora`.
- Lo anulado no cuenta en: `resumenDelDia` (todo), `resumenPorVendedor`, tarjetas del Historial, `saldoCliente`, `listaClientesConDeuda`, `deudaTotalAl`, `clientesConDeudaAl`.
- No hay "desanular"; no se corrige ni se anula algo ya anulado.
- "Deshacer" tras cobrar (`VentaRepository.eliminarVenta`) no cambia.
- Formato de `antes`: `$50.000 · Contado · Efectivo`, `$50.000 · Contado · Transferencia`, `$50.000 · Fiado · Rosa`, `$20.000 · Efectivo`, `$15.000 · Hielo`, `$15.000` (gasto sin descripción). Pesos con `formatoMoneda`.
- Textos exactos: "Corregir", "Anular", "Guardar", "Cancelar", "Descripción", "Contado", "Fiado", "Efectivo", "Transferencia", "Venta", "Abono", "Gasto", "Venta corregida", "Venta anulada", "Abono corregido", "Abono anulado", "Gasto corregido", "Gasto anulado", "¿Anular esta venta de $X?" / "¿Anular este abono de $X?" / "¿Anular este gasto de $X?", "Ya no contará en los totales.", "No se pudo guardar, intenta de nuevo", "Anulada por X · HH:MM" / "Anulado por X · HH:MM", "Corregida por X · antes: …" / "Corregido por X · antes: …" (femenino solo para ventas; hora con `formatoHora`).
- Toda la UI en español. Montos con `Monto`; el anulado va tachado y en `ColoresApp.textoSecundario`.
- Trabajar en una rama nueva `fase3a-corregir-anular` desde `master`.

## Review Focus

1. Doble toque en "Guardar" de la hoja → una sola corrección guardada (prueba en Task 7).
2. Pasar a contado una venta fiada que ya tenía abonos → el cliente queda con saldo a favor, sale de Fiado y la deuda total no baja de 0 (prueba en Task 4).
3. Anular la única venta fiada de un cliente → desaparece de la lista de Fiado sin error (prueba en Task 3).
4. Al pasar una venta a fiada, escribir el nombre de un cliente existente con otras mayúsculas ("rosa" vs "Rosa") → usa el cliente existente, no crea otro (prueba en Task 7).
5. Abrir un respaldo hecho con la app v2 → migra a v3 con todo sin anular (prueba en Task 1).

---

### Task 1: Esquema v3 — `anulado` y tabla `correcciones`

**Files:**
- Create: `lib/data/correccion.dart`
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v2.dart`
- Modify: `test/data/migracion_test.dart`
- Modify: `test/respaldo/copia_base_datos_test.dart:23`

**Interfaces:**
- Produces: `enum TipoMovimiento { venta, abono, gasto }`, `enum AccionCorreccion { anulado, corregido }` (exportados por `database.dart`); columnas `Venta.anulado`, `PagoFiado.anulado`, `Gasto.anulado` (`bool`); tabla `db.correcciones` con data class `Correccion { int id; TipoMovimiento tipoMovimiento; int movimientoId; AccionCorreccion accion; int usuarioId; DateTime fecha; String antes; }` y `CorreccionesCompanion.insert(...)`.

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase3a-corregir-anular
```

- [ ] **Step 2: Escribir el fixture v2**

`test/support/esquema_v2.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v1.dart';

/// Crea en [ruta] una base con el esquema v2 de la app (2D, antes de la 3A):
/// el de v1 más medio de pago y configuración de la tienda, y además un gasto.
void crearBaseV2(String ruta) {
  crearBaseV1(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE ventas ADD COLUMN medio_pago TEXT NOT NULL DEFAULT 'efectivo';
      ALTER TABLE pagos_fiado ADD COLUMN medio_pago TEXT NOT NULL DEFAULT 'efectivo';
      CREATE TABLE configuracion_tienda (id INTEGER NOT NULL,
        imagen_qr BLOB NULL, PRIMARY KEY (id));
      INSERT INTO gastos (monto, descripcion, fecha, usuario_id)
        VALUES (1500, 'Hielo', 1788000000, 1);
    ''')
    ..userVersion = 2
    ..close();
}
```

- [ ] **Step 3: Escribir las pruebas que fallan**

En `test/data/migracion_test.dart`, agregar `import '../support/esquema_v2.dart';`, cambiar `expect(db.schemaVersion, 2);` por `expect(db.schemaVersion, 3);` y agregar dentro de `main()`:

```dart
  test('una base v2 abre en v3 sin nada anulado y sin correcciones', () async {
    final archivo = File('${carpeta.path}/v2.sqlite');
    crearBaseV2(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.ventas).getSingle()).anulado, isFalse);
    expect((await db.select(db.pagosFiado).getSingle()).anulado, isFalse);
    expect((await db.select(db.gastos).getSingle()).anulado, isFalse);
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('una base v1 abre en v3 sin nada anulado', () async {
    final archivo = File('${carpeta.path}/v1b.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.ventas).getSingle()).anulado, isFalse);
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('una base nueva guarda correcciones con sus enums', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    await db.into(db.correcciones).insert(CorreccionesCompanion.insert(
          tipoMovimiento: TipoMovimiento.abono,
          movimientoId: 7,
          accion: AccionCorreccion.anulado,
          usuarioId: usuario,
          fecha: DateTime(2026, 10, 6, 15),
          antes: r'$2.000 · Efectivo',
        ));

    final fila = await db.select(db.correcciones).getSingle();
    expect(fila.tipoMovimiento, TipoMovimiento.abono);
    expect(fila.movimientoId, 7);
    expect(fila.accion, AccionCorreccion.anulado);
    expect(fila.antes, r'$2.000 · Efectivo');
  });
```

En `test/respaldo/copia_base_datos_test.dart:23` cambiar `versionMaxima: 2` por `versionMaxima: 3` (la copia de una base nueva ahora es v3).

- [ ] **Step 4: Correr las pruebas y ver que fallan**

Run: `flutter test test/data/migracion_test.dart`
Expected: FAIL de compilación (`anulado`, `correcciones`, `TipoMovimiento` no existen).

- [ ] **Step 5: Implementar el esquema**

`lib/data/correccion.dart`:

```dart
/// Qué clase de movimiento se anuló o corrigió.
enum TipoMovimiento { venta, abono, gasto }

/// Qué se le hizo al movimiento.
enum AccionCorreccion { anulado, corregido }
```

En `lib/data/database.dart`:

- Junto a los imports/exports de `medio_pago.dart`:

```dart
import 'correccion.dart';
import 'medio_pago.dart';

export 'correccion.dart';
export 'medio_pago.dart';
```

- Al final de las columnas de `Ventas`, `PagosFiado` y `Gastos`, agregar en cada una:

```dart
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
```

- Después de `ConfiguracionTienda`:

```dart
/// Rastro de cada anulación o corrección de un movimiento.
@DataClassName('Correccion')
class Correcciones extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tipoMovimiento => textEnum<TipoMovimiento>()();

  /// Id en `ventas`, `pagos_fiado` o `gastos` según [tipoMovimiento]; sin
  /// llave foránea porque apunta a tres tablas.
  IntColumn get movimientoId => integer()();
  TextColumn get accion => textEnum<AccionCorreccion>()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();

  /// Cómo estaba el movimiento justo antes del cambio, ya formateado.
  TextColumn get antes => text()();
}
```

- Agregar `Correcciones,` al final de la lista `tables:` de `@DriftDatabase`.
- `int get schemaVersion => 3;`
- En `onUpgrade`, después del bloque `if (desde < 2) {...}`:

```dart
          if (desde < 3) {
            await m.addColumn(ventas, ventas.anulado);
            await m.addColumn(pagosFiado, pagosFiado.anulado);
            await m.addColumn(gastos, gastos.anulado);
            await m.createTable(correcciones);
          }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Correr las pruebas y ver que pasan**

Run: `flutter test test/data test/respaldo`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/data test/support/esquema_v2.dart test/data/migracion_test.dart test/respaldo/copia_base_datos_test.dart
git commit -m "Add voided flag to movements and a corrections table (schema v3)"
```

---

### Task 2: Regla de permisos `puedeCorregir`

**Files:**
- Create: `lib/util/permisos.dart`
- Test: `test/util/permisos_test.dart`

**Interfaces:**
- Consumes: `Usuario` (data class de Drift), `inicioDelDia` de `lib/util/fecha_util.dart`.
- Produces: `bool puedeCorregir({required Usuario usuario, required int duenoId, required DateTime fechaMovimiento, required DateTime ahora})`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/util/permisos_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/permisos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ana = Usuario(id: 1, nombre: 'Ana', rol: 'admin', pinHash: 'x');
  const beto = Usuario(id: 2, nombre: 'Beto', rol: 'vendedor', pinHash: 'y');
  final ahora = DateTime(2026, 10, 6, 15);

  bool puede(Usuario usuario, int duenoId, DateTime fecha) => puedeCorregir(
      usuario: usuario, duenoId: duenoId, fechaMovimiento: fecha, ahora: ahora);

  test('el administrador puede con cualquier movimiento de cualquier día', () {
    expect(puede(ana, 2, DateTime(2026, 9, 1)), isTrue);
    expect(puede(ana, 1, DateTime(2026, 10, 6, 8)), isTrue);
  });

  test('el vendedor puede con lo suyo de hoy', () {
    expect(puede(beto, 2, DateTime(2026, 10, 6, 0, 1)), isTrue);
  });

  test('el vendedor no puede con lo suyo de ayer', () {
    expect(puede(beto, 2, DateTime(2026, 10, 5, 23, 59)), isFalse);
  });

  test('el vendedor no puede con lo de otro aunque sea de hoy', () {
    expect(puede(beto, 1, DateTime(2026, 10, 6, 9)), isFalse);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/util/permisos_test.dart`
Expected: FAIL (`permisos.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/util/permisos.dart`:

```dart
import '../data/database.dart';
import 'fecha_util.dart';

/// true si [usuario] puede corregir o anular un movimiento registrado por
/// [duenoId] en [fechaMovimiento]: el administrador siempre; el vendedor solo
/// lo suyo y del mismo día que [ahora].
bool puedeCorregir({
  required Usuario usuario,
  required int duenoId,
  required DateTime fechaMovimiento,
  required DateTime ahora,
}) {
  if (usuario.rol == 'admin') return true;
  return duenoId == usuario.id &&
      inicioDelDia(fechaMovimiento) == inicioDelDia(ahora);
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/util/permisos_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/util/permisos.dart test/util/permisos_test.dart
git commit -m "Add the rule for who can correct or void a movement"
```

---

### Task 3: Lo anulado no cuenta en totales ni saldos

**Files:**
- Modify: `lib/repositories/venta_repository.dart` (`ventasDelDia`)
- Modify: `lib/repositories/gasto_repository.dart` (`gastosDelDia`)
- Modify: `lib/repositories/fiado_repository.dart` (`saldoCliente`, `listaClientesConDeuda`, `pagosDelDia`, `ventasFiadasCliente`, `pagosCliente`, `_saldosAl`)
- Test: `test/repositories/anulados_test.dart`

**Interfaces:**
- Consumes: columnas `anulado` (Task 1).
- Produces: `ventasDelDia(DateTime dia, {int? usuarioId, bool incluirAnulados = false})`, `gastosDelDia(DateTime dia, {int? usuarioId, bool incluirAnulados = false})`, `ventasFiadasCliente(int clienteId, {bool incluirAnulados = false})`, `pagosCliente(int clienteId, {bool incluirAnulados = false})`. Todas las demás consultas que suman excluyen lo anulado siempre.

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/repositories/anulados_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/resumen_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late FiadoRepository fiado;
  late ResumenRepository resumen;
  late int ana;
  late int pedro;
  final dia = DateTime(2026, 10, 6);
  DateTime a(int hora) => DateTime(2026, 10, 6, hora);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    fiado = FiadoRepository(db);
    resumen = ResumenRepository(db, ventas, gastos, fiado);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<void> anular(String tabla, int id) => db.customStatement(
      'UPDATE $tabla SET anulado = 1 WHERE id = ?', [id]);

  /// Un día con un movimiento anulado de cada clase y otros vigentes.
  Future<({int fiadaVigente, int pagoAnulado})> cargarDia() async {
    final contadoAnulada = await ventas.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: ana, fecha: a(8));
    await ventas.registrarVenta(
        monto: 3000,
        esFiado: false,
        usuarioId: ana,
        fecha: a(9),
        medioPago: MedioPago.transferencia);
    final fiadaAnulada = await ventas.registrarVenta(
        monto: 2000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(7));
    final fiadaVigente = await ventas.registrarVenta(
        monto: 4000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(10));
    final pagoAnulado = await fiado.registrarPago(
        clienteId: pedro, monto: 1000, usuarioId: ana, fecha: a(11));
    final gastoAnulado =
        await gastos.registrarGasto(monto: 700, usuarioId: ana, fecha: a(12));
    await gastos.registrarGasto(monto: 300, usuarioId: ana, fecha: a(13));
    await anular('ventas', contadoAnulada);
    await anular('ventas', fiadaAnulada);
    await anular('pagos_fiado', pagoAnulado);
    await anular('gastos', gastoAnulado);
    return (fiadaVigente: fiadaVigente, pagoAnulado: pagoAnulado);
  }

  test('el resumen del día no cuenta lo anulado', () async {
    await cargarDia();
    final r = await resumen.resumenDelDia(dia);
    expect(r.totalVendido, 7000);
    expect(r.cantidadVentas, 2);
    expect(r.cantidadFiadas, 1);
    expect(r.recibidoEfectivo, 0);
    expect(r.recibidoTransferencia, 3000);
    expect(r.totalGastado, 300);
    expect(r.totalPorCobrar, 4000);
    expect(r.clientesConDeuda, 1);
  });

  test('el resumen por vendedor no cuenta lo anulado', () async {
    await cargarDia();
    final porVendedor = await resumen.resumenPorVendedor(dia);
    expect(porVendedor.values.single.totalVendido, 7000);
  });

  test('el saldo y la lista de Fiado no cuentan lo anulado', () async {
    await cargarDia();
    expect(await fiado.saldoCliente(pedro), 4000);
    final lista = await fiado.listaClientesConDeuda();
    expect(lista.single.saldo, 4000);
    expect(lista.single.fechaDeudaMasAntigua, a(10));
  });

  test('anular la única venta fiada saca al cliente de Fiado', () async {
    final id = await ventas.registrarVenta(
        monto: 2000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(7));
    await anular('ventas', id);
    expect(await fiado.listaClientesConDeuda(), isEmpty);
    expect(await fiado.deudaTotalAl(dia), 0);
    expect(await fiado.clientesConDeudaAl(dia), 0);
  });

  test('las listas traen lo anulado solo si se pide', () async {
    final ids = await cargarDia();
    expect(await ventas.ventasDelDia(dia), hasLength(2));
    expect(await ventas.ventasDelDia(dia, incluirAnulados: true), hasLength(4));
    expect(await gastos.gastosDelDia(dia), hasLength(1));
    expect(await gastos.gastosDelDia(dia, incluirAnulados: true), hasLength(2));
    expect(await fiado.pagosDelDia(dia), isEmpty);
    expect((await fiado.ventasFiadasCliente(pedro)).map((v) => v.id),
        [ids.fiadaVigente]);
    expect(await fiado.ventasFiadasCliente(pedro, incluirAnulados: true),
        hasLength(2));
    expect(await fiado.pagosCliente(pedro), isEmpty);
    expect((await fiado.pagosCliente(pedro, incluirAnulados: true)).single.id,
        ids.pagoAnulado);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/anulados_test.dart`
Expected: FAIL (parámetro `incluirAnulados` no existe; totales cuentan lo anulado).

- [ ] **Step 3: Implementar los filtros**

`lib/repositories/venta_repository.dart`, reemplazar `ventasDelDia`:

```dart
  /// Ventas de [dia]. Lo anulado solo viene con [incluirAnulados], para
  /// mostrarlo en el Historial; nunca debe sumarse.
  Future<List<Venta>> ventasDelDia(
    DateTime dia, {
    int? usuarioId,
    bool incluirAnulados = false,
  }) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.ventas)
      ..where((v) =>
          v.fecha.isBiggerOrEqualValue(inicio) &
          v.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((v) => v.usuarioId.equals(usuarioId));
    }
    if (!incluirAnulados) {
      query.where((v) => v.anulado.equals(false));
    }
    return query.get();
  }
```

`lib/repositories/gasto_repository.dart`, reemplazar `gastosDelDia`:

```dart
  /// Gastos de [dia]. Lo anulado solo viene con [incluirAnulados], para
  /// mostrarlo en el Historial; nunca debe sumarse.
  Future<List<Gasto>> gastosDelDia(
    DateTime dia, {
    int? usuarioId,
    bool incluirAnulados = false,
  }) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.gastos)
      ..where((g) =>
          g.fecha.isBiggerOrEqualValue(inicio) &
          g.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((g) => g.usuarioId.equals(usuarioId));
    }
    if (!incluirAnulados) {
      query.where((g) => g.anulado.equals(false));
    }
    return query.get();
  }
```

`lib/repositories/fiado_repository.dart`:

- En `saldoCliente`, las dos consultas:

```dart
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.clienteId.equals(clienteId) &
              v.esFiado.equals(true) &
              v.anulado.equals(false)))
        .get();
```

```dart
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId) & p.anulado.equals(false)))
        .get();
```

- En `listaClientesConDeuda`, la consulta `ventasFiadas`:

```dart
      final ventasFiadas = await (_db.select(_db.ventas)
            ..where((v) =>
                v.clienteId.equals(cliente.id) &
                v.esFiado.equals(true) &
                v.anulado.equals(false))
            ..orderBy([(v) => OrderingTerm.asc(v.fecha)]))
          .get();
```

- En `pagosDelDia`, el primer `where`:

```dart
      ..where((p) =>
          p.fecha.isBiggerOrEqualValue(inicioDelDia(dia)) &
          p.fecha.isSmallerOrEqualValue(finDelDia(dia)) &
          p.anulado.equals(false));
```

- Reemplazar `ventasFiadasCliente` y `pagosCliente`:

```dart
  Future<List<Venta>> ventasFiadasCliente(
    int clienteId, {
    bool incluirAnulados = false,
  }) {
    final query = _db.select(_db.ventas)
      ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true))
      ..orderBy([(v) => OrderingTerm.desc(v.fecha)]);
    if (!incluirAnulados) query.where((v) => v.anulado.equals(false));
    return query.get();
  }

  Future<List<PagoFiado>> pagosCliente(
    int clienteId, {
    bool incluirAnulados = false,
  }) {
    final query = _db.select(_db.pagosFiado)
      ..where((p) => p.clienteId.equals(clienteId))
      ..orderBy([(p) => OrderingTerm.desc(p.fecha)]);
    if (!incluirAnulados) query.where((p) => p.anulado.equals(false));
    return query.get();
  }
```

- En `_saldosAl`, las dos consultas:

```dart
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.esFiado.equals(true) &
              v.clienteId.isNotNull() &
              v.anulado.equals(false) &
              v.fecha.isSmallerOrEqualValue(corte)))
        .get();
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) =>
              p.anulado.equals(false) & p.fecha.isSmallerOrEqualValue(corte)))
        .get();
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories`
Expected: PASS (las pruebas viejas de repositorios siguen pasando: nada en ellas está anulado).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories test/repositories/anulados_test.dart
git commit -m "Leave voided movements out of totals, balances and debt"
```

---

### Task 4: `CorreccionRepository`

**Files:**
- Create: `lib/repositories/correccion_repository.dart`
- Modify: `lib/providers/repository_providers.dart`
- Test: `test/repositories/correccion_repository_test.dart`

**Interfaces:**
- Consumes: `puedeCorregir` (Task 2), tabla `correcciones` y columnas `anulado` (Task 1), `formatoMoneda`.
- Produces:
  - `class PermisoDenegado implements Exception`
  - `class CorreccionInvalida implements Exception { final String mensaje; }`
  - `CorreccionRepository(AppDatabase db, {DateTime Function()? reloj})`
  - `Future<void> anularVenta(int id, {required Usuario por})`
  - `Future<void> corregirVenta(int id, {required int monto, required bool esFiado, int? clienteId, MedioPago medioPago = MedioPago.efectivo, required Usuario por})`
  - `Future<void> anularPago(int id, {required Usuario por})`
  - `Future<void> corregirPago(int id, {required int monto, required MedioPago medioPago, required Usuario por})`
  - `Future<void> anularGasto(int id, {required Usuario por})`
  - `Future<void> corregirGasto(int id, {required int monto, String? descripcion, required Usuario por})`
  - `Future<Map<int, Correccion>> ultimasCorrecciones(TipoMovimiento tipo, Iterable<int> ids)` — id del movimiento → su corrección más reciente.
  - `final correccionRepositoryProvider = Provider<CorreccionRepository>(...)`

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/repositories/correccion_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CorreccionRepository repo;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late FiadoRepository fiado;
  late Usuario ana; // administradora
  late Usuario beto; // vendedor
  late int pedro;
  late int rosa;
  final ahora = DateTime(2026, 10, 6, 15, 40);
  final hoy = DateTime(2026, 10, 6, 9);
  final ayer = DateTime(2026, 10, 5, 9);

  Future<Usuario> crearUsuario(String nombre, String rol) async {
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: nombre, rol: rol, pinHash: 'x'));
    return (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db, reloj: () => ahora);
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    fiado = FiadoRepository(db);
    ana = await crearUsuario('Ana', 'admin');
    beto = await crearUsuario('Beto', 'vendedor');
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    rosa =
        await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Rosa'));
  });

  tearDown(() => db.close());

  Future<Venta> venta(int id) =>
      (db.select(db.ventas)..where((v) => v.id.equals(id))).getSingle();
  Future<PagoFiado> pago(int id) =>
      (db.select(db.pagosFiado)..where((p) => p.id.equals(id))).getSingle();
  Future<Gasto> gasto(int id) =>
      (db.select(db.gastos)..where((g) => g.id.equals(id))).getSingle();
  Future<List<Correccion>> correcciones() => db.select(db.correcciones).get();

  group('ventas', () {
    test('anular marca la venta y deja el rastro', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);

      await repo.anularVenta(id, por: ana);

      expect((await venta(id)).anulado, isTrue);
      final c = (await correcciones()).single;
      expect(c.tipoMovimiento, TipoMovimiento.venta);
      expect(c.movimientoId, id);
      expect(c.accion, AccionCorreccion.anulado);
      expect(c.usuarioId, ana.id);
      expect(c.fecha, ahora);
      expect(c.antes, r'$5.000 · Contado · Efectivo');
    });

    test('de contado a fiada suma a la deuda del cliente', () async {
      final id = await ventas.registrarVenta(
          monto: 5000,
          esFiado: false,
          usuarioId: ana.id,
          fecha: hoy,
          medioPago: MedioPago.transferencia);

      await repo.corregirVenta(id,
          monto: 6000, esFiado: true, clienteId: pedro, por: ana);

      final v = await venta(id);
      expect(v.monto, 6000);
      expect(v.esFiado, isTrue);
      expect(v.clienteId, pedro);
      expect(v.medioPago, MedioPago.efectivo);
      expect(v.anulado, isFalse);
      expect(await fiado.saldoCliente(pedro), 6000);
      final c = (await correcciones()).single;
      expect(c.accion, AccionCorreccion.corregido);
      expect(c.antes, r'$5.000 · Contado · Transferencia');
    });

    test('de fiada a contado quita la deuda y guarda el medio de pago',
        () async {
      final id = await ventas.registrarVenta(
          monto: 4000, esFiado: true, clienteId: rosa, usuarioId: ana.id, fecha: hoy);

      await repo.corregirVenta(id,
          monto: 4000,
          esFiado: false,
          medioPago: MedioPago.transferencia,
          por: ana);

      final v = await venta(id);
      expect(v.esFiado, isFalse);
      expect(v.clienteId, isNull);
      expect(v.medioPago, MedioPago.transferencia);
      expect(await fiado.saldoCliente(rosa), 0);
      expect((await correcciones()).single.antes, r'$4.000 · Fiado · Rosa');
    });

    test(
        'pasar a contado una venta ya abonada deja saldo a favor sin deuda '
        'negativa', () async {
      final id = await ventas.registrarVenta(
          monto: 4000, esFiado: true, clienteId: rosa, usuarioId: ana.id, fecha: hoy);
      await fiado.registrarPago(
          clienteId: rosa, monto: 3000, usuarioId: ana.id, fecha: hoy);

      await repo.corregirVenta(id, monto: 4000, esFiado: false, por: ana);

      expect(await fiado.saldoCliente(rosa), -3000);
      expect(await fiado.listaClientesConDeuda(), isEmpty);
      expect(await fiado.deudaTotalAl(ahora), 0);
    });
  });

  group('abonos', () {
    test('corregir cambia monto y medio de pago', () async {
      final id = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await repo.corregirPago(id,
          monto: 2500, medioPago: MedioPago.transferencia, por: ana);

      final p = await pago(id);
      expect(p.monto, 2500);
      expect(p.medioPago, MedioPago.transferencia);
      final c = (await correcciones()).single;
      expect(c.tipoMovimiento, TipoMovimiento.abono);
      expect(c.antes, r'$2.000 · Efectivo');
    });

    test('anular lo saca del saldo', () async {
      await ventas.registrarVenta(
          monto: 5000, esFiado: true, clienteId: pedro, usuarioId: ana.id, fecha: hoy);
      final id = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await repo.anularPago(id, por: ana);

      expect((await pago(id)).anulado, isTrue);
      expect(await fiado.saldoCliente(pedro), 5000);
    });
  });

  group('gastos', () {
    test('corregir cambia monto y descripción', () async {
      final id = await gastos.registrarGasto(
          monto: 1500, descripcion: 'Hielo', usuarioId: ana.id, fecha: hoy);

      await repo.corregirGasto(id,
          monto: 1800, descripcion: 'Hielo y bolsas', por: ana);

      final g = await gasto(id);
      expect(g.monto, 1800);
      expect(g.descripcion, 'Hielo y bolsas');
      expect((await correcciones()).single.antes, r'$1.500 · Hielo');
    });

    test('anular un gasto sin descripción guarda solo el monto', () async {
      final id =
          await gastos.registrarGasto(monto: 1500, usuarioId: ana.id, fecha: hoy);

      await repo.anularGasto(id, por: ana);

      expect((await gasto(id)).anulado, isTrue);
      expect((await correcciones()).single.antes, r'$1.500');
    });
  });

  group('permisos', () {
    test('el vendedor corrige lo suyo de hoy', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: hoy);

      await repo.anularVenta(id, por: beto);

      expect((await venta(id)).anulado, isTrue);
    });

    test('el vendedor no toca lo suyo de ayer', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

      await expectLater(
          repo.anularVenta(id, por: beto), throwsA(isA<PermisoDenegado>()));
      await expectLater(
          repo.corregirVenta(id, monto: 1000, esFiado: false, por: beto),
          throwsA(isA<PermisoDenegado>()));

      final v = await venta(id);
      expect(v.anulado, isFalse);
      expect(v.monto, 5000);
      expect(await correcciones(), isEmpty);
    });

    test('el vendedor no toca lo de otro', () async {
      final gastoId =
          await gastos.registrarGasto(monto: 900, usuarioId: ana.id, fecha: hoy);
      final pagoId = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await expectLater(repo.corregirGasto(gastoId, monto: 100, por: beto),
          throwsA(isA<PermisoDenegado>()));
      await expectLater(
          repo.anularPago(pagoId, por: beto), throwsA(isA<PermisoDenegado>()));
      expect(await correcciones(), isEmpty);
    });

    test('el administrador corrige lo de otro de días anteriores', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

      await repo.anularVenta(id, por: ana);

      expect((await venta(id)).anulado, isTrue);
    });
  });

  group('reglas', () {
    test('no se anula ni se corrige algo ya anulado', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      await repo.anularVenta(id, por: ana);

      await expectLater(repo.anularVenta(id, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      await expectLater(
          repo.corregirVenta(id, monto: 100, esFiado: false, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      expect(await correcciones(), hasLength(1));
    });

    test('monto 0 o fiada sin cliente se rechazan sin cambiar nada', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);

      await expectLater(
          repo.corregirVenta(id, monto: 0, esFiado: false, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      await expectLater(
          repo.corregirVenta(id, monto: 5000, esFiado: true, por: ana),
          throwsA(isA<CorreccionInvalida>()));

      expect((await venta(id)).monto, 5000);
      expect((await venta(id)).esFiado, isFalse);
      expect(await correcciones(), isEmpty);
    });

    test('ultimasCorrecciones da la más reciente de cada movimiento', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      final gastoId =
          await gastos.registrarGasto(monto: 900, usuarioId: ana.id, fecha: hoy);
      await repo.corregirVenta(id, monto: 6000, esFiado: false, por: ana);
      await repo.corregirVenta(id, monto: 7000, esFiado: false, por: ana);
      await repo.anularGasto(gastoId, por: ana);

      final ultimas =
          await repo.ultimasCorrecciones(TipoMovimiento.venta, [id]);

      expect(ultimas.keys.toList(), [id]);
      expect(ultimas[id]!.antes, r'$6.000 · Contado · Efectivo');
      expect(
          (await repo.ultimasCorrecciones(TipoMovimiento.gasto, [gastoId]))[
                  gastoId]!
              .accion,
          AccionCorreccion.anulado);
      expect(await repo.ultimasCorrecciones(TipoMovimiento.abono, const []),
          isEmpty);
    });
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/correccion_repository_test.dart`
Expected: FAIL (`correccion_repository.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/repositories/correccion_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/formato_moneda.dart';
import '../util/permisos.dart';

/// El usuario no puede corregir ni anular ese movimiento.
class PermisoDenegado implements Exception {
  const PermisoDenegado();
}

/// La corrección no es válida: monto en 0, venta fiada sin cliente o
/// movimiento ya anulado.
class CorreccionInvalida implements Exception {
  const CorreccionInvalida(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

String _nombreMedio(MedioPago medio) =>
    medio == MedioPago.efectivo ? 'Efectivo' : 'Transferencia';

/// Único lugar que anula o corrige ventas, abonos y gastos. Cada cambio queda
/// en `correcciones` con quién, cuándo y cómo estaba antes, en la misma
/// transacción que el cambio.
class CorreccionRepository {
  CorreccionRepository(this._db, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _reloj;

  // ---- Ventas ----

  Future<void> anularVenta(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final antes = await _antesVenta(venta);
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id)))
          .write(const VentasCompanion(anulado: Value(true)));
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.anulado, por, antes);
    });
  }

  /// Una venta fiada guarda `efectivo` (no cuenta por medio de pago); una de
  /// contado queda sin cliente.
  Future<void> corregirVenta(
    int id, {
    required int monto,
    required bool esFiado,
    int? clienteId,
    MedioPago medioPago = MedioPago.efectivo,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    if (esFiado && clienteId == null) {
      throw const CorreccionInvalida('Una venta fiada necesita cliente');
    }
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final antes = await _antesVenta(venta);
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id))).write(
        VentasCompanion(
          monto: Value(monto),
          esFiado: Value(esFiado),
          clienteId: Value(esFiado ? clienteId : null),
          medioPago: Value(esFiado ? MedioPago.efectivo : medioPago),
        ),
      );
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.corregido, por, antes);
    });
  }

  // ---- Abonos ----

  Future<void> anularPago(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final pago = await _pago(id);
      _comprobar(por, pago.usuarioId, pago.fecha, pago.anulado);
      await (_db.update(_db.pagosFiado)..where((p) => p.id.equals(id)))
          .write(const PagosFiadoCompanion(anulado: Value(true)));
      await _registrar(TipoMovimiento.abono, id, AccionCorreccion.anulado, por,
          _antesPago(pago));
    });
  }

  Future<void> corregirPago(
    int id, {
    required int monto,
    required MedioPago medioPago,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    await _db.transaction(() async {
      final pago = await _pago(id);
      _comprobar(por, pago.usuarioId, pago.fecha, pago.anulado);
      await (_db.update(_db.pagosFiado)..where((p) => p.id.equals(id))).write(
          PagosFiadoCompanion(monto: Value(monto), medioPago: Value(medioPago)));
      await _registrar(TipoMovimiento.abono, id, AccionCorreccion.corregido,
          por, _antesPago(pago));
    });
  }

  // ---- Gastos ----

  Future<void> anularGasto(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final gasto = await _gasto(id);
      _comprobar(por, gasto.usuarioId, gasto.fecha, gasto.anulado);
      await (_db.update(_db.gastos)..where((g) => g.id.equals(id)))
          .write(const GastosCompanion(anulado: Value(true)));
      await _registrar(TipoMovimiento.gasto, id, AccionCorreccion.anulado, por,
          _antesGasto(gasto));
    });
  }

  Future<void> corregirGasto(
    int id, {
    required int monto,
    String? descripcion,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    await _db.transaction(() async {
      final gasto = await _gasto(id);
      _comprobar(por, gasto.usuarioId, gasto.fecha, gasto.anulado);
      await (_db.update(_db.gastos)..where((g) => g.id.equals(id))).write(
          GastosCompanion(monto: Value(monto), descripcion: Value(descripcion)));
      await _registrar(TipoMovimiento.gasto, id, AccionCorreccion.corregido,
          por, _antesGasto(gasto));
    });
  }

  // ---- Consulta ----

  /// Corrección más reciente de cada movimiento de [ids], por id.
  Future<Map<int, Correccion>> ultimasCorrecciones(
    TipoMovimiento tipo,
    Iterable<int> ids,
  ) async {
    if (ids.isEmpty) return {};
    final filas = await (_db.select(_db.correcciones)
          ..where((c) =>
              c.tipoMovimiento.equalsValue(tipo) & c.movimientoId.isIn(ids))
          ..orderBy([
            (c) => OrderingTerm.asc(c.fecha),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .get();
    // Las más recientes van al final y reemplazan a las anteriores.
    return {for (final c in filas) c.movimientoId: c};
  }

  // ---- Apoyo ----

  Future<Venta> _venta(int id) =>
      (_db.select(_db.ventas)..where((v) => v.id.equals(id))).getSingle();

  Future<PagoFiado> _pago(int id) =>
      (_db.select(_db.pagosFiado)..where((p) => p.id.equals(id))).getSingle();

  Future<Gasto> _gasto(int id) =>
      (_db.select(_db.gastos)..where((g) => g.id.equals(id))).getSingle();

  void _validarMonto(int monto) {
    if (monto <= 0) {
      throw const CorreccionInvalida('El monto debe ser mayor que 0');
    }
  }

  void _comprobar(Usuario por, int duenoId, DateTime fecha, bool anulado) {
    if (anulado) {
      throw const CorreccionInvalida('Este movimiento ya está anulado');
    }
    if (!puedeCorregir(
        usuario: por, duenoId: duenoId, fechaMovimiento: fecha, ahora: _reloj())) {
      throw const PermisoDenegado();
    }
  }

  Future<String> _antesVenta(Venta venta) async {
    final monto = formatoMoneda(venta.monto);
    if (!venta.esFiado) {
      return '$monto · Contado · ${_nombreMedio(venta.medioPago)}';
    }
    final clienteId = venta.clienteId;
    final cliente = clienteId == null
        ? null
        : await (_db.select(_db.clientes)..where((c) => c.id.equals(clienteId)))
            .getSingleOrNull();
    return '$monto · Fiado · ${cliente?.nombre ?? 'Sin cliente'}';
  }

  String _antesPago(PagoFiado pago) =>
      '${formatoMoneda(pago.monto)} · ${_nombreMedio(pago.medioPago)}';

  String _antesGasto(Gasto gasto) {
    final descripcion = gasto.descripcion?.trim() ?? '';
    final monto = formatoMoneda(gasto.monto);
    return descripcion.isEmpty ? monto : '$monto · $descripcion';
  }

  Future<void> _registrar(
    TipoMovimiento tipo,
    int id,
    AccionCorreccion accion,
    Usuario por,
    String antes,
  ) {
    return _db.into(_db.correcciones).insert(CorreccionesCompanion.insert(
          tipoMovimiento: tipo,
          movimientoId: id,
          accion: accion,
          usuarioId: por.id,
          fecha: _reloj(),
          antes: antes,
        ));
  }
}
```

En `lib/providers/repository_providers.dart` agregar el import `import '../repositories/correccion_repository.dart';` y:

```dart
final correccionRepositoryProvider = Provider(
  (ref) => CorreccionRepository(ref.watch(databaseProvider)),
);
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories/correccion_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/correccion_repository.dart lib/providers/repository_providers.dart test/repositories/correccion_repository_test.dart
git commit -m "Add CorreccionRepository to void and correct movements with a trail"
```

---

### Task 5: Las listas traen lo anulado y la última corrección

**Files:**
- Modify: `lib/repositories/historial_repository.dart`
- Modify: `lib/repositories/fiado_repository.dart` (`MovimientoFiado`, `movimientosCliente`)
- Modify: `lib/providers/repository_providers.dart` (`historialRepositoryProvider`)
- Modify: `test/repositories/historial_repository_test.dart`
- Modify: `test/repositories/fiado_repository_test.dart`

**Interfaces:**
- Consumes: `CorreccionRepository.ultimasCorrecciones` (Task 4), `incluirAnulados` (Task 3).
- Produces:
  - `HistorialRepository(VentaRepository, GastoRepository, CorreccionRepository)`
  - `MovimientoHistorial` gana `required int id`, `int? clienteId`, `bool anulado = false`, `Correccion? ultimaCorreccion`.
  - `MovimientoFiado` gana `required int id`, `required int usuarioId`, `bool anulado = false`, `Correccion? ultimaCorreccion`.
  - `movimientosDelDia` y `movimientosCliente` incluyen lo anulado.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/repositories/historial_repository_test.dart`:
- agregar `import 'package:app_ventas/repositories/correccion_repository.dart';`
- en `setUp`, cambiar `repo = HistorialRepository(ventaRepo, gastoRepo);` por `repo = HistorialRepository(ventaRepo, gastoRepo, CorreccionRepository(db));`
- agregar:

```dart
  test('trae lo anulado marcado, la última corrección y el cliente', () async {
    final usuarioAna =
        await (db.select(db.usuarios)..where((u) => u.id.equals(ana))).getSingle();
    final correcciones =
        CorreccionRepository(db, reloj: () => DateTime(2026, 9, 2, 18));
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final anulada = await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 2, 9));
    final fiada = await ventaRepo.registrarVenta(
        monto: 2000,
        esFiado: true,
        clienteId: pedro,
        usuarioId: ana,
        fecha: DateTime(2026, 9, 2, 11));
    final corregido = await gastoRepo.registrarGasto(
        monto: 1000,
        descripcion: 'Hielo',
        usuarioId: ana,
        fecha: DateTime(2026, 9, 2, 10));
    await correcciones.anularVenta(anulada, por: usuarioAna);
    await correcciones.corregirGasto(corregido,
        monto: 1200, descripcion: 'Hielo', por: usuarioAna);

    final movimientos = await repo.movimientosDelDia(dia);

    final venta = movimientos.singleWhere((m) => m.id == anulada &&
        m.tipo == TipoMovimientoHistorial.venta);
    expect(venta.anulado, isTrue);
    expect(venta.ultimaCorreccion!.accion, AccionCorreccion.anulado);
    final deFiado = movimientos.singleWhere((m) => m.id == fiada &&
        m.tipo == TipoMovimientoHistorial.venta);
    expect(deFiado.clienteId, pedro);
    expect(deFiado.ultimaCorreccion, isNull);
    final gasto =
        movimientos.singleWhere((m) => m.tipo == TipoMovimientoHistorial.gasto);
    expect(gasto.id, corregido);
    expect(gasto.monto, 1200);
    expect(gasto.anulado, isFalse);
    expect(gasto.ultimaCorreccion!.antes, r'$1.000 · Hielo');
  });
```

En `test/repositories/fiado_repository_test.dart` agregar `import 'package:app_ventas/repositories/correccion_repository.dart';` y:

```dart
  test('movimientosCliente trae lo anulado marcado con su corrección',
      () async {
    final ana = await (db.select(db.usuarios)
          ..where((u) => u.id.equals(usuarioId)))
        .getSingle();
    final correcciones =
        CorreccionRepository(db, reloj: () => DateTime(2026, 9, 3));
    final ventaId = await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(2026, 9, 1),
          esFiado: const Value(true),
          clienteId: Value(clienteId),
          usuarioId: usuarioId,
        ));
    final pagoId = await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 2));
    await correcciones.anularPago(pagoId, por: ana);
    await correcciones.corregirVenta(ventaId,
        monto: 6000, esFiado: true, clienteId: clienteId, por: ana);

    final movimientos = await repo.movimientosCliente(clienteId);

    final abono =
        movimientos.singleWhere((m) => m.tipo == TipoMovimientoFiado.abono);
    expect(abono.id, pagoId);
    expect(abono.usuarioId, usuarioId);
    expect(abono.anulado, isTrue);
    expect(abono.ultimaCorreccion!.accion, AccionCorreccion.anulado);
    final venta =
        movimientos.singleWhere((m) => m.tipo == TipoMovimientoFiado.venta);
    expect(venta.id, ventaId);
    expect(venta.monto, 6000);
    expect(venta.ultimaCorreccion!.antes, r'$5.000 · Fiado · Don Pedro');
    expect(await repo.saldoCliente(clienteId), 6000);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/historial_repository_test.dart test/repositories/fiado_repository_test.dart`
Expected: FAIL de compilación (constructor de `HistorialRepository`, campos `id`, `anulado`, `ultimaCorreccion`).

- [ ] **Step 3: Implementar el Historial**

Reemplazar `lib/repositories/historial_repository.dart` completo:

```dart
import '../data/database.dart';
import 'correccion_repository.dart';
import 'gasto_repository.dart';
import 'venta_repository.dart';

enum TipoMovimientoHistorial { venta, gasto }

class MovimientoHistorial {
  const MovimientoHistorial({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.clienteId,
    this.descripcion,
    this.medioPago = MedioPago.efectivo,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  final TipoMovimientoHistorial tipo;

  /// Id en su tabla (`ventas` o `gastos`).
  final int id;
  final int monto;
  final DateTime fecha;
  final int usuarioId;

  /// Solo aplica a ventas; siempre false para gastos.
  final bool esFiado;

  /// Solo aplica a ventas fiadas.
  final int? clienteId;

  /// Solo aplica a gastos; null para ventas o gastos sin descripción.
  final String? descripcion;

  /// Solo aplica a ventas.
  final MedioPago medioPago;

  /// Anulado: se muestra tachado y no suma en ningún total.
  final bool anulado;

  /// Anulación o corrección más reciente, si la hay.
  final Correccion? ultimaCorreccion;
}

class HistorialRepository {
  HistorialRepository(
    this._ventaRepository,
    this._gastoRepository,
    this._correccionRepository,
  );

  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;
  final CorreccionRepository _correccionRepository;

  /// Movimientos de [dia], incluidos los anulados (para mostrarlos tachados).
  Future<List<MovimientoHistorial>> movimientosDelDia(
    DateTime dia, {
    int? usuarioId,
  }) async {
    final ventas = await _ventaRepository.ventasDelDia(dia,
        usuarioId: usuarioId, incluirAnulados: true);
    final gastos = await _gastoRepository.gastosDelDia(dia,
        usuarioId: usuarioId, incluirAnulados: true);
    final correccionesVentas = await _correccionRepository
        .ultimasCorrecciones(TipoMovimiento.venta, ventas.map((v) => v.id));
    final correccionesGastos = await _correccionRepository
        .ultimasCorrecciones(TipoMovimiento.gasto, gastos.map((g) => g.id));
    return [
      for (final v in ventas)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.venta,
          id: v.id,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          esFiado: v.esFiado,
          clienteId: v.clienteId,
          medioPago: v.medioPago,
          anulado: v.anulado,
          ultimaCorreccion: correccionesVentas[v.id],
        ),
      for (final g in gastos)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.gasto,
          id: g.id,
          monto: g.monto,
          fecha: g.fecha,
          usuarioId: g.usuarioId,
          descripcion: g.descripcion,
          anulado: g.anulado,
          ultimaCorreccion: correccionesGastos[g.id],
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
```

En `lib/providers/repository_providers.dart`, `historialRepositoryProvider`:

```dart
final historialRepositoryProvider = Provider(
  (ref) => HistorialRepository(
    ref.watch(ventaRepositoryProvider),
    ref.watch(gastoRepositoryProvider),
    ref.watch(correccionRepositoryProvider),
  ),
);
```

- [ ] **Step 4: Implementar Fiado**

En `lib/repositories/fiado_repository.dart`:
- agregar `import 'correccion_repository.dart';`
- reemplazar `MovimientoFiado`:

```dart
class MovimientoFiado {
  const MovimientoFiado({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.medioPago = MedioPago.efectivo,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  final TipoMovimientoFiado tipo;

  /// Id en su tabla (`ventas` o `pagos_fiado`).
  final int id;
  final int monto;
  final DateTime fecha;

  /// Quién lo registró.
  final int usuarioId;

  /// Solo aplica a abonos.
  final MedioPago medioPago;

  /// Anulado: se muestra tachado y no cuenta en el saldo.
  final bool anulado;

  /// Anulación o corrección más reciente, si la hay.
  final Correccion? ultimaCorreccion;
}
```

- reemplazar `movimientosCliente`:

```dart
  /// Ventas fiadas y abonos del cliente, incluidos los anulados (para
  /// mostrarlos tachados).
  Future<List<MovimientoFiado>> movimientosCliente(int clienteId) async {
    final ventas = await ventasFiadasCliente(clienteId, incluirAnulados: true);
    final pagos = await pagosCliente(clienteId, incluirAnulados: true);
    final correcciones = CorreccionRepository(_db);
    final correccionesVentas = await correcciones.ultimasCorrecciones(
        TipoMovimiento.venta, ventas.map((v) => v.id));
    final correccionesPagos = await correcciones.ultimasCorrecciones(
        TipoMovimiento.abono, pagos.map((p) => p.id));
    return [
      for (final v in ventas)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.venta,
          id: v.id,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          anulado: v.anulado,
          ultimaCorreccion: correccionesVentas[v.id],
        ),
      for (final p in pagos)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.abono,
          id: p.id,
          monto: p.monto,
          fecha: p.fecha,
          usuarioId: p.usuarioId,
          medioPago: p.medioPago,
          anulado: p.anulado,
          ultimaCorreccion: correccionesPagos[p.id],
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/repositories test/screens/historial test/screens/fiado`
Expected: PASS (las pantallas todavía no usan los campos nuevos, pero deben compilar).

- [ ] **Step 6: Commit**

```bash
git add lib/repositories lib/providers/repository_providers.dart test/repositories
git commit -m "Include voided movements and their latest correction in history and client lists"
```

---

### Task 6: Extraer el buscador de clientes a un widget compartido

**Files:**
- Create: `lib/widgets/selector_cliente.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart` (quitar `_SelectorCliente`, usar `SelectorCliente`)

**Interfaces:**
- Consumes: `ClienteTicket` de `lib/providers/ticket_provider.dart`, `listaClientesProvider`.
- Produces: `SelectorCliente({Key? key, required ClienteTicket? elegido, required ValueChanged<ClienteTicket?> onElegir, ValueChanged<String>? onEscribir, bool exigir = false})`. Mantiene las llaves `cliente_elegido`, `campo_cliente`, `cliente_sugerido_<id>`, `boton_cliente_nuevo`.

Refactor sin cambio de comportamiento: las pruebas existentes de `test/screens/venta/` son la red.

- [ ] **Step 1: Correr las pruebas de venta antes del cambio**

Run: `flutter test test/screens/venta`
Expected: PASS

- [ ] **Step 2: Crear el widget**

`lib/widgets/selector_cliente.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/clientes_providers.dart';
import '../providers/ticket_provider.dart';

/// Buscador de cliente para ventas fiadas: sugiere clientes existentes y
/// permite uno nuevo con el nombre escrito. Con un cliente [elegido] muestra
/// solo su chip, que se puede quitar.
class SelectorCliente extends ConsumerStatefulWidget {
  const SelectorCliente({
    super.key,
    required this.elegido,
    required this.onElegir,
    this.onEscribir,
    this.exigir = false,
  });

  final ClienteTicket? elegido;
  final ValueChanged<ClienteTicket?> onElegir;
  final ValueChanged<String>? onEscribir;

  /// Con true y nada escrito, muestra "Escribe o elige el cliente".
  final bool exigir;

  @override
  ConsumerState<SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends ConsumerState<SelectorCliente> {
  final _controller = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elegido = widget.elegido;
    if (elegido != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('cliente_elegido'),
          avatar: const Icon(Icons.person_rounded, size: 18),
          label: Text(elegido.nombre),
          onDeleted: () => widget.onElegir(null),
        ),
      );
    }

    final clientes =
        ref.watch(listaClientesProvider).valueOrNull ?? const <Cliente>[];
    final texto = _busqueda.trim();
    final buscado = texto.toLowerCase();
    final sugeridos = clientes
        .where((c) => c.nombre.toLowerCase().contains(buscado))
        .take(6)
        .toList();
    final existeExacto = clientes.any(
      (c) => c.nombre.trim().toLowerCase() == buscado,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('campo_cliente'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: '¿A quién le fías?',
            prefixIcon: const Icon(Icons.search_rounded),
            errorText: widget.exigir && texto.isEmpty
                ? 'Escribe o elige el cliente'
                : null,
          ),
          onChanged: (valor) {
            setState(() => _busqueda = valor);
            widget.onEscribir?.call(valor);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in sugeridos)
              ActionChip(
                key: Key('cliente_sugerido_${c.id}'),
                label: Text(c.nombre),
                onPressed: () =>
                    widget.onElegir(ClienteTicket(id: c.id, nombre: c.nombre)),
              ),
            if (texto.isNotEmpty && !existeExacto)
              ActionChip(
                key: const Key('boton_cliente_nuevo'),
                avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text('Nuevo: $texto'),
                onPressed: () => widget.onElegir(ClienteTicket(nombre: texto)),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Usarlo en Registrar venta**

En `lib/screens/venta/registrar_venta_screen.dart`:
- borrar las clases `_SelectorCliente` y `_SelectorClienteState` completas;
- agregar `import '../../widgets/selector_cliente.dart';`;
- reemplazar `const _SelectorCliente(),` por:

```dart
            SelectorCliente(
              elegido: ticket.cliente,
              onElegir: notifier.elegirCliente,
              onEscribir: notifier.escribirCliente,
              exigir: !ticket.estaVacio,
            ),
```

- si `clientes_providers.dart` queda sin uso en ese archivo, quitar su import (lo dirá `flutter analyze`).

- [ ] **Step 4: Correr y ver que todo sigue igual**

Run: `flutter test test/screens/venta` y `flutter analyze`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/selector_cliente.dart lib/screens/venta/registrar_venta_screen.dart
git commit -m "Extract the client picker into a shared widget"
```

---

### Task 7: Hoja de movimiento (detalle, corregir, anular)

**Files:**
- Create: `lib/screens/correccion/texto_correccion.dart`
- Create: `lib/screens/correccion/hoja_movimiento.dart`
- Modify: `lib/ui/monto.dart` (parámetro `tachado`)
- Test: `test/screens/correccion/texto_correccion_test.dart`
- Test: `test/screens/correccion/hoja_movimiento_test.dart`
- Modify: `test/ui/componentes_test.dart`

**Interfaces:**
- Consumes: `CorreccionRepository` y `correccionRepositoryProvider` (Task 4), `puedeCorregir` (Task 2), `MovimientoHistorial`/`MovimientoFiado` (Task 5), `SelectorCliente` (Task 6), `mostrarHojaInferior`, `avisar`, `TecladoMonto`/`aplicarTecla`, `SelectorSegmentado`, `BotonPrincipal`, `listaUsuariosProvider`, `sesionProvider`, `clienteRepositoryProvider.obtenerOCrearCliente`.
- Produces:
  - `Monto(int valor, {double tamano, TonoMonto tono, bool tachado = false})`
  - `String textoCorreccion(Correccion correccion, String nombreUsuario)`
  - `class MovimientoEditable` con `MovimientoEditable.desdeHistorial(MovimientoHistorial m, {String? nombreCliente})` y `MovimientoEditable.desdeFiado(MovimientoFiado m, {required int clienteId, required String nombreCliente})`
  - `Future<void> abrirHojaMovimiento(BuildContext context, MovimientoEditable movimiento)`
  - Llaves: `detalle_movimiento`, `texto_correccion`, `boton_corregir`, `boton_anular`, `confirmar_anular`, `editar_tipo_venta`, `editar_medio_pago`, `editar_descripcion`, `boton_guardar_correccion`.

- [ ] **Step 1: Escribir las pruebas que fallan (texto y Monto)**

`test/screens/correccion/texto_correccion_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/correccion/texto_correccion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Correccion correccion(TipoMovimiento tipo, AccionCorreccion accion) =>
      Correccion(
        id: 1,
        tipoMovimiento: tipo,
        movimientoId: 1,
        accion: accion,
        usuarioId: 1,
        fecha: DateTime(2026, 10, 6, 15, 40),
        antes: r'$5.000 · Contado · Efectivo',
      );

  test('una venta anulada va en femenino con la hora', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.venta, AccionCorreccion.anulado), 'Ana'),
        'Anulada por Ana · 15:40');
  });

  test('un gasto corregido va en masculino con el valor anterior', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.gasto, AccionCorreccion.corregido), 'Ana'),
        r'Corregido por Ana · antes: $5.000 · Contado · Efectivo');
  });

  test('un abono anulado va en masculino', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.abono, AccionCorreccion.anulado), 'Beto'),
        'Anulado por Beto · 15:40');
  });
}
```

En `test/ui/componentes_test.dart` agregar (con los imports que ya tenga ese archivo; `Monto` está en `package:app_ventas/ui/monto.dart`):

```dart
  testWidgets('Monto tachado se ve con línea y en gris', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Monto(5000, tachado: true)));
    final texto = tester.widget<Text>(find.text(r'$5.000'));
    expect(texto.style!.decoration, TextDecoration.lineThrough);
    expect(texto.style!.color, ColoresApp.textoSecundario);
  });
```

- [ ] **Step 2: Correr y ver que fallan**

Run: `flutter test test/screens/correccion/texto_correccion_test.dart test/ui/componentes_test.dart`
Expected: FAIL (`texto_correccion.dart` no existe; `tachado` no existe).

- [ ] **Step 3: Implementar texto y Monto tachado**

`lib/screens/correccion/texto_correccion.dart`:

```dart
import '../../data/database.dart';
import '../../util/fecha_util.dart';

/// "Anulada por Ana · 15:40" o "Corregida por Ana · antes: $5.000 · Efectivo".
/// Las ventas van en femenino; los abonos y los gastos, en masculino.
String textoCorreccion(Correccion correccion, String nombreUsuario) {
  final femenino = correccion.tipoMovimiento == TipoMovimiento.venta;
  if (correccion.accion == AccionCorreccion.anulado) {
    return '${femenino ? 'Anulada' : 'Anulado'} por $nombreUsuario · '
        '${formatoHora(correccion.fecha)}';
  }
  return '${femenino ? 'Corregida' : 'Corregido'} por $nombreUsuario · '
      'antes: ${correccion.antes}';
}
```

En `lib/ui/monto.dart`:
- constructor: agregar `this.tachado = false,` después de `this.tono = TonoMonto.neutro,`;
- campo con doc:

```dart
  /// Anulado: tachado y en gris, sin importar el tono.
  final bool tachado;
```

- en el `TextStyle` del `build`, reemplazar `color: colorDe(tono),` por:

```dart
          color: tachado ? ColoresApp.textoSecundario : colorDe(tono),
          decoration: tachado ? TextDecoration.lineThrough : null,
```

Run: `flutter test test/screens/correccion/texto_correccion_test.dart test/ui/componentes_test.dart`
Expected: PASS

- [ ] **Step 4: Escribir las pruebas de la hoja que fallan**

`test/screens/correccion/hoja_movimiento_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/correccion/hoja_movimiento.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/util/fecha_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Sesión de un usuario nuevo con [rol]; devuelve el container y el usuario.
  Future<(ProviderContainer, Usuario)> sesion({String rol = 'admin'}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    return (container, container.read(sesionProvider).usuarioActivo!);
  }

  Future<void> abrir(WidgetTester tester, ProviderContainer container,
      MovimientoEditable movimiento) async {
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => abrirHojaMovimiento(context, movimiento),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<Venta> venta(int id) =>
      (db.select(db.ventas)..where((v) => v.id.equals(id))).getSingle();

  MovimientoEditable deVenta(int id, Usuario dueno, {DateTime? fecha}) =>
      MovimientoEditable(
        tipo: TipoMovimiento.venta,
        id: id,
        monto: 5000,
        fecha: fecha ?? DateTime.now(),
        usuarioId: dueno.id,
      );

  bool guardarHabilitado(WidgetTester tester) =>
      tester
          .widget<BotonPrincipal>(
              find.byKey(const Key('boton_guardar_correccion')))
          .onPressed !=
      null;

  testWidgets('el administrador ve el detalle con Corregir y Anular',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);

    await abrir(tester, container, deVenta(id, ana));

    expect(find.text('Contado · Efectivo'), findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsOneWidget);
    expect(find.byKey(const Key('boton_anular')), findsOneWidget);
  });

  testWidgets('el vendedor no ve botones en una venta suya de ayer',
      (tester) async {
    final (container, beto) = await sesion(rol: 'vendedor');
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final id = await VentaRepository(db).registrarVenta(
        monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

    await abrir(tester, container, deVenta(id, beto, fecha: ayer));

    expect(find.text('Contado · Efectivo'), findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsNothing);
    expect(find.byKey(const Key('boton_anular')), findsNothing);
  });

  testWidgets('corregir el monto guarda, cierra la hoja y avisa',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();
    expect(guardarHabilitado(tester), isTrue);
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect((await venta(id)).monto, 500);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Venta corregida'), findsOneWidget);
  });

  testWidgets('un doble toque en Guardar guarda una sola corrección',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await db.select(db.correcciones).get(), hasLength(1));
  });

  testWidgets(
      'pasar a fiada exige cliente y usa el existente aunque cambien las '
      'mayúsculas', (tester) async {
    final (container, ana) = await sesion();
    final rosa =
        await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Rosa'));
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fiado'));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.enterText(find.byKey(const Key('campo_cliente')), 'rosa');
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isTrue);
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final v = await venta(id);
    expect(v.esFiado, isTrue);
    expect(v.clienteId, rosa);
    expect(await db.select(db.clientes).get(), hasLength(1));
  });

  testWidgets('anular pide confirmación; cancelar no cambia nada',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    expect(find.text(r'¿Anular esta venta de $5.000?'), findsOneWidget);
    expect(find.text('Ya no contará en los totales.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await venta(id)).anulado, isFalse);
    expect(find.byKey(const Key('boton_anular')), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular')));
    await tester.pumpAndSettle();

    expect((await venta(id)).anulado, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Venta anulada'), findsOneWidget);
  });

  testWidgets('un abono se corrige cambiando el medio de pago',
      (tester) async {
    final (container, ana) = await sesion();
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final fecha = DateTime.now();
    final id = await FiadoRepository(db).registrarPago(
        clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: fecha);
    await abrir(
        tester,
        container,
        MovimientoEditable(
            tipo: TipoMovimiento.abono,
            id: id,
            monto: 2000,
            fecha: fecha,
            usuarioId: ana.id,
            clienteId: pedro));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final pago = await (db.select(db.pagosFiado)..where((p) => p.id.equals(id)))
        .getSingle();
    expect(pago.medioPago, MedioPago.transferencia);
    expect(find.text('Abono corregido'), findsOneWidget);
  });

  testWidgets('un gasto se corrige cambiando la descripción', (tester) async {
    final (container, ana) = await sesion();
    final fecha = DateTime.now();
    final id = await GastoRepository(db).registrarGasto(
        monto: 1500, descripcion: 'Hielo', usuarioId: ana.id, fecha: fecha);
    await abrir(
        tester,
        container,
        MovimientoEditable(
            tipo: TipoMovimiento.gasto,
            id: id,
            monto: 1500,
            fecha: fecha,
            usuarioId: ana.id,
            descripcion: 'Hielo'));

    expect(find.text('Hielo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('editar_descripcion')), 'Hielo y bolsas');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    final gasto =
        await (db.select(db.gastos)..where((g) => g.id.equals(id))).getSingle();
    expect(gasto.descripcion, 'Hielo y bolsas');
    expect(find.text('Gasto corregido'), findsOneWidget);
  });

  testWidgets('un movimiento anulado dice quién lo anuló y no deja corregir',
      (tester) async {
    final (container, ana) = await sesion();
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await CorreccionRepository(db).anularVenta(id, por: ana);
    final correccion = await db.select(db.correcciones).getSingle();

    await abrir(
        tester,
        container,
        MovimientoEditable(
          tipo: TipoMovimiento.venta,
          id: id,
          monto: 5000,
          fecha: DateTime.now(),
          usuarioId: ana.id,
          anulado: true,
          ultimaCorreccion: correccion,
        ));

    expect(find.text('Anulada por Ana · ${formatoHora(correccion.fecha)}'),
        findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsNothing);
    expect(find.byKey(const Key('boton_anular')), findsNothing);
  });
}
```

- [ ] **Step 5: Correr y ver que falla**

Run: `flutter test test/screens/correccion/hoja_movimiento_test.dart`
Expected: FAIL (`hoja_movimiento.dart` no existe).

- [ ] **Step 6: Implementar la hoja**

`lib/screens/correccion/hoja_movimiento.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../repositories/historial_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/teclado_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/permisos.dart';
import '../../widgets/selector_cliente.dart';
import 'texto_correccion.dart';

/// Lo que la hoja necesita de un movimiento, venga del Historial o de Fiado.
class MovimientoEditable {
  const MovimientoEditable({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.clienteId,
    this.nombreCliente,
    this.medioPago = MedioPago.efectivo,
    this.descripcion,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  factory MovimientoEditable.desdeHistorial(
    MovimientoHistorial m, {
    String? nombreCliente,
  }) =>
      MovimientoEditable(
        tipo: m.tipo == TipoMovimientoHistorial.venta
            ? TipoMovimiento.venta
            : TipoMovimiento.gasto,
        id: m.id,
        monto: m.monto,
        fecha: m.fecha,
        usuarioId: m.usuarioId,
        esFiado: m.esFiado,
        clienteId: m.clienteId,
        nombreCliente: nombreCliente,
        medioPago: m.medioPago,
        descripcion: m.descripcion,
        anulado: m.anulado,
        ultimaCorreccion: m.ultimaCorreccion,
      );

  factory MovimientoEditable.desdeFiado(
    MovimientoFiado m, {
    required int clienteId,
    required String nombreCliente,
  }) {
    final esVenta = m.tipo == TipoMovimientoFiado.venta;
    return MovimientoEditable(
      tipo: esVenta ? TipoMovimiento.venta : TipoMovimiento.abono,
      id: m.id,
      monto: m.monto,
      fecha: m.fecha,
      usuarioId: m.usuarioId,
      esFiado: esVenta,
      clienteId: clienteId,
      nombreCliente: nombreCliente,
      medioPago: m.medioPago,
      anulado: m.anulado,
      ultimaCorreccion: m.ultimaCorreccion,
    );
  }

  final TipoMovimiento tipo;
  final int id;
  final int monto;
  final DateTime fecha;

  /// Quién lo registró.
  final int usuarioId;
  final bool esFiado;
  final int? clienteId;
  final String? nombreCliente;
  final MedioPago medioPago;
  final String? descripcion;
  final bool anulado;
  final Correccion? ultimaCorreccion;
}

String _titulo(TipoMovimiento tipo) => switch (tipo) {
      TipoMovimiento.venta => 'Venta',
      TipoMovimiento.abono => 'Abono',
      TipoMovimiento.gasto => 'Gasto',
    };

String _esteMovimiento(TipoMovimiento tipo) => switch (tipo) {
      TipoMovimiento.venta => 'esta venta',
      TipoMovimiento.abono => 'este abono',
      TipoMovimiento.gasto => 'este gasto',
    };

String _aviso(TipoMovimiento tipo, {required bool anulado}) => switch (tipo) {
      TipoMovimiento.venta => anulado ? 'Venta anulada' : 'Venta corregida',
      TipoMovimiento.abono => anulado ? 'Abono anulado' : 'Abono corregido',
      TipoMovimiento.gasto => anulado ? 'Gasto anulado' : 'Gasto corregido',
    };

String _nombreMedio(MedioPago medio) =>
    medio == MedioPago.efectivo ? 'Efectivo' : 'Transferencia';

/// Abre el detalle de [movimiento]; si se corrige o anula, avisa al cerrar.
Future<void> abrirHojaMovimiento(
  BuildContext context,
  MovimientoEditable movimiento,
) async {
  final aviso = await mostrarHojaInferior<String>(
    context,
    titulo: _titulo(movimiento.tipo),
    builder: (_) => HojaMovimiento(movimiento: movimiento),
  );
  if (aviso != null && context.mounted) avisar(context, aviso);
}

/// Detalle de un movimiento con Corregir y Anular si el usuario puede.
/// Al guardar o anular se cierra devolviendo el texto del aviso.
class HojaMovimiento extends ConsumerStatefulWidget {
  const HojaMovimiento({super.key, required this.movimiento});

  final MovimientoEditable movimiento;

  @override
  ConsumerState<HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends ConsumerState<HojaMovimiento> {
  bool _editando = false;
  late int _monto = widget.movimiento.monto;
  late bool _esFiado = widget.movimiento.esFiado;
  late MedioPago _medio = widget.movimiento.medioPago;
  late ClienteTicket? _cliente =
      widget.movimiento.esFiado && widget.movimiento.clienteId != null
          ? ClienteTicket(
              id: widget.movimiento.clienteId,
              nombre: widget.movimiento.nombreCliente ?? '')
          : null;
  String _escrito = '';
  late final _descripcion =
      TextEditingController(text: widget.movimiento.descripcion ?? '');

  /// True mientras se guarda; evita guardar dos veces con un doble toque.
  bool _guardando = false;
  String? _error;

  MovimientoEditable get _m => widget.movimiento;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  ClienteTicket? get _clienteElegido {
    if (_cliente != null) return _cliente;
    final nombre = _escrito.trim();
    return nombre.isEmpty ? null : ClienteTicket(nombre: nombre);
  }

  bool get _hayCambios {
    if (_monto != _m.monto) return true;
    return switch (_m.tipo) {
      TipoMovimiento.venta => _esFiado != _m.esFiado ||
          (_esFiado
              ? _clienteElegido?.id != _m.clienteId
              : _medio != _m.medioPago),
      TipoMovimiento.abono => _medio != _m.medioPago,
      TipoMovimiento.gasto =>
        _descripcion.text.trim() != (_m.descripcion?.trim() ?? ''),
    };
  }

  bool get _valido =>
      _monto > 0 &&
      (_m.tipo != TipoMovimiento.venta || !_esFiado || _clienteElegido != null);

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final por = ref.read(sesionProvider).usuarioActivo!;
      final repo = ref.read(correccionRepositoryProvider);
      switch (_m.tipo) {
        case TipoMovimiento.venta:
          int? clienteId;
          if (_esFiado) {
            final cliente = _clienteElegido!;
            clienteId = cliente.id ??
                await ref
                    .read(clienteRepositoryProvider)
                    .obtenerOCrearCliente(cliente.nombre);
          }
          await repo.corregirVenta(_m.id,
              monto: _monto,
              esFiado: _esFiado,
              clienteId: clienteId,
              medioPago: _medio,
              por: por);
        case TipoMovimiento.abono:
          await repo.corregirPago(_m.id,
              monto: _monto, medioPago: _medio, por: por);
        case TipoMovimiento.gasto:
          final descripcion = _descripcion.text.trim();
          await repo.corregirGasto(_m.id,
              monto: _monto,
              descripcion: descripcion.isEmpty ? null : descripcion,
              por: por);
      }
      if (mounted) {
        Navigator.of(context).pop(_aviso(_m.tipo, anulado: false));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _anular() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Anular ${_esteMovimiento(_m.tipo)} de '
            '${formatoMoneda(_m.monto)}?'),
        content: const Text('Ya no contará en los totales.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar_anular'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final por = ref.read(sesionProvider).usuarioActivo!;
      final repo = ref.read(correccionRepositoryProvider);
      switch (_m.tipo) {
        case TipoMovimiento.venta:
          await repo.anularVenta(_m.id, por: por);
        case TipoMovimiento.abono:
          await repo.anularPago(_m.id, por: por);
        case TipoMovimiento.gasto:
          await repo.anularGasto(_m.id, por: por);
      }
      if (mounted) Navigator.of(context).pop(_aviso(_m.tipo, anulado: true));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String get _detalle => switch (_m.tipo) {
        TipoMovimiento.venta => _m.esFiado
            ? 'Fiado · ${_m.nombreCliente ?? ''}'
            : 'Contado · ${_nombreMedio(_m.medioPago)}',
        TipoMovimiento.abono => 'Abono · ${_nombreMedio(_m.medioPago)}',
        TipoMovimiento.gasto => (_m.descripcion?.trim().isNotEmpty ?? false)
            ? _m.descripcion!.trim()
            : 'Gasto',
      };

  Widget? get _textoError => _error == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ColoresApp.sale),
          ),
        );

  @override
  Widget build(BuildContext context) =>
      _editando ? _formulario() : _vistaDetalle();

  Widget _vistaDetalle() {
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};
    final usuario = ref.watch(sesionProvider).usuarioActivo;
    final puede = usuario != null &&
        !_m.anulado &&
        puedeCorregir(
          usuario: usuario,
          duenoId: _m.usuarioId,
          fechaMovimiento: _m.fecha,
          ahora: DateTime.now(),
        );
    final correccion = _m.ultimaCorreccion;
    final error = _textoError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Monto(_m.monto, tamano: 32, tachado: _m.anulado),
        const SizedBox(height: 4),
        Text(_detalle, key: const Key('detalle_movimiento')),
        Text(
          '${nombres[_m.usuarioId] ?? ''} · ${formatoFechaHora(_m.fecha)}',
          style: const TextStyle(color: ColoresApp.textoSecundario),
        ),
        if (correccion != null) ...[
          const SizedBox(height: 8),
          Text(
            textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
            key: const Key('texto_correccion'),
            style: const TextStyle(color: ColoresApp.textoSecundario),
          ),
        ],
        ?error,
        if (puede) ...[
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_corregir'),
            texto: 'Corregir',
            onPressed: () => setState(() => _editando = true),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('boton_anular'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
            onPressed: _guardando ? null : _anular,
            child: const Text('Anular'),
          ),
        ],
      ],
    );
  }

  Widget _selectorMedio() => SelectorSegmentado<MedioPago>(
        key: const Key('editar_medio_pago'),
        opciones: const {
          MedioPago.efectivo: 'Efectivo',
          MedioPago.transferencia: 'Transferencia',
        },
        valor: _medio,
        onCambio: (medio) => setState(() => _medio = medio),
      );

  Widget _formulario() {
    final error = _textoError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_m.tipo == TipoMovimiento.venta) ...[
          SelectorSegmentado<bool>(
            key: const Key('editar_tipo_venta'),
            opciones: const {false: 'Contado', true: 'Fiado'},
            valor: _esFiado,
            onCambio: (fiado) => setState(() => _esFiado = fiado),
          ),
          const SizedBox(height: 12),
          if (_esFiado)
            SelectorCliente(
              elegido: _cliente,
              onElegir: (cliente) => setState(() => _cliente = cliente),
              onEscribir: (texto) => setState(() => _escrito = texto),
              exigir: true,
            )
          else
            _selectorMedio(),
        ],
        if (_m.tipo == TipoMovimiento.abono) _selectorMedio(),
        if (_m.tipo == TipoMovimiento.gasto)
          TextField(
            key: const Key('editar_descripcion'),
            controller: _descripcion,
            decoration: const InputDecoration(labelText: 'Descripción'),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        Center(child: Monto(_monto, tamano: 36)),
        ?error,
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) => setState(() {
            _monto = aplicarTecla(_monto, tecla);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_guardar_correccion'),
          texto: 'Guardar',
          onPressed: _hayCambios && _valido && !_guardando ? _guardar : null,
        ),
      ],
    );
  }
}
```

Nota: `?error` es la sintaxis de elemento nulo de Dart 3.8+ (el proyecto usa ^3.13). Si `flutter analyze` la rechaza, cambiar por `if (error != null) error,`.

- [ ] **Step 7: Correr y ver que pasa**

Run: `flutter test test/screens/correccion test/ui`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/ui/monto.dart lib/screens/correccion test/screens/correccion test/ui/componentes_test.dart
git commit -m "Add the movement sheet to view, correct or void a sale, payment or expense"
```

---

### Task 8: Historial — tocar, tachar y totales sin anulados

**Files:**
- Modify: `lib/screens/historial/historial_screen.dart`
- Modify: `test/screens/historial/historial_screen_test.dart`

**Interfaces:**
- Consumes: `MovimientoHistorial` con `id`, `clienteId`, `anulado`, `ultimaCorreccion` (Task 5); `abrirHojaMovimiento`, `MovimientoEditable.desdeHistorial`, `textoCorreccion`, `Monto(tachado:)` (Task 7); `listaClientesProvider`.
- Produces: cada fila con llave `movimiento_<venta|gasto>_<id>`; línea de corrección en gris bajo el subtítulo.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/historial/historial_screen_test.dart` agregar imports:

```dart
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/ui/monto.dart';
import '../../support/montaje.dart';
```

y las pruebas:

```dart
  Future<Usuario> usuario(int id) =>
      (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();

  testWidgets(
      'una venta anulada se ve tachada, dice quién la anuló y no suma',
      (tester) async {
    final anulada =
        await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await ventas.registrarVenta(monto: 3000, esFiado: false, usuarioId: ana);
    await CorreccionRepository(db).anularVenta(anulada, por: await usuario(ana));
    await montar(tester);

    expect(enTotal('total_ventas', r'$3.000'), findsOneWidget);
    final monto = tester.widget<Monto>(find.descendant(
        of: find.byKey(Key('movimiento_venta_$anulada')),
        matching: find.byType(Monto)));
    expect(monto.tachado, isTrue);
    expect(find.textContaining('Anulada por Ana · '), findsOneWidget);
  });

  testWidgets('un gasto corregido muestra el valor anterior', (tester) async {
    final id = await gastos.registrarGasto(
        monto: 1000, descripcion: 'Hielo', usuarioId: ana);
    await CorreccionRepository(db).corregirGasto(id,
        monto: 1200, descripcion: 'Hielo', por: await usuario(ana));
    await montar(tester);

    expect(enTotal('total_gastos', r'$1.200'), findsOneWidget);
    expect(find.text(r'Corregido por Ana · antes: $1.000 · Hielo'),
        findsOneWidget);
  });

  testWidgets('sin sesión, tocar un movimiento muestra solo su detalle',
      (tester) async {
    final id =
        await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await montar(tester);

    await tester.tap(find.byKey(Key('movimiento_venta_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detalle_movimiento')), findsOneWidget);
    expect(find.byKey(const Key('boton_corregir')), findsNothing);
  });

  testWidgets('anular desde el Historial descuenta la venta del total',
      (tester) async {
    final container = await containerConSesion(db, nombre: 'Caro');
    addTearDown(container.dispose);
    final id =
        await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const HistorialScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('movimiento_venta_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular')));
    await tester.pumpAndSettle();

    expect(enTotal('total_ventas', r'$0'), findsOneWidget);
    expect(find.text('Venta anulada'), findsOneWidget);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/historial/historial_screen_test.dart`
Expected: FAIL (no hay llave `movimiento_venta_<id>`; el total cuenta lo anulado).

- [ ] **Step 3: Implementar**

En `lib/screens/historial/historial_screen.dart`:
- imports nuevos:

```dart
import '../../providers/clientes_providers.dart';
import '../correccion/hoja_movimiento.dart';
import '../correccion/texto_correccion.dart';
```

- en `build`, después de `final nombres = ...`:

```dart
    final clientes = {
      for (final c
          in ref.watch(listaClientesProvider).valueOrNull ?? const <Cliente>[])
        c.id: c.nombre,
    };
```

- en los totales, excluir lo anulado:

```dart
                final totalVentas = movimientos
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.venta)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                final totalGastos = movimientos
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.gasto)
                    .fold<int>(0, (suma, m) => suma + m.monto);
```

- la lista:

```dart
                            for (final m in movimientos)
                              _MovimientoTile(
                                movimiento: m,
                                nombres: nombres,
                                onTap: () => abrirHojaMovimiento(
                                  context,
                                  MovimientoEditable.desdeHistorial(m,
                                      nombreCliente: clientes[m.clienteId]),
                                ),
                              ),
```

- reemplazar `_MovimientoTile` completo:

```dart
class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({
    required this.movimiento,
    required this.nombres,
    required this.onTap,
  });

  final MovimientoHistorial movimiento;

  /// Nombre de cada usuario por id.
  final Map<int, String> nombres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esGasto = movimiento.tipo == TipoMovimientoHistorial.gasto;
    final color = esGasto ? ColoresApp.sale : ColoresApp.entra;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');
    final correccion = movimiento.ultimaCorreccion;

    return ListTile(
      key: Key('movimiento_${movimiento.tipo.name}_${movimiento.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esGasto ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Monto(movimiento.monto,
              tamano: 16,
              tono: esGasto ? TonoMonto.sale : TonoMonto.neutro,
              tachado: movimiento.anulado),
          if (!esGasto &&
              movimiento.medioPago == MedioPago.transferencia) ...[
            const SizedBox(width: 8),
            const EtiquetaQr(),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$detalle · ${nombres[movimiento.usuarioId] ?? ''}'),
          if (correccion != null)
            Text(
              textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
              style: const TextStyle(
                  fontSize: 12, color: ColoresApp.textoSecundario),
            ),
        ],
      ),
      trailing: Text(formatoHora(movimiento.fecha),
          style: const TextStyle(color: ColoresApp.textoSecundario)),
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/historial`
Expected: PASS (incluidas las pruebas viejas: `'Contado · Ana'` sigue siendo un `Text` exacto).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/historial/historial_screen.dart test/screens/historial/historial_screen_test.dart
git commit -m "Open the movement sheet from Historial and show voided and corrected rows"
```

---

### Task 9: Fiado — corregir y anular desde el detalle del cliente

**Files:**
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart`
- Modify: `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `MovimientoFiado` con `id`, `usuarioId`, `anulado`, `ultimaCorreccion` (Task 5); `abrirHojaMovimiento`, `MovimientoEditable.desdeFiado`, `textoCorreccion`, `Monto(tachado:)` (Task 7); `listaUsuariosProvider`.
- Produces: cada fila con llave `movimiento_fiado_<venta|abono>_<id>`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/fiado/detalle_cliente_screen_test.dart` agregar `import 'package:app_ventas/ui/monto.dart';` y:

```dart
  testWidgets('anular la venta fiada la tacha y deja el saldo en 0',
      (tester) async {
    final clienteId = await montarDetalle(tester);
    final ventaId = (await db.select(db.ventas).getSingle()).id;

    await tester.tap(find.byKey(Key('movimiento_fiado_venta_$ventaId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_anular')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 0);
    expect(saldo(r'$0'), findsOneWidget);
    final monto = tester.widget<Monto>(find.descendant(
        of: find.byKey(Key('movimiento_fiado_venta_$ventaId')),
        matching: find.byType(Monto)));
    expect(monto.tachado, isTrue);
    expect(find.textContaining('Anulada por Ana · '), findsOneWidget);
    expect(find.text('Venta anulada'), findsOneWidget);
  });

  testWidgets('corregir un abono cambia el saldo y muestra el valor anterior',
      (tester) async {
    final clienteId = await montarDetalle(tester);
    final usuarioId = (await db.select(db.usuarios).getSingle()).id;
    final pagoId = await FiadoRepository(db).registrarPago(
        clienteId: clienteId, monto: 2000, usuarioId: usuarioId);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('movimiento_fiado_abono_$pagoId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 4800);
    expect(saldo(r'$4.800'), findsOneWidget);
    expect(find.text(r'Corregido por Ana · antes: $2.000 · Efectivo'),
        findsOneWidget);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/fiado/detalle_cliente_screen_test.dart`
Expected: FAIL (no hay llaves `movimiento_fiado_...`).

- [ ] **Step 3: Implementar**

En `lib/screens/fiado/detalle_cliente_screen.dart`:
- imports nuevos:

```dart
import '../../data/database.dart';
import '../../providers/usuarios_providers.dart';
import '../correccion/hoja_movimiento.dart';
import '../correccion/texto_correccion.dart';
```

  (quitar `import '../../data/medio_pago.dart';`, que ya llega por `database.dart`).

- en `build`, antes del `return Scaffold(`:

```dart
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};
```

- la lista de movimientos:

```dart
                  for (final m in movimientos)
                    _FilaMovimiento(
                      movimiento: m,
                      nombres: nombres,
                      onTap: () => abrirHojaMovimiento(
                        context,
                        MovimientoEditable.desdeFiado(m,
                            clienteId: cliente.id,
                            nombreCliente: cliente.nombre),
                      ),
                    ),
```

- reemplazar `_FilaMovimiento` completo:

```dart
class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.movimiento,
    required this.nombres,
    required this.onTap,
  });

  final MovimientoFiado movimiento;

  /// Nombre de cada usuario por id.
  final Map<int, String> nombres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esAbono = movimiento.tipo == TipoMovimientoFiado.abono;
    final color = esAbono ? ColoresApp.entra : ColoresApp.fiado;
    final correccion = movimiento.ultimaCorreccion;
    return ListTile(
      key: Key('movimiento_fiado_${movimiento.tipo.name}_${movimiento.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esAbono ? Icons.payments_rounded : Icons.shopping_bag_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Monto(movimiento.monto,
              tamano: 16,
              tono: esAbono ? TonoMonto.entra : TonoMonto.fiado,
              tachado: movimiento.anulado),
          if (esAbono && movimiento.medioPago == MedioPago.transferencia) ...[
            const SizedBox(width: 8),
            const EtiquetaQr(),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatoFechaHora(movimiento.fecha)),
          if (correccion != null)
            Text(
              textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
              style: const TextStyle(
                  fontSize: 12, color: ColoresApp.textoSecundario),
            ),
        ],
      ),
      trailing: Text(esAbono ? 'Abono' : 'Venta fiada'),
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/fiado`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/fiado/detalle_cliente_screen.dart test/screens/fiado/detalle_cliente_screen_test.dart
git commit -m "Correct and void sales and payments from the client detail"
```

---

### Task 10: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-vecitienda-corregir-anular-design.md` (línea `**Estado:**`)

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test`
Expected: "No issues found!" y todas las pruebas pasan.

- [ ] **Step 2: Prueba manual en el emulador**

```bash
flutter build apk --debug
```

Instalar en el emulador `app_ventas_ligero` (`adb install -r build/app/outputs/flutter-apk/app-debug.apk`) y comprobar a mano, entrando como administrador:
1. Registrar una venta de contado de $5.000; en Historial tocarla → Corregir → borrar un dígito → Guardar: el total baja a $500 y aparece "Corregida por …".
2. Anular esa venta: queda tachada y el total de Inicio vuelve a $0.
3. En Fiado, registrar una venta fiada y anularla desde el detalle del cliente: el cliente sale de la lista.
4. Entrar como vendedor: en una venta de otro usuario no aparecen Corregir ni Anular.

- [ ] **Step 3: Marcar la especificación como implementada**

En la especificación, cambiar `**Estado:** Diseño aprobado, pendiente de plan` por `**Estado:** Implementado`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-06-vecitienda-corregir-anular-design.md
git commit -m "Mark Fase 3A as implemented"
```
