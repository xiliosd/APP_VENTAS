# Fase 2D — Cobro por QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cobrar ventas de contado y abonos de fiado por transferencia mostrando el QR que el tendero cargó, y separar en el resumen del día lo recibido en efectivo y por transferencia.

**Architecture:** El esquema Drift sube a v2: columna `medioPago` (enum `MedioPago` guardado como texto) en `ventas` y `pagos_fiado`, y tabla de una fila `configuracion_tienda` con la imagen del QR en un BLOB. Un `ConfiguracionRepository` lee/escribe el QR; una pantalla reutilizable `CobroQrScreen` muestra el QR y devuelve `true` solo con "Recibido". La venta y el abono se registran después de esa confirmación.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ drift_dev/build_runner), sqlite3 3.5, `image_picker` (nuevo).

**Spec:** `docs/superpowers/specs/2026-10-05-app-ventas-fase2d-cobro-qr-design.md`

## Global Constraints

- Valores de medio de pago: `'efectivo' | 'transferencia'`; por defecto `'efectivo'`.
- Las ventas fiadas guardan `efectivo` y **no** cuentan en los totales por medio de pago.
- `schemaVersion = 2`. `CopiaBaseDatos.tablas` **no cambia** (sigue con las 6 tablas de v1) para que los respaldos v1 sigan siendo válidos.
- Imagen del QR: `image_picker` con `maxWidth: 1024`, `maxHeight: 1024`, `imageQuality: 85`.
- Textos exactos: "Cobro por QR", "Pide al cliente que escanee y digite este valor", "Aún no has cargado tu QR", "Configurar QR", "Recibido", "Cancelar", "Cargar QR", "Cambiar QR", "Quitar QR", "Descarga tu QR desde la app de Nequi, Daviplata o tu banco y cárgalo aquí.", "No se pudo cargar la imagen, prueba con otra", "No se pudo mostrar el QR", "Efectivo", "Transferencia", "Cobrar $X por QR", "Recibido: efectivo $X · transferencias $Y", etiqueta "QR".
- Toda la UI en español; contraste de texto ≥ 4.5:1 (reglas de la 2E/marca).
- La app sigue funcionando sin internet.
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.

## Review Focus

1. Doble toque en "Recibido" → un solo registro y no se cierra la pantalla de abajo (prueba en Task 3).
2. Volver con el botón atrás del sistema desde el cobro por QR → no se guarda nada y el ticket queda intacto (prueba en Task 4).
3. Imagen guardada que no se puede decodificar → mensaje "No se pudo mostrar el QR", sin excepción (prueba en Task 3).
4. Abono por transferencia mayor que la deuda → error antes de abrir el QR, nada guardado (prueba en Task 5).
5. Restaurar un respaldo hecho con la app v1 (sin `medio_pago` ni `configuracion_tienda`) → se restaura y migra, todo queda en efectivo (prueba en Task 1).

---

### Task 1: Esquema v2, `MedioPago` y migración

**Files:**
- Create: `lib/data/medio_pago.dart`
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v1.dart`
- Create: `test/data/migracion_test.dart`
- Modify: `test/respaldo/restaurador_test.dart`

**Interfaces:**
- Produces: `enum MedioPago { efectivo, transferencia }`; `Venta.medioPago` y `PagoFiado.medioPago` de tipo `MedioPago`; `VentasCompanion.medioPago` / `PagosFiadoCompanion.medioPago` (`Value<MedioPago>`); tabla `db.configuracionTienda` con data class `ConfiguracionTiendaFila { int id; Uint8List? imagenQr; }`; `AppDatabase.schemaVersion == 2`; helper de prueba `void crearBaseV1(String ruta)`.

- [ ] **Step 1: Write the failing tests**

`test/support/esquema_v1.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

/// Crea en [ruta] una base con el esquema v1 de la app (antes de la 2D), con
/// un usuario, una venta de contado y un abono.
void crearBaseV1(String ruta) {
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE usuarios (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, rol TEXT NOT NULL, pin_hash TEXT NOT NULL);
      CREATE TABLE productos (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, precio INTEGER NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)));
      CREATE TABLE clientes (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, telefono TEXT NULL, notas TEXT NULL);
      CREATE TABLE ventas (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        monto INTEGER NOT NULL, producto_id INTEGER NULL REFERENCES productos (id),
        fecha INTEGER NOT NULL,
        es_fiado INTEGER NOT NULL DEFAULT 0 CHECK (es_fiado IN (0, 1)),
        cliente_id INTEGER NULL REFERENCES clientes (id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      CREATE TABLE pagos_fiado (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL REFERENCES clientes (id),
        monto INTEGER NOT NULL, fecha INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      CREATE TABLE gastos (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        monto INTEGER NOT NULL, descripcion TEXT NULL, fecha INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      INSERT INTO usuarios (nombre, rol, pin_hash) VALUES ('Ana', 'admin', 'x');
      INSERT INTO clientes (nombre) VALUES ('Don Pedro');
      INSERT INTO ventas (monto, fecha, es_fiado, usuario_id)
        VALUES (5000, 1788000000, 0, 1);
      INSERT INTO pagos_fiado (cliente_id, monto, fecha, usuario_id)
        VALUES (1, 2000, 1788000000, 1);
    ''')
    ..userVersion = 1
    ..close();
}
```

`test/data/migracion_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/data/medio_pago.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v1.dart';

void main() {
  late Directory carpeta;

  setUp(() async => carpeta = await Directory.systemTemp.createTemp('migra'));
  tearDown(() => carpeta.delete(recursive: true));

  test('una base v1 abre en v2 con ventas y abonos en efectivo', () async {
    final archivo = File('${carpeta.path}/v1.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final ventas = await db.select(db.ventas).get();
    final pagos = await db.select(db.pagosFiado).get();
    expect(ventas.single.medioPago, MedioPago.efectivo);
    expect(pagos.single.medioPago, MedioPago.efectivo);
    expect(await db.select(db.configuracionTienda).get(), isEmpty);
  });

  test('una base nueva guarda el medio de pago y la imagen del QR', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 1000,
          fecha: DateTime(2026, 10, 5),
          usuarioId: usuario,
          medioPago: const Value(MedioPago.transferencia),
        ));
    await db.into(db.configuracionTienda).insert(
        ConfiguracionTiendaCompanion.insert(
            id: const Value(1), imagenQr: Value(Uint8List.fromList([1, 2]))));

    expect((await db.select(db.ventas).getSingle()).medioPago,
        MedioPago.transferencia);
    expect((await db.select(db.configuracionTienda).getSingle()).imagenQr,
        [1, 2]);
    expect(db.schemaVersion, 2);
  });
}
```

Añadir al final de `main()` en `test/respaldo/restaurador_test.dart` (y el import `import '../support/esquema_v1.dart';` arriba):

```dart
  test('restaura un respaldo hecho con la versión 1 de la app', () async {
    final copiaV1 = File('${(await carpeta.createTemp('v1')).path}/r.sqlite');
    crearBaseV1(copiaV1.path);
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copiaV1);
    final local = AppDatabase(NativeDatabase(archivoLocal));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.restaurado);
    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    final ventas = await reabierta.select(reabierta.ventas).get();
    expect(ventas.single.monto, 5000);
    expect(ventas.single.medioPago, MedioPago.efectivo);
    await reabierta.close();
  });
```

(con `import 'package:app_ventas/data/medio_pago.dart';`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/migracion_test.dart test/respaldo/restaurador_test.dart`
Expected: FAIL de compilación: `medio_pago.dart` no existe / `medioPago` y `configuracionTienda` no definidos.

- [ ] **Step 3: Implement**

`lib/data/medio_pago.dart`:

```dart
/// Cómo se recibió el dinero de una venta de contado o de un abono.
enum MedioPago { efectivo, transferencia }
```

En `lib/data/database.dart`:
- Añadir `import 'dart:typed_data';` (si el analizador lo pide) e `import 'medio_pago.dart';` y `export 'medio_pago.dart';` debajo de los imports existentes.
- En `Ventas` y en `PagosFiado` agregar:

```dart
  TextColumn get medioPago => textEnum<MedioPago>()
      .withDefault(const Constant('efectivo'))();
```

- Nueva tabla antes de `@DriftDatabase`:

```dart
/// Configuración de la tienda: una sola fila (id 1).
@DataClassName('ConfiguracionTiendaFila')
class ConfiguracionTienda extends Table {
  IntColumn get id => integer()();
  BlobColumn get imagenQr => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- `@DriftDatabase(tables: [Usuarios, Productos, Clientes, Ventas, PagosFiado, Gastos, ConfiguracionTienda])`.
- Reemplazar `int get schemaVersion => 1;` por:

```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, desde, hasta) async {
          if (desde < 2) {
            await m.addColumn(ventas, ventas.medioPago);
            await m.addColumn(pagosFiado, pagosFiado.medioPago);
            await m.createTable(configuracionTienda);
          }
        },
      );
```

Luego: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/ test/respaldo/`
Expected: PASS (incluidas las pruebas de respaldo existentes; `CopiaBaseDatos.tablas` no se toca).

- [ ] **Step 5: Run the full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add lib/data test/data test/support/esquema_v1.dart test/respaldo/restaurador_test.dart
git commit -m "Add payment method column and store settings table (schema v2)"
```

---

### Task 2: Repositorios con medio de pago y QR

**Files:**
- Create: `lib/repositories/configuracion_repository.dart`
- Modify: `lib/repositories/venta_repository.dart`, `lib/repositories/fiado_repository.dart`, `lib/repositories/resumen_repository.dart`, `lib/repositories/historial_repository.dart`, `lib/providers/repository_providers.dart`
- Create: `lib/providers/configuracion_providers.dart`
- Create: `test/repositories/configuracion_repository_test.dart`
- Modify: `test/repositories/venta_repository_test.dart`, `test/repositories/fiado_repository_test.dart`, `test/repositories/resumen_repository_test.dart`, `test/repositories/historial_repository_test.dart`, `test/respaldo/restaurador_test.dart`

**Interfaces:**
- Consumes: `MedioPago`, `db.configuracionTienda`, `ConfiguracionTiendaCompanion` (Task 1).
- Produces:
  - `ConfiguracionRepository(AppDatabase)`: `Future<Uint8List?> imagenQr()`, `Stream<Uint8List?> observarImagenQr()`, `Future<void> guardarImagenQr(Uint8List bytes)`, `Future<void> quitarImagenQr()`.
  - `configuracionRepositoryProvider` (Provider) y `imagenQrProvider` (`StreamProvider.autoDispose<Uint8List?>`) en `lib/providers/configuracion_providers.dart`.
  - `VentaRepository.registrarVenta({..., MedioPago medioPago = MedioPago.efectivo})`.
  - `FiadoRepository.registrarPago({..., MedioPago medioPago = MedioPago.efectivo})`, `Future<List<PagoFiado>> pagosDelDia(DateTime dia, {int? usuarioId})`, `MovimientoFiado.medioPago` (default efectivo).
  - `ResumenDia.recibidoEfectivo`, `ResumenDia.recibidoTransferencia` (int, default 0).
  - `MovimientoHistorial.medioPago` (default efectivo).

- [ ] **Step 1: Write the failing tests**

`test/repositories/configuracion_repository_test.dart`:

```dart
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConfiguracionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ConfiguracionRepository(db);
  });
  tearDown(() => db.close());

  test('sin QR cargado devuelve null', () async {
    expect(await repo.imagenQr(), isNull);
  });

  test('guardar, reemplazar y quitar el QR', () async {
    await repo.guardarImagenQr(Uint8List.fromList([1, 2, 3]));
    expect(await repo.imagenQr(), [1, 2, 3]);

    await repo.guardarImagenQr(Uint8List.fromList([9]));
    expect(await repo.imagenQr(), [9]);
    expect(await db.select(db.configuracionTienda).get(), hasLength(1));

    await repo.quitarImagenQr();
    expect(await repo.imagenQr(), isNull);
  });

  test('observarImagenQr emite los cambios', () async {
    final emitidos = <Uint8List?>[];
    final sub = repo.observarImagenQr().listen(emitidos.add);
    await pumpEventQueue();
    await repo.guardarImagenQr(Uint8List.fromList([7]));
    await pumpEventQueue();
    await sub.cancel();

    expect(emitidos.first, isNull);
    expect(emitidos.last, [7]);
  });
}
```

En `test/repositories/venta_repository_test.dart` añadir (usa el `repo`/usuario del `setUp` existente; ajustar nombres a los del archivo):

```dart
  test('registrarVenta guarda el medio de pago (efectivo por defecto)',
      () async {
    final a = await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: usuarioId);
    final b = await repo.registrarVenta(
        monto: 2000,
        esFiado: false,
        usuarioId: usuarioId,
        medioPago: MedioPago.transferencia);

    final ventas = await db.select(db.ventas).get();
    expect(ventas.firstWhere((v) => v.id == a).medioPago, MedioPago.efectivo);
    expect(ventas.firstWhere((v) => v.id == b).medioPago,
        MedioPago.transferencia);
  });
```

En `test/repositories/fiado_repository_test.dart` añadir:

```dart
  test('registrarPago guarda el medio y pagosDelDia filtra por día y usuario',
      () async {
    final dia = DateTime(2026, 10, 5, 10);
    await repo.registrarPago(
        clienteId: clienteId, monto: 1000, usuarioId: usuarioId, fecha: dia);
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: dia,
        medioPago: MedioPago.transferencia);
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 500,
        usuarioId: usuarioId,
        fecha: dia.subtract(const Duration(days: 1)));

    final pagos = await repo.pagosDelDia(dia);
    expect(pagos.map((p) => p.monto), unorderedEquals([1000, 2000]));
    expect(pagos.firstWhere((p) => p.monto == 2000).medioPago,
        MedioPago.transferencia);
    expect(await repo.pagosDelDia(dia, usuarioId: usuarioId + 99), isEmpty);

    final movimientos = await repo.movimientosCliente(clienteId);
    expect(movimientos.firstWhere((m) => m.monto == 2000).medioPago,
        MedioPago.transferencia);
  });
```

(Si el `setUp` del archivo no expone `clienteId`/`usuarioId`, crear el usuario y el cliente dentro de la prueba con `db.into(...)`.)

En `test/repositories/resumen_repository_test.dart` añadir:

```dart
  test('recibido separa efectivo y transferencia, sin fiado y con abonos',
      () async {
    final fiadoRepo = FiadoRepository(db);
    final cliente = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 3000,
        esFiado: false,
        usuarioId: vendedor2,
        fecha: dia,
        medioPago: MedioPago.transferencia);
    await ventaRepo.registrarVenta(
        monto: 9000,
        esFiado: true,
        clienteId: cliente,
        usuarioId: vendedor1,
        fecha: dia);
    await fiadoRepo.registrarPago(
        clienteId: cliente,
        monto: 2000,
        usuarioId: vendedor1,
        fecha: dia,
        medioPago: MedioPago.transferencia);
    await fiadoRepo.registrarPago(
        clienteId: cliente, monto: 1000, usuarioId: vendedor2, fecha: dia);

    final todo = await repo.resumenDelDia(dia);
    expect(todo.recibidoEfectivo, 6000);
    expect(todo.recibidoTransferencia, 5000);

    final soloAna = await repo.resumenDelDia(dia, usuarioId: vendedor1);
    expect(soloAna.recibidoEfectivo, 5000);
    expect(soloAna.recibidoTransferencia, 2000);
  });
```

En `test/repositories/historial_repository_test.dart` añadir una prueba que registre una venta con `medioPago: MedioPago.transferencia` y verifique `movimientos.single.medioPago == MedioPago.transferencia` (usar el repo y usuario del `setUp` del archivo).

En `test/respaldo/restaurador_test.dart` añadir:

```dart
  test('el respaldo restaurado conserva la imagen del QR', () async {
    final origen = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(origen)
        .guardarImagenQr(Uint8List.fromList([4, 5, 6]));
    final copia = await CopiaBaseDatos.crearCopia(
        origen, await carpeta.createTemp('origenqr'));
    await origen.close();
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copia);
    final local = AppDatabase(NativeDatabase(archivoLocal));

    await restaurador.restaurar(nube, local);

    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    expect(await ConfiguracionRepository(reabierta).imagenQr(), [4, 5, 6]);
    await reabierta.close();
  });
```

(imports: `dart:typed_data`, `package:app_ventas/repositories/configuracion_repository.dart`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/ test/respaldo/restaurador_test.dart`
Expected: FAIL de compilación (`ConfiguracionRepository`, parámetro `medioPago`, `pagosDelDia`, `recibidoEfectivo` no existen).

- [ ] **Step 3: Implement**

`lib/repositories/configuracion_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../data/database.dart';

/// Configuración de la tienda (una sola fila, id 1). Por ahora, el QR de cobro.
class ConfiguracionRepository {
  ConfiguracionRepository(this._db);

  final AppDatabase _db;

  static const _id = 1;

  SimpleSelectStatement<$ConfiguracionTiendaTable, ConfiguracionTiendaFila>
      get _fila => _db.select(_db.configuracionTienda)
        ..where((c) => c.id.equals(_id));

  Future<Uint8List?> imagenQr() async =>
      (await _fila.getSingleOrNull())?.imagenQr;

  Stream<Uint8List?> observarImagenQr() =>
      _fila.watchSingleOrNull().map((fila) => fila?.imagenQr);

  Future<void> guardarImagenQr(Uint8List bytes) =>
      _db.into(_db.configuracionTienda).insertOnConflictUpdate(
            ConfiguracionTiendaCompanion.insert(
                id: const Value(_id), imagenQr: Value(bytes)),
          );

  Future<void> quitarImagenQr() =>
      _db.into(_db.configuracionTienda).insertOnConflictUpdate(
            const ConfiguracionTiendaCompanion(
                id: Value(_id), imagenQr: Value(null)),
          );
}
```

`lib/providers/configuracion_providers.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/configuracion_repository.dart';
import 'database_provider.dart';

final configuracionRepositoryProvider = Provider(
  (ref) => ConfiguracionRepository(ref.watch(databaseProvider)),
);

/// QR de cobro cargado por el admin; null si no hay.
final imagenQrProvider = StreamProvider.autoDispose<Uint8List?>(
  (ref) => ref.watch(configuracionRepositoryProvider).observarImagenQr(),
);
```

`VentaRepository.registrarVenta`: añadir el parámetro `MedioPago medioPago = MedioPago.efectivo,` y en el companion `medioPago: Value(medioPago),`.

`FiadoRepository`:
- `MovimientoFiado` gana `this.medioPago = MedioPago.efectivo` y `final MedioPago medioPago;`; en `movimientosCliente`, los abonos pasan `medioPago: p.medioPago`.
- `registrarPago` gana `MedioPago medioPago = MedioPago.efectivo,` y `medioPago: Value(medioPago),` en el companion.
- Nuevo método:

```dart
  Future<List<PagoFiado>> pagosDelDia(DateTime dia, {int? usuarioId}) {
    final query = _db.select(_db.pagosFiado)
      ..where((p) =>
          p.fecha.isBiggerOrEqualValue(inicioDelDia(dia)) &
          p.fecha.isSmallerOrEqualValue(finDelDia(dia)));
    if (usuarioId != null) {
      query.where((p) => p.usuarioId.equals(usuarioId));
    }
    return query.get();
  }
```

`ResumenRepository`:
- `ResumenDia` gana `this.recibidoEfectivo = 0, this.recibidoTransferencia = 0,` y sus campos `final int` documentados: `/// Ventas de contado y abonos del día recibidos en efectivo.` / `/// ... por transferencia.`
- En `resumenDelDia`, tras leer ventas y gastos:

```dart
    final pagos =
        await _fiadoRepository.pagosDelDia(dia, usuarioId: usuarioId);
    int recibido(MedioPago medio) =>
        ventas
            .where((v) => !v.esFiado && v.medioPago == medio)
            .fold<int>(0, (suma, v) => suma + v.monto) +
        pagos
            .where((p) => p.medioPago == medio)
            .fold<int>(0, (suma, p) => suma + p.monto);
```

  y pasar `recibidoEfectivo: recibido(MedioPago.efectivo), recibidoTransferencia: recibido(MedioPago.transferencia),` al constructor.

`HistorialRepository`: `MovimientoHistorial` gana `this.medioPago = MedioPago.efectivo` / `final MedioPago medioPago;` (doc: `/// Solo aplica a ventas.`); las ventas pasan `medioPago: v.medioPago`. Importar `../data/medio_pago.dart`.

`lib/providers/repository_providers.dart`: sin cambios (el provider nuevo vive en `configuracion_providers.dart`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/repositories/ test/respaldo/`
Expected: PASS.

- [ ] **Step 5: Full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add lib/repositories lib/providers test/repositories test/respaldo
git commit -m "Record payment method on sales and payments and store the QR image"
```

---

### Task 3: Pantallas de QR (cobro y configuración)

**Files:**
- Modify: `pubspec.yaml` (dependencia `image_picker`)
- Create: `lib/screens/qr/selector_imagen.dart`
- Create: `lib/screens/qr/cobro_qr_screen.dart`
- Create: `lib/screens/qr/configurar_qr_screen.dart`
- Create: `lib/ui/etiqueta_qr.dart`
- Modify: `lib/screens/configuracion/ajustes_screen.dart`
- Create: `test/support/imagen_prueba.dart`
- Create: `test/screens/qr/cobro_qr_screen_test.dart`
- Create: `test/screens/qr/configurar_qr_screen_test.dart`

**Interfaces:**
- Consumes: `configuracionRepositoryProvider`, `imagenQrProvider`, `ConfiguracionRepository` (Task 2); `sesionProvider.esAdmin`.
- Produces:
  - `abstract class SelectorImagen { Future<Uint8List?> elegir(); }`, `SelectorImagenGaleria`, `selectorImagenProvider`.
  - `CobroQrScreen({required int monto})` que hace `pop(true)` con "Recibido" y `pop(false)` con "Cancelar".
  - `Future<bool> abrirCobroQr(BuildContext context, {required int monto})`.
  - `ConfigurarQrScreen()`.
  - `EtiquetaQr()` (widget con `Key('etiqueta_qr')` y texto "QR").
  - Entrada de Ajustes con `Key('menu_cobro_qr')`.
  - Test helpers: `pngDePrueba` (Uint8List) y `SelectorImagenFalso({Uint8List? bytes, Object? error})`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add image_picker`
Expected: `image_picker` en `dependencies` de `pubspec.yaml`. (En Android 13+ usa el selector de fotos del sistema; no hace falta permiso nuevo.)

- [ ] **Step 2: Write the failing tests**

`test/support/imagen_prueba.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_ventas/screens/qr/selector_imagen.dart';

/// PNG válido de 1x1 px.
final Uint8List pngDePrueba = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class SelectorImagenFalso implements SelectorImagen {
  SelectorImagenFalso({this.bytes, this.error});

  final Uint8List? bytes;
  final Object? error;

  @override
  Future<Uint8List?> elegir() async {
    if (error != null) throw error!;
    return bytes;
  }
}
```

`test/screens/qr/cobro_qr_screen_test.dart`:

```dart
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/qr/cobro_qr_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/imagen_prueba.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Abre el cobro por $12.000 encima de "Inicio" y guarda lo que devuelve.
  Future<List<bool>> abrir(WidgetTester tester, {String rol = 'admin'}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    final resultados = <bool>[];
    abrirCobroQr(navegador.currentContext!, monto: 12000)
        .then(resultados.add);
    await tester.pumpAndSettle();
    return resultados;
  }

  testWidgets('muestra el total, la instrucción y el QR cargado',
      (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await abrir(tester);

    expect(find.text(r'$12.000'), findsOneWidget);
    expect(find.text('Pide al cliente que escanee y digite este valor'),
        findsOneWidget);
    expect(find.byKey(const Key('imagen_qr')), findsOneWidget);
  });

  testWidgets('Recibido devuelve true y Cancelar devuelve false',
      (tester) async {
    var resultados = await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.pumpAndSettle();
    expect(resultados, [true]);

    abrirCobroQr(navegador.currentContext!, monto: 12000)
        .then(resultados.add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_qr_cancelar')));
    await tester.pumpAndSettle();
    expect(resultados, [true, false]);
  });

  testWidgets('un doble toque en Recibido cierra solo el cobro',
      (tester) async {
    final resultados = await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.tap(find.byKey(const Key('boton_qr_recibido')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(resultados, [true]);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('sin QR, el admin ve el aviso y Configurar QR', (tester) async {
    await abrir(tester);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
    expect(find.byKey(const Key('boton_configurar_qr')), findsOneWidget);
    expect(find.byKey(const Key('boton_qr_recibido')), findsOneWidget);
  });

  testWidgets('sin QR, el vendedor no ve Configurar QR', (tester) async {
    await abrir(tester, rol: 'vendedor');
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
    expect(find.byKey(const Key('boton_configurar_qr')), findsNothing);
  });

  testWidgets('una imagen dañada muestra un mensaje en vez de fallar',
      (tester) async {
    await ConfiguracionRepository(db)
        .guardarImagenQr(Uint8List.fromList([1, 2, 3]));
    await abrir(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('No se pudo mostrar el QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en un celular pequeño con letra grande no se desborda',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);

    await abrir(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('boton_qr_recibido')), findsOneWidget);
  });
}
```

`test/screens/qr/configurar_qr_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/qr/configurar_qr_screen.dart';
import 'package:app_ventas/screens/qr/selector_imagen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/imagen_prueba.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester, SelectorImagen selector,
      {Widget inicio = const ConfigurarQrScreen()}) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final conSelector = ProviderContainer(
      parent: container,
      overrides: [selectorImagenProvider.overrideWithValue(selector)],
    );
    addTearDown(conSelector.dispose);
    await tester.pumpWidget(appDePrueba(conSelector, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('sin QR muestra la ayuda y Cargar QR lo guarda',
      (tester) async {
    await montar(tester, SelectorImagenFalso(bytes: pngDePrueba));
    expect(
        find.text('Descarga tu QR desde la app de Nequi, Daviplata o tu '
            'banco y cárgalo aquí.'),
        findsOneWidget);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();

    expect(await ConfiguracionRepository(db).imagenQr(), pngDePrueba);
    expect(find.byKey(const Key('vista_qr')), findsOneWidget);
    expect(find.text('Cambiar QR'), findsOneWidget);
  });

  testWidgets('si no se elige imagen no cambia nada', (tester) async {
    await montar(tester, SelectorImagenFalso());
    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
  });

  testWidgets('si falla la lectura avisa y no guarda', (tester) async {
    await montar(tester, SelectorImagenFalso(error: Exception('x')));
    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar la imagen, prueba con otra'),
        findsOneWidget);
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
  });

  testWidgets('Quitar QR lo borra', (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await montar(tester, SelectorImagenFalso());
    await tester.tap(find.byKey(const Key('boton_quitar_qr')));
    await tester.pumpAndSettle();
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
  });

  testWidgets('Ajustes tiene la entrada Cobro por QR', (tester) async {
    await montar(tester, SelectorImagenFalso(),
        inicio: const Scaffold(body: AjustesScreen()));
    await tester.tap(find.byKey(const Key('menu_cobro_qr')));
    await tester.pumpAndSettle();
    expect(find.byType(ConfigurarQrScreen), findsOneWidget);
  });
}
```

(Si `ProviderContainer(parent:)` con `UncontrolledProviderScope` diera problemas, crear el container directamente con `overrides: [databaseProvider.overrideWithValue(db), selectorImagenProvider.overrideWithValue(selector)]` y fijar la sesión como en `containerConSesion`.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/screens/qr/`
Expected: FAIL de compilación (no existen `selector_imagen.dart`, `cobro_qr_screen.dart`, `configurar_qr_screen.dart`).

- [ ] **Step 4: Implement**

`lib/screens/qr/selector_imagen.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Elige una imagen y devuelve sus bytes, o null si no se eligió ninguna.
abstract class SelectorImagen {
  Future<Uint8List?> elegir();
}

/// Galería del celular; reduce la imagen a 1024 px como máximo.
class SelectorImagenGaleria implements SelectorImagen {
  @override
  Future<Uint8List?> elegir() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return archivo?.readAsBytes();
  }
}

final selectorImagenProvider =
    Provider<SelectorImagen>((ref) => SelectorImagenGaleria());
```

`lib/ui/etiqueta_qr.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Marca pequeña "QR" para ventas y abonos recibidos por transferencia.
class EtiquetaQr extends StatelessWidget {
  const EtiquetaQr({super.key = const Key('etiqueta_qr')});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.primario.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'QR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColoresApp.primario,
        ),
      ),
    );
  }
}
```

`lib/screens/qr/cobro_qr_screen.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/monto.dart';
import 'configurar_qr_screen.dart';

/// Abre el cobro por QR de [monto]. true solo si el tendero tocó "Recibido".
Future<bool> abrirCobroQr(BuildContext context, {required int monto}) async {
  final recibido = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => CobroQrScreen(monto: monto)),
  );
  return recibido == true;
}

class CobroQrScreen extends ConsumerStatefulWidget {
  const CobroQrScreen({super.key, required this.monto});

  final int monto;

  @override
  ConsumerState<CobroQrScreen> createState() => _CobroQrScreenState();
}

class _CobroQrScreenState extends ConsumerState<CobroQrScreen> {
  /// Evita que un doble toque cierre también la pantalla de abajo.
  bool _cerrando = false;

  void _cerrar(bool recibido) {
    if (_cerrando) return;
    _cerrando = true;
    Navigator.of(context).pop(recibido);
  }

  @override
  Widget build(BuildContext context) {
    final imagen = ref.watch(imagenQrProvider);
    final esAdmin = ref.watch(sesionProvider).esAdmin;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cobro por QR'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Monto(widget.monto, tamano: 44)),
              const SizedBox(height: 4),
              const Text(
                'Pide al cliente que escanee y digite este valor',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresApp.textoSecundario),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: imagen.when(
                  data: (bytes) => bytes == null
                      ? _SinQr(esAdmin: esAdmin)
                      : _ImagenQr(bytes),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const _QrIlegible(),
                ),
              ),
              const SizedBox(height: 16),
              BotonPrincipal(
                key: const Key('boton_qr_recibido'),
                texto: 'Recibido',
                variante: VarianteBoton.entra,
                onPressed: () => _cerrar(true),
              ),
              const SizedBox(height: 8),
              BotonPrincipal(
                key: const Key('boton_qr_cancelar'),
                texto: 'Cancelar',
                variante: VarianteBoton.contorno,
                onPressed: () => _cerrar(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagenQr extends StatelessWidget {
  const _ImagenQr(this.bytes);

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.memory(
        bytes,
        key: const Key('imagen_qr'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _QrIlegible(),
      ),
    );
  }
}

class _QrIlegible extends StatelessWidget {
  const _QrIlegible();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No se pudo mostrar el QR',
        textAlign: TextAlign.center,
        style: TextStyle(color: ColoresApp.textoSecundario),
      ),
    );
  }
}

class _SinQr extends StatelessWidget {
  const _SinQr({required this.esAdmin});

  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded,
                size: 64, color: ColoresApp.textoSecundario),
            const SizedBox(height: 8),
            const Text('Aún no has cargado tu QR',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (esAdmin) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('boton_configurar_qr'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConfigurarQrScreen()),
                ),
                child: const Text('Configurar QR'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`lib/screens/qr/configurar_qr_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import 'selector_imagen.dart';

class ConfigurarQrScreen extends ConsumerStatefulWidget {
  const ConfigurarQrScreen({super.key});

  @override
  ConsumerState<ConfigurarQrScreen> createState() =>
      _ConfigurarQrScreenState();
}

class _ConfigurarQrScreenState extends ConsumerState<ConfigurarQrScreen> {
  bool _ocupado = false;

  Future<void> _cargar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await ref.read(selectorImagenProvider).elegir();
      if (bytes == null) return;
      await ref.read(configuracionRepositoryProvider).guardarImagenQr(bytes);
      if (mounted) avisar(context, 'QR guardado');
    } catch (_) {
      if (mounted) {
        avisar(context, 'No se pudo cargar la imagen, prueba con otra');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _quitar() async {
    await ref.read(configuracionRepositoryProvider).quitarImagenQr();
    if (mounted) avisar(context, 'QR quitado');
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ref.watch(imagenQrProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobro por QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Descarga tu QR desde la app de Nequi, Daviplata o tu banco y '
            'cárgalo aquí.',
            style: TextStyle(color: ColoresApp.textoSecundario),
          ),
          const SizedBox(height: 16),
          if (bytes == null)
            const EstadoVacio(
              icono: Icons.qr_code_2_rounded,
              titulo: 'Aún no has cargado tu QR',
            )
          else
            SizedBox(
              key: const Key('vista_qr'),
              height: 280,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('No se pudo mostrar el QR'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_cargar_qr'),
            texto: bytes == null ? 'Cargar QR' : 'Cambiar QR',
            onPressed: _ocupado ? null : _cargar,
          ),
          if (bytes != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('boton_quitar_qr'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
              onPressed: _quitar,
              child: const Text('Quitar QR'),
            ),
          ],
        ],
      ),
    );
  }
}
```

En `lib/screens/configuracion/ajustes_screen.dart`, dentro de la tarjeta "TIENDA", después de la entrada de Usuarios (antes de Respaldo), añadir:

```dart
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_cobro_qr'),
                leading: const Icon(Icons.qr_code_2_rounded),
                title: const Text('Cobro por QR'),
                subtitle: const Text('Tu QR de Nequi, Daviplata o banco'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConfigurarQrScreen()),
                ),
              ),
```

con `import '../qr/configurar_qr_screen.dart';`. (Ajustes solo es visible para el admin; el vendedor no ve esta entrada.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/screens/qr/ test/screens/home/`
Expected: PASS.

- [ ] **Step 6: Full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add pubspec.yaml pubspec.lock lib/screens/qr lib/ui/etiqueta_qr.dart lib/screens/configuracion/ajustes_screen.dart test/support/imagen_prueba.dart test/screens/qr
git commit -m "Add QR payment screen and QR settings"
```

---

### Task 4: Cobrar una venta por transferencia

**Files:**
- Modify: `lib/providers/ticket_provider.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart`
- Modify: `test/providers/ticket_provider_test.dart`
- Modify: `test/screens/venta/registrar_venta_screen_test.dart`

**Interfaces:**
- Consumes: `MedioPago` (Task 1), `VentaRepository.registrarVenta(medioPago:)` (Task 2), `abrirCobroQr` (Task 3).
- Produces: `Ticket.medioPago` (default `MedioPago.efectivo`), `TicketNotifier.cambiarMedioPago(MedioPago)`; selector con `Key('selector_medio_pago')`.

- [ ] **Step 1: Write the failing tests**

En `test/providers/ticket_provider_test.dart` añadir (siguiendo el estilo del archivo para crear el container y leer el notifier):

```dart
  test('el medio de pago empieza en efectivo, cambia y vuelve al vaciar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(ticketProvider, (_, __) {});
    addTearDown(sub.close);
    final notifier = container.read(ticketProvider.notifier);

    expect(container.read(ticketProvider).medioPago, MedioPago.efectivo);
    notifier.agregarMonto(1000);
    notifier.cambiarMedioPago(MedioPago.transferencia);
    notifier.sumar('m1000');
    expect(container.read(ticketProvider).medioPago, MedioPago.transferencia);

    notifier.vaciar();
    expect(container.read(ticketProvider).medioPago, MedioPago.efectivo);
  });
```

(import `package:app_ventas/data/medio_pago.dart`.)

En `test/screens/venta/registrar_venta_screen_test.dart` añadir (imports: `package:app_ventas/data/medio_pago.dart`, `package:app_ventas/repositories/configuracion_repository.dart`, `../../support/imagen_prueba.dart`):

```dart
  testWidgets('Transferencia: el QR se muestra y Recibido guarda la venta',
      (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.text('Transferencia'));
    await tester.pump();
    expect(find.text(r'Cobrar $5.000 por QR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('imagen_qr')), findsOneWidget);
    expect(await db.select(db.ventas).get(), isEmpty);

    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 5000);
    expect(venta.medioPago, MedioPago.transferencia);
    expect(find.text(r'Venta registrada · $5.000'), findsOneWidget);
  });

  testWidgets('Cancelar en el QR no guarda y deja el ticket igual',
      (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.text('Transferencia'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_qr_cancelar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $5.000 por QR'), findsOneWidget);
  });

  testWidgets('volver atrás desde el QR no guarda y deja el ticket igual',
      (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.text('Transferencia'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $5.000 por QR'), findsOneWidget);
    expect(find.byKey(const Key('boton_cobrar')), findsOneWidget);
  });

  testWidgets('con Fiado no aparece el selector de medio de pago',
      (tester) async {
    await abrirVenta(tester);
    expect(find.byKey(const Key('selector_medio_pago')), findsOneWidget);
    await tester.tap(find.text('Fiado'));
    await tester.pump();
    expect(find.byKey(const Key('selector_medio_pago')), findsNothing);
  });

  testWidgets('Efectivo registra como siempre, en efectivo', (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    expect((await db.select(db.ventas).get()).single.medioPago,
        MedioPago.efectivo);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/ticket_provider_test.dart test/screens/venta/`
Expected: FAIL (`medioPago`/`cambiarMedioPago` no existen; no hay "Transferencia" en pantalla).

- [ ] **Step 3: Implement**

`lib/providers/ticket_provider.dart`:
- `import '../data/medio_pago.dart';`
- `Ticket` gana `this.medioPago = MedioPago.efectivo,` en el constructor y el campo `/// Solo aplica a ventas de contado.\n  final MedioPago medioPago;`.
- Cada `Ticket(...)` creado en `cambiarFiado`, `elegirCliente`, `escribirCliente` y `_conLineas` pasa `medioPago: state.medioPago`.
- `vaciar` deja de usar `_conLineas` y vuelve a efectivo:

```dart
  void vaciar() => state = Ticket(
    esFiado: state.esFiado,
    cliente: state.cliente,
    nombreEscrito: state.nombreEscrito,
  );
```

- Nuevo:

```dart
  void cambiarMedioPago(MedioPago medio) => state = Ticket(
    lineas: state.lineas,
    esFiado: state.esFiado,
    cliente: state.cliente,
    nombreEscrito: state.nombreEscrito,
    medioPago: medio,
  );
```

`lib/screens/venta/registrar_venta_screen.dart`:
- Imports: `../../data/medio_pago.dart`, `../qr/cobro_qr_screen.dart`.
- En `_cobrar`, justo después de `final ticket = ref.read(ticketProvider);`:

```dart
      final porQr =
          !ticket.esFiado && ticket.medioPago == MedioPago.transferencia;
      if (porQr) {
        final recibido = await abrirCobroQr(context, monto: ticket.total);
        if (!recibido || !mounted) return;
      }
```

  y en `registrarVenta(...)` añadir `medioPago: porQr ? MedioPago.transferencia : MedioPago.efectivo,`.
- En `build`, después del bloque `if (ticket.esFiado) ...[...]`:

```dart
          if (!ticket.esFiado) ...[
            const SizedBox(height: 12),
            SelectorSegmentado<MedioPago>(
              key: const Key('selector_medio_pago'),
              opciones: const {
                MedioPago.efectivo: 'Efectivo',
                MedioPago.transferencia: 'Transferencia',
              },
              valor: ticket.medioPago,
              onCambio: notifier.cambiarMedioPago,
            ),
          ],
```

- En `_BarraCobro.build`, el texto de contado:

```dart
    final texto = !ticket.esFiado
        ? (ticket.medioPago == MedioPago.transferencia
            ? 'Cobrar $total por QR'
            : 'Cobrar $total')
        : cliente == null
        ? 'Fiar $total'
        : 'Fiar $total a ${cliente.nombre}';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/providers/ test/screens/venta/`
Expected: PASS (también las pruebas existentes de la venta, incluida la de "Ver ticket" a 360 dp).

- [ ] **Step 5: Full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add lib/providers/ticket_provider.dart lib/screens/venta test/providers test/screens/venta
git commit -m "Let a cash sale be charged by bank transfer through the QR screen"
```

---

### Task 5: Abono de fiado por transferencia

**Files:**
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart`
- Modify: `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `FiadoRepository.registrarPago(medioPago:)`, `MovimientoFiado.medioPago` (Task 2); `abrirCobroQr`, `EtiquetaQr` (Task 3).
- Produces: selector `Key('selector_medio_abono')` en la hoja de abono.

- [ ] **Step 1: Write the failing tests**

En `test/screens/fiado/detalle_cliente_screen_test.dart` añadir (imports `package:app_ventas/data/medio_pago.dart`):

```dart
  testWidgets('un abono por transferencia pasa por el QR y queda marcado',
      (tester) async {
    await montarDetalle(tester);
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await teclear(tester, ['2', '0', '0', '0']);
    await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boton_qr_recibido')), findsOneWidget);
    expect(await db.select(db.pagosFiado).get(), isEmpty);

    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.pumpAndSettle();

    final pago = (await db.select(db.pagosFiado).get()).single;
    expect(pago.monto, 2000);
    expect(pago.medioPago, MedioPago.transferencia);
    expect(find.byKey(const Key('etiqueta_qr')), findsOneWidget);
  });

  testWidgets('cancelar el QR del abono no registra nada', (tester) async {
    await montarDetalle(tester);
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await teclear(tester, ['1', '0', '0', '0']);
    await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_qr_cancelar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.pagosFiado).get(), isEmpty);
  });

  testWidgets('un abono por QR mayor que la deuda da error sin abrir el QR',
      (tester) async {
    await montarDetalle(tester);
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await teclear(tester, ['9', '0', '0', '0']);
    await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(find.byKey(const Key('boton_qr_recibido')), findsNothing);
    expect(await db.select(db.pagosFiado).get(), isEmpty);
  });

  testWidgets('un abono en efectivo no lleva la etiqueta QR', (tester) async {
    await montarDetalle(tester);
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['1', '0', '0', '0']);
    await tester.ensureVisible(find.byKey(const Key('boton_confirmar_abono')));
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect((await db.select(db.pagosFiado).get()).single.medioPago,
        MedioPago.efectivo);
    expect(find.byKey(const Key('etiqueta_qr')), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/fiado/detalle_cliente_screen_test.dart`
Expected: FAIL (no hay "Transferencia" en la hoja de abono).

- [ ] **Step 3: Implement**

En `lib/screens/fiado/detalle_cliente_screen.dart`:
- Imports: `../../data/medio_pago.dart`, `../../ui/etiqueta_qr.dart`, `../../ui/selector_segmentado.dart`, `../qr/cobro_qr_screen.dart`.
- `_HojaAbonoState` gana `MedioPago _medio = MedioPago.efectivo;`.
- En `_guardar`, después de la validación del saldo y antes de leer la sesión:

```dart
    if (_medio == MedioPago.transferencia) {
      final recibido = await abrirCobroQr(context, monto: _monto);
      if (!recibido || !mounted) return;
    }
```

  y `registrarPago(..., medioPago: _medio)`.
- En `build` de la hoja, como primer hijo de la `Column`:

```dart
        SelectorSegmentado<MedioPago>(
          key: const Key('selector_medio_abono'),
          opciones: const {
            MedioPago.efectivo: 'Efectivo',
            MedioPago.transferencia: 'Transferencia',
          },
          valor: _medio,
          onCambio: (medio) => setState(() => _medio = medio),
        ),
        const SizedBox(height: 12),
```

- En `_MovimientoTile` (movimientos del cliente), el `title` pasa a:

```dart
      title: Row(
        children: [
          Monto(movimiento.monto,
              tamano: 16, tono: esAbono ? TonoMonto.entra : TonoMonto.fiado),
          if (esAbono && movimiento.medioPago == MedioPago.transferencia) ...[
            const SizedBox(width: 8),
            const EtiquetaQr(),
          ],
        ],
      ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/fiado/`
Expected: PASS, incluidas las pruebas de abono existentes. Si alguna existente no alcanza `boton_confirmar_abono` por el selector nuevo, añadir `await tester.ensureVisible(...)` antes del toque y registrarlo como ruling.

- [ ] **Step 5: Full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add lib/screens/fiado test/screens/fiado
git commit -m "Let a credit payment be received by bank transfer through the QR screen"
```

---

### Task 6: Recibido en Inicio, etiqueta en Historial y documentación

**Files:**
- Modify: `lib/screens/home/resumen_screen.dart`
- Modify: `lib/screens/historial/historial_screen.dart`
- Modify: `test/screens/home/resumen_screen_test.dart`
- Modify: `test/screens/historial/historial_screen_test.dart`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-10-05-app-ventas-fase2d-cobro-qr-design.md` (Estado)

**Interfaces:**
- Consumes: `ResumenDia.recibidoEfectivo/recibidoTransferencia`, `MovimientoHistorial.medioPago` (Task 2); `EtiquetaQr` (Task 3).
- Produces: `Text` con `Key('texto_recibido')` en la tarjeta de ventas.

- [ ] **Step 1: Write the failing tests**

En `test/screens/home/resumen_screen_test.dart` añadir (import `package:app_ventas/data/medio_pago.dart`):

```dart
  testWidgets('la tarjeta de ventas muestra lo recibido por medio de pago',
      (tester) async {
    await vender(5000);
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 3000,
          fecha: DateTime.now(),
          usuarioId: ana,
          medioPago: const Value(MedioPago.transferencia),
        ));
    await vender(9000, fiado: true);

    await montar(tester);

    expect(
        enTarjeta('tarjeta_ventas',
            r'Recibido: efectivo $5.000 · transferencias $3.000'),
        findsOneWidget);
  });
```

En `test/screens/historial/historial_screen_test.dart` añadir:

```dart
  testWidgets('una venta por transferencia lleva la etiqueta QR',
      (tester) async {
    await ventas.registrarVenta(
        monto: 4000,
        esFiado: false,
        usuarioId: ana,
        medioPago: MedioPago.transferencia);
    await ventas.registrarVenta(monto: 1000, esFiado: false, usuarioId: ana);

    await montar(tester);

    expect(find.byKey(const Key('etiqueta_qr')), findsOneWidget);
  });
```

(import `package:app_ventas/data/medio_pago.dart`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/home/resumen_screen_test.dart test/screens/historial/`
Expected: FAIL (no existe el texto "Recibido: …" ni la etiqueta en el historial).

- [ ] **Step 3: Implement**

`lib/screens/home/resumen_screen.dart`: importar `../../util/formato_moneda.dart` y, en la tarjeta `tarjeta_ventas`, después del `Text` de cantidades:

```dart
              const SizedBox(height: 2),
              Text(
                'Recibido: efectivo ${formatoMoneda(resumen.recibidoEfectivo)}'
                ' · transferencias '
                '${formatoMoneda(resumen.recibidoTransferencia)}',
                key: const Key('texto_recibido'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
```

`lib/screens/historial/historial_screen.dart`: importar `../../data/medio_pago.dart` y `../../ui/etiqueta_qr.dart`; en `_MovimientoTile` el `title` pasa a:

```dart
      title: Row(
        children: [
          Monto(movimiento.monto,
              tamano: 16, tono: esGasto ? TonoMonto.sale : TonoMonto.neutro),
          if (!esGasto &&
              movimiento.medioPago == MedioPago.transferencia) ...[
            const SizedBox(width: 8),
            const EtiquetaQr(),
          ],
        ],
      ),
```

`README.md`, sección "## Fase 2": reemplazar la línea de la 2D por:

```markdown
- **2D — Cobro por QR** (hecho): el admin carga en Ajustes → "Cobro por QR" la
  imagen del QR de su Nequi, Daviplata o banco; las ventas de contado y los
  abonos pueden cobrarse por transferencia (se guardan al tocar "Recibido") y el
  Inicio separa lo recibido en efectivo y por transferencias.
```

En el spec, `**Estado:** Borrador para revisión` → `**Estado:** Implementado`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/`
Expected: PASS.

- [ ] **Step 5: Full suite and commit**

Run: `flutter analyze && flutter test`
Expected: No issues; todas pasan.

```bash
git add lib/screens/home lib/screens/historial test/screens/home test/screens/historial README.md docs/superpowers/specs/2026-10-05-app-ventas-fase2d-cobro-qr-design.md
git commit -m "Show cash and transfer totals on Inicio and tag QR sales in history"
```

- [ ] **Step 6: Manual check (emulator)**

`flutter run` en el emulador: cargar una captura de QR desde Ajustes, cobrar una venta y un abono por transferencia, y comprobar la línea "Recibido" en Inicio y la etiqueta "QR" en el Historial. Si es posible, escanear el QR mostrado con otro celular.
