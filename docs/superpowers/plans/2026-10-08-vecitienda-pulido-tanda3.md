# Pulido Tanda 3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mejoras internas: guardados atómicos, repositorios sin construirse entre sí y Reportes sin trabajo de más.

**Architecture:** Un `CatalogoRepository` nuevo que envuelve en una transacción el guardado
completo de un producto; `corregirVenta` crea el cliente nuevo dentro de su transacción; una
función `saldoDeCliente` compartida; `deudasTotalesAl` calcula varias fechas con una lectura;
ajustes pequeños en providers y orden del ranking.

**Tech Stack:** Flutter, Riverpod 2, Drift (transacciones anidadas en la misma zona), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-08-vecitienda-pulido-tanda3-design.md`

## Global Constraints

- Esquema v7 sin cambios; sin dependencias nuevas.
- Comportamiento visible igual: textos y flujos de pantalla no cambian.
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- Rama `pulido-tanda3` desde `master`.

## Review Focus

- Editar un producto existente (no nuevo) que falla al guardar: el producto conserva sus datos previos (rollback también de la edición) — Task 1.
- Reintentar después de un fallo con proveedor nuevo: un solo proveedor creado — Task 1.
- Corregir una venta fiada eligiendo un cliente existente (con id): sigue igual — Task 2.
- Reportes con clientes con saldo a favor: la deuda de cada fecha sigue sin restar — Task 5.
- Desactivar el control en un producto que falla al guardar no deja el control apagado a medias — Task 1.

---

### Task 1: Guardar un producto en una sola transacción

**Files:**
- Create: `lib/repositories/catalogo_repository.dart`, `test/repositories/catalogo_repository_test.dart`
- Modify: `lib/providers/repository_providers.dart`, `lib/screens/configuracion/producto_screen.dart` (`_guardar`, `_Fila`, `_productoIdGuardado`)

**Interfaces — Produces:** `ProveedorEnFormulario`, `ControlEnFormulario`,
`CatalogoRepository(AppDatabase, ProductoRepository, ProveedorRepository, InventarioRepository)`,
`Future<int> guardarProductoCompleto({int? id, required String nombre, required int precio, required List<ProveedorEnFormulario> proveedores, ControlEnFormulario? control, required bool controlabaAntes, required Usuario por})`,
`catalogoRepositoryProvider`.

- [ ] **Step 1: Write the failing test** `test/repositories/catalogo_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/catalogo_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CatalogoRepository repo;
  late Usuario ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CatalogoRepository(db, ProductoRepository(db),
        ProveedorRepository(db), InventarioRepository(db));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
  });
  tearDown(() => db.close());

  const alpinaNueva = ProveedorEnFormulario(
      nombre: 'Alpina', precioCompra: 1500, preferido: true);

  test('guarda producto, proveedor nuevo y control juntos', () async {
    final id = await repo.guardarProductoCompleto(
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [alpinaNueva],
      control: const ControlEnFormulario(hayAhora: 5, minimo: 2, pedirHasta: 10),
      controlabaAntes: false,
      por: ana,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect((p.controlaExistencias, p.minimo, p.pedirHasta), (true, 2, 10));
    expect((await db.select(db.proveedores).getSingle()).nombre, 'Alpina');
    expect(await InventarioRepository(db).existencias(id), 5);
  });

  test('si falla el último paso no queda nada', () async {
    await expectLater(
      repo.guardarProductoCompleto(
        nombre: 'Avena',
        precio: 2000,
        proveedores: const [alpinaNueva],
        // "Pedir hasta" menor que el mínimo: cambiarLimites lanza al final.
        control: const ControlEnFormulario(hayAhora: 5, minimo: 6, pedirHasta: 3),
        controlabaAntes: false,
        por: ana,
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.productos).get(), isEmpty);
    expect(await db.select(db.proveedores).get(), isEmpty);
    expect(await db.select(db.conteosInventario).get(), isEmpty);
  });

  test('al editar, un fallo deja el producto como estaba', () async {
    final id = await ProductoRepository(db)
        .guardarProducto(nombre: 'Avena', precio: 2000);
    await expectLater(
      repo.guardarProductoCompleto(
        id: id,
        nombre: 'Avena grande',
        precio: 2500,
        proveedores: const [],
        control: const ControlEnFormulario(hayAhora: 1, minimo: 6, pedirHasta: 3),
        controlabaAntes: false,
        por: ana,
      ),
      throwsArgumentError,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect((p.nombre, p.precio, p.controlaExistencias), ('Avena', 2000, false));
  });

  test('reutiliza un proveedor existente con el mismo nombre', () async {
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    final id = await repo.guardarProductoCompleto(
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [
        ProveedorEnFormulario(
            nombre: ' alpina ', precioCompra: 1500, preferido: true),
      ],
      controlabaAntes: false,
      por: ana,
    );
    expect(await db.select(db.proveedores).get(), hasLength(1));
    expect((await ProductoRepository(db).proveedoresDe(id)).single.proveedorId,
        alpina);
  });

  test('dejar de controlar apaga el control', () async {
    final id = await ProductoRepository(db)
        .guardarProducto(nombre: 'Avena', precio: 2000);
    await InventarioRepository(db)
        .activarControl(id, cantidad: 3, minimo: 1, por: ana);
    await repo.guardarProductoCompleto(
      id: id,
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [],
      controlabaAntes: true,
      por: ana,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect(p.controlaExistencias, isFalse);
  });
}
```

(Si la tabla de conteos tiene otro nombre en `database.dart`, usar el real; buscar con
`grep -n "class Conteos\|TableInfo" lib/data/database.dart`.)

- [ ] **Step 2: Run** `flutter test test/repositories/catalogo_repository_test.dart` — Expected: FAIL de compilación (no existe el archivo).

- [ ] **Step 3: Implement** `lib/repositories/catalogo_repository.dart`:

```dart
import '../data/database.dart';
import 'inventario_repository.dart';
import 'producto_repository.dart';
import 'proveedor_repository.dart';

/// Un proveedor del producto en el formulario; [proveedorId] null = nuevo
/// (se crea al guardar, o se reutiliza uno con el mismo nombre).
class ProveedorEnFormulario {
  const ProveedorEnFormulario({
    this.proveedorId,
    required this.nombre,
    required this.precioCompra,
    required this.preferido,
  });

  final int? proveedorId;
  final String nombre;
  final int precioCompra;
  final bool preferido;
}

/// Existencias pedidas en el formulario. [hayAhora] solo al activar el
/// control.
class ControlEnFormulario {
  const ControlEnFormulario({
    this.hayAhora,
    required this.minimo,
    this.pedirHasta,
  });

  final int? hayAhora;
  final int minimo;
  final int? pedirHasta;
}

/// Guarda un producto con sus proveedores y existencias en una sola
/// transacción: si algo falla, no queda nada a medias.
class CatalogoRepository {
  CatalogoRepository(
    this._db,
    this._productos,
    this._proveedores,
    this._inventario,
  );

  final AppDatabase _db;
  final ProductoRepository _productos;
  final ProveedorRepository _proveedores;
  final InventarioRepository _inventario;

  /// [control] null = no controla existencias; [controlabaAntes] indica si
  /// las controlaba al abrir el formulario. Devuelve el id del producto.
  Future<int> guardarProductoCompleto({
    int? id,
    required String nombre,
    required int precio,
    required List<ProveedorEnFormulario> proveedores,
    ControlEnFormulario? control,
    required bool controlabaAntes,
    required Usuario por,
  }) {
    return _db.transaction(() async {
      final vinculos = <ProveedorDeProducto>[];
      for (final p in proveedores) {
        final proveedorId = p.proveedorId ??
            (await _proveedores.buscarPorNombre(p.nombre))?.id ??
            await _proveedores.crear(nombre: p.nombre);
        vinculos.add(ProveedorDeProducto(
          proveedorId: proveedorId,
          precioCompra: p.precioCompra,
          preferido: p.preferido,
        ));
      }
      final productoId = await _productos.guardarProducto(
        id: id,
        nombre: nombre,
        precio: precio,
        proveedores: vinculos,
      );
      if (control != null) {
        if (!controlabaAntes) {
          await _inventario.activarControl(
            productoId,
            cantidad: control.hayAhora!,
            minimo: control.minimo,
            por: por,
          );
        }
        await _inventario.cambiarLimites(
          productoId,
          minimo: control.minimo,
          pedirHasta: control.pedirHasta,
        );
      } else if (controlabaAntes) {
        await _inventario.desactivarControl(productoId);
      }
      return productoId;
    });
  }
}
```

`repository_providers.dart` (importar `catalogo_repository.dart`):

```dart
final catalogoRepositoryProvider = Provider(
  (ref) => CatalogoRepository(
    ref.watch(databaseProvider),
    ref.watch(productoRepositoryProvider),
    ref.watch(proveedorRepositoryProvider),
    ref.watch(inventarioRepositoryProvider),
  ),
);
```

(Si alguno de esos providers vive en otro archivo, importarlo de ahí.)

`producto_screen.dart`:
- Borrar el campo `_productoIdGuardado` y su comentario.
- En `_guardar`, reemplazar desde `final proveedores = ref.read(proveedorRepositoryProvider);`
  hasta antes de `if (mounted) Navigator.of(context).pop(true);` por:

```dart
      await ref.read(catalogoRepositoryProvider).guardarProductoCompleto(
            id: widget.producto?.id,
            nombre: nombre,
            precio: precio!,
            proveedores: [
              for (final f in _filas)
                ProveedorEnFormulario(
                  proveedorId: f.proveedorId,
                  nombre: f.nombre,
                  precioCompra: f.precioCompra,
                  preferido: f.preferido,
                ),
            ],
            control: _controla
                ? ControlEnFormulario(
                    hayAhora: hay,
                    minimo: minimo!,
                    pedirHasta: pedirHasta,
                  )
                : null,
            controlabaAntes: _controlabaAlAbrir,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
```

- `_Fila.proveedorId` vuelve a ser `final int? proveedorId;` (ya no se asigna al guardar).
- Importar `'../../repositories/catalogo_repository.dart'`; quitar imports que queden sin uso.

- [ ] **Step 4: Run** `flutter test test/repositories/catalogo_repository_test.dart test/screens/configuracion/` — Expected: PASS (incluido "si activar el control falla, reintentar no duplica el producto").
- [ ] **Step 5: Commit** `git commit -m "Save a product with its suppliers and stock settings in one transaction"`.

---

### Task 2: Cliente nuevo dentro de la corrección

**Files:**
- Modify: `lib/repositories/correccion_repository.dart` (`corregirVenta`), `lib/screens/correccion/hoja_movimiento.dart` (`_guardar`)
- Test: `test/repositories/correccion_pulido_test.dart`; `test/screens/correccion/hoja_movimiento_test.dart` (actualizar la firma de `_RepoSinPermiso.corregirVenta` agregando `String? clienteNuevo,`)

- [ ] **Step 1: Write the failing tests** en `correccion_pulido_test.dart`:

```dart
  group('cliente nuevo al corregir', () {
    test('se crea y se asigna dentro de la corrección', () async {
      final id = await VentaRepository(db).registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      await repo.corregirVenta(id,
          monto: 5000, esFiado: true, clienteNuevo: 'Rosa', por: ana);
      final rosa = await (db.select(db.clientes)
            ..where((c) => c.nombre.equals('Rosa')))
          .getSingle();
      final venta = await (db.select(db.ventas)..where((v) => v.id.equals(id)))
          .getSingle();
      expect(venta.clienteId, rosa.id);
    });

    test('si la corrección falla no queda creado', () async {
      final id = await VentaRepository(db).registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      await repo.anularVenta(id, por: ana);
      await expectLater(
        repo.corregirVenta(id,
            monto: 5000, esFiado: true, clienteNuevo: 'Rosa', por: ana),
        throwsA(isA<CorreccionInvalida>()),
      );
      expect(
          await (db.select(db.clientes)..where((c) => c.nombre.equals('Rosa')))
              .get(),
          isEmpty);
    });

    test('un nombre igual a un cliente existente lo reutiliza', () async {
      final id = await VentaRepository(db).registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      await repo.corregirVenta(id,
          monto: 5000, esFiado: true, clienteNuevo: ' don pedro ', por: ana);
      final venta = await (db.select(db.ventas)..where((v) => v.id.equals(id)))
          .getSingle();
      expect(venta.clienteId, pedro);
      expect(await db.select(db.clientes).get(), hasLength(1));
    });
  });
```

- [ ] **Step 2: Run** `flutter test test/repositories/correccion_pulido_test.dart` — Expected: FAIL de compilación (`clienteNuevo` no existe).

- [ ] **Step 3: Implement.** En `corregirVenta`: parámetro `String? clienteNuevo,` después de
`int? clienteId,`. Cambiar la validación inicial:

```dart
    final nuevo = clienteNuevo?.trim() ?? '';
    if (esFiado && clienteId == null && nuevo.isEmpty) {
      throw const CorreccionInvalida('Una venta fiada necesita cliente');
    }
```

Dentro de la transacción, justo después de `_comprobar(...)`:

```dart
      final cliente = !esFiado
          ? null
          : clienteId ?? await ClienteRepository(_db).obtenerOCrearCliente(nuevo);
```

y en el resto del método usar `cliente` donde se usaba `clienteId` (la comparación `igual` y
`clienteId: Value(esFiado ? cliente : null)`). Importar `cliente_repository.dart`. Actualizar el
doc del método: "Si es fiada, [clienteId] o [clienteNuevo] (se obtiene o crea en la misma
transacción)."

En `hoja_movimiento.dart` `_guardar`, el caso venta queda:

```dart
        case TipoMovimiento.venta:
          final cliente = _esFiado ? _clienteElegido! : null;
          await repo.corregirVenta(_m.id,
              monto: _total,
              esFiado: _esFiado,
              clienteId: cliente?.id,
              clienteNuevo: cliente?.id == null ? cliente?.nombre : null,
              medioPago: _medio,
              cantidades: _lineas.isEmpty
                  ? null
                  : {for (final l in _lineas) l.id: _cantidad(l)},
              por: por);
```

(quitar la llamada a `clienteRepositoryProvider` y su import si queda sin uso). En
`hoja_movimiento_test.dart`, agregar `String? clienteNuevo,` a la firma de
`_RepoSinPermiso.corregirVenta`.

- [ ] **Step 4: Run** `flutter test test/repositories/ test/screens/correccion/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Create a new customer inside the sale correction transaction"`.

---

### Task 3: Fiado y corrección sin construirse entre sí

**Files:**
- Modify: `lib/repositories/fiado_repository.dart`, `lib/repositories/correccion_repository.dart`, `lib/providers/repository_providers.dart:33-35`
- Test: `test/repositories/fiado_repository_test.dart`

**Interfaces — Produces:** `Future<int> saldoDeCliente(AppDatabase db, int clienteId)`; `FiadoRepository(AppDatabase db, {CorreccionRepository? correcciones})`.

- [ ] **Step 1: Write the failing test** (al final de `main()` de `fiado_repository_test.dart`;
revisar sus variables de `setUp` — base `db`, usuario y cliente — y usarlas; importar
`correccion_repository.dart`):

```dart
  test('usa el repositorio de correcciones que recibe', () async {
    final espia = _CorreccionesEspia(db);
    final repo = FiadoRepository(db, correcciones: espia);
    final cliente = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Lucía'));
    await repo.movimientosCliente(cliente);
    expect(espia.consultas, 2); // ventas y abonos
  });

  test('saldoDeCliente da ventas fiadas menos abonos', () async {
    final cliente = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Lucía'));
    final usuario = (await db.select(db.usuarios).get()).first.id;
    await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 5000, fecha: DateTime(2026, 10, 8), usuarioId: usuario,
        esFiado: const Value(true), clienteId: Value(cliente)));
    await FiadoRepository(db)
        .registrarPago(clienteId: cliente, monto: 2000, usuarioId: usuario);
    expect(await saldoDeCliente(db, cliente), 3000);
  });
```

y fuera de `main()`:

```dart
class _CorreccionesEspia extends CorreccionRepository {
  _CorreccionesEspia(super.db);

  int consultas = 0;

  @override
  Future<Map<int, Correccion>> ultimasCorrecciones(
      TipoMovimiento tipo, Iterable<int> ids) {
    consultas++;
    return super.ultimasCorrecciones(tipo, ids);
  }
}
```

(Si en `setUp` no se crea ningún usuario, crearlo en el test con
`db.into(db.usuarios).insert(UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'))`.
Importar `package:drift/drift.dart' show Value` si falta.)

- [ ] **Step 2: Run** `flutter test test/repositories/fiado_repository_test.dart` — Expected: FAIL de compilación.

- [ ] **Step 3: Implement** en `fiado_repository.dart`:

```dart
/// Lo que debe [clienteId]: ventas fiadas no anuladas menos abonos no
/// anulados. Compartido con CorreccionRepository sin construir repositorios.
Future<int> saldoDeCliente(AppDatabase db, int clienteId) async {
  ... // cuerpo actual de saldoCliente, usando db en vez de _db
}
```

En la clase:

```dart
  FiadoRepository(this._db, {CorreccionRepository? correcciones})
      : _correcciones = correcciones ?? CorreccionRepository(_db);

  final AppDatabase _db;
  final CorreccionRepository _correcciones;

  Future<int> saldoCliente(int clienteId) => saldoDeCliente(_db, clienteId);
```

y en `movimientosCliente` usar `_correcciones` en vez de `CorreccionRepository(_db)`.

`correccion_repository.dart`: `await saldoDeCliente(_db, pago.clienteId) + pago.monto` (el import de
`fiado_repository.dart` se mantiene por la función).

`repository_providers.dart`:

```dart
final fiadoRepositoryProvider = Provider(
  (ref) => FiadoRepository(
    ref.watch(databaseProvider),
    correcciones: ref.watch(correccionRepositoryProvider),
  ),
);
```

- [ ] **Step 4: Run** `flutter test test/repositories/ test/screens/fiado/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Inject corrections into the credit repository and share the balance query"`.

---

### Task 4: Aviso de cambios de Reportes con autoDispose

**Files:**
- Modify: `lib/providers/reporte_providers.dart:14-16`
- Test: `test/providers/reporte_providers_test.dart` (nuevo)

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/reporte_providers.dart';
import 'package:app_ventas/util/periodo.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Descartados extends ProviderObserver {
  final nombres = <String?>[];

  @override
  void didDisposeProvider(
          ProviderBase<Object?> provider, ProviderContainer container) =>
      nombres.add(provider.name);
}

void main() {
  test('al cerrar Reportes se deja de escuchar la base', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final observador = _Descartados();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
      observers: [observador],
    );
    addTearDown(container.dispose);
    final hoy = DateTime(2026, 10, 8);
    final consulta =
        (periodo: Periodo.actual(TipoPeriodo.semana, hoy), hoy: hoy);

    final escucha =
        container.listen(comparacionReporteProvider(consulta), (_, __) {});
    await container.read(comparacionReporteProvider(consulta).future);
    escucha.close();
    await container.pump();
    await container.pump();

    expect(observador.nombres, contains('cambiosReporte'));
  });
}
```

- [ ] **Step 2: Run** `flutter test test/providers/reporte_providers_test.dart` — Expected: FAIL (no se descarta).

- [ ] **Step 3: Implement:**

```dart
final _cambiosReporteProvider = StreamProvider.autoDispose<void>(
  (ref) => ref.watch(databaseProvider).tableUpdates().map((_) {}),
  name: 'cambiosReporte',
);
```

- [ ] **Step 4: Run** `flutter test test/providers/ test/screens/reportes/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Stop listening for report changes once Reportes closes"`.

---

### Task 5: Deuda de Reportes en una sola lectura

**Files:**
- Modify: `lib/repositories/fiado_repository.dart` (`_saldosAl`, `deudaTotalAl`), `lib/repositories/reporte_repository.dart` (`reporte`, `comparar`)
- Test: `test/repositories/reporte_repository_test.dart`, `test/repositories/fiado_repository_test.dart`

**Interfaces — Produces:** `Future<Map<DateTime, int>> deudasTotalesAl(Iterable<DateTime> dias)` (claves = los días pedidos tal cual).

- [ ] **Step 1: Write the failing tests.** En `fiado_repository_test.dart`:

```dart
  test('deudasTotalesAl da lo mismo que deudaTotalAl para cada día', () async {
    final usuario = (await db.select(db.usuarios).get()).first.id;
    final a = await db.into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'A'));
    final b = await db.into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'B'));
    Future<void> fiar(int c, int monto, DateTime f) => db.into(db.ventas).insert(
        VentasCompanion.insert(monto: monto, fecha: f, usuarioId: usuario,
            esFiado: const Value(true), clienteId: Value(c)));
    await fiar(a, 5000, DateTime(2026, 10, 1, 9));
    await fiar(b, 1000, DateTime(2026, 10, 3, 9));
    final repo = FiadoRepository(db);
    // B paga de más: su saldo a favor no resta a la deuda de A.
    await repo.registrarPago(clienteId: b, monto: 3000, usuarioId: usuario,
        fecha: DateTime(2026, 10, 4, 9));
    final dias = [DateTime(2026, 9, 30), DateTime(2026, 10, 1),
        DateTime(2026, 10, 3), DateTime(2026, 10, 5)];

    final deudas = await repo.deudasTotalesAl(dias);

    for (final d in dias) {
      expect(deudas[d], await repo.deudaTotalAl(d), reason: '$d');
    }
    expect(deudas.values.toList(), [0, 5000, 6000, 5000]);
  });
```

En `reporte_repository_test.dart` (fuera de `main()`):

```dart
class _FiadoContador extends FiadoRepository {
  _FiadoContador(super.db);

  int lotes = 0;
  int sueltas = 0;

  @override
  Future<Map<DateTime, int>> deudasTotalesAl(Iterable<DateTime> dias) {
    lotes++;
    return super.deudasTotalesAl(dias);
  }

  @override
  Future<int> deudaTotalAl(DateTime dia) {
    sueltas++;
    return super.deudaTotalAl(dia);
  }
}
```

y el test:

```dart
  test('comparar lee la deuda de las cuatro fechas de una vez', () async {
    final fiado = _FiadoContador(db);
    final hoy = DateTime(2026, 10, 7);
    await ReporteRepository(db, fiado)
        .comparar(Periodo.actual(TipoPeriodo.semana, hoy), hoy: hoy);
    expect((fiado.lotes, fiado.sueltas), (1, 0));
  });
```

(Importar `periodo.dart` si falta. Revisar el `setUp` del archivo: `ana` y `pedro` ya existen;
en el test de fiado usar el usuario que cree su `setUp` o crearlo.)

- [ ] **Step 2: Run** `flutter test test/repositories/fiado_repository_test.dart test/repositories/reporte_repository_test.dart` — Expected: FAIL de compilación.

- [ ] **Step 3: Implement** en `FiadoRepository` (reemplaza `_saldosAl` y adapta los dos usos):

```dart
  /// Ventas fiadas y abonos no anulados hasta el cierre de [dia].
  Future<(List<Venta>, List<PagoFiado>)> _movimientosHasta(DateTime dia) async {
    final corte = finDelDia(dia);
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
    return (ventas, pagos);
  }

  /// Saldo de cada cliente al cierre de [dia] con los movimientos dados.
  Map<int, int> _saldos(List<Venta> ventas, List<PagoFiado> pagos, DateTime dia) {
    final corte = finDelDia(dia);
    final saldos = <int, int>{};
    for (final v in ventas.where((v) => !v.fecha.isAfter(corte))) {
      saldos.update(v.clienteId!, (s) => s + v.monto, ifAbsent: () => v.monto);
    }
    for (final p in pagos.where((p) => !p.fecha.isAfter(corte))) {
      saldos.update(p.clienteId, (s) => s - p.monto, ifAbsent: () => -p.monto);
    }
    return saldos;
  }

  /// Deuda de todos los clientes al cierre de cada día de [dias], con una
  /// sola lectura. Un saldo a favor cuenta como 0.
  Future<Map<DateTime, int>> deudasTotalesAl(Iterable<DateTime> dias) async {
    final lista = dias.toList();
    if (lista.isEmpty) return {};
    final ultimo = lista.reduce((a, b) => a.isAfter(b) ? a : b);
    final (ventas, pagos) = await _movimientosHasta(ultimo);
    return {
      for (final d in lista)
        d: _saldos(ventas, pagos, d)
            .values
            .where((s) => s > 0)
            .fold<int>(0, (suma, s) => suma + s),
    };
  }

  /// Lo que deben todos los clientes al cierre de [dia].
  Future<int> deudaTotalAl(DateTime dia) async =>
      (await deudasTotalesAl([dia]))[dia]!;

  /// Cuántos clientes deben algo al cierre de [dia].
  Future<int> clientesConDeudaAl(DateTime dia) async {
    final (ventas, pagos) = await _movimientosHasta(dia);
    return _saldos(ventas, pagos, dia).values.where((s) => s > 0).length;
  }
```

En `ReporteRepository`:
- Renombrar el cuerpo de `reporte` a `Future<Reporte> _reporte(DateTime desde, DateTime hasta, Map<DateTime, int> deudas)`; dentro, `deudaInicio: deudas[_diaAntes(inicio)]!` y `deudaFin: deudas[ultimo]!`, con

```dart
DateTime _diaAntes(DateTime dia) => DateTime(dia.year, dia.month, dia.day - 1);
```

- Público:

```dart
  /// Reporte de los días [desde] a [hasta], ambos incluidos.
  Future<Reporte> reporte(DateTime desde, DateTime hasta) async {
    final inicio = inicioDelDia(desde);
    final ultimo = inicioDelDia(hasta);
    final deudas =
        await _fiado.deudasTotalesAl([_diaAntes(inicio), ultimo]);
    return _reporte(inicio, ultimo, deudas);
  }
```

- En `comparar`, después de calcular `hasta` y `hastaAnterior`:

```dart
    final deudas = await _fiado.deudasTotalesAl([
      _diaAntes(periodo.inicio),
      inicioDelDia(hasta),
      _diaAntes(anterior.inicio),
      inicioDelDia(hastaAnterior),
    ]);
    final actual = await _reporte(periodo.inicio, hasta, deudas);
    final previo = await _reporte(anterior.inicio, hastaAnterior, deudas);
```

(`_reporte` normaliza `desde`/`hasta` con `inicioDelDia` como hoy; las claves deben coincidir
exactamente con las calculadas ahí.)

- [ ] **Step 4: Run** `flutter test test/repositories/ test/screens/reportes/ test/screens/home/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Compute report debts for all dates with one read"`.

---

### Task 6: Desempate del ranking y comentario de la barra

**Files:**
- Modify: `lib/repositories/reporte_repository.dart:249`, `lib/screens/reportes/barras_por_dia.dart` (doc de `fraccion`)
- Test: `test/repositories/reporte_ranking_test.dart`

- [ ] **Step 1: Write the failing test**:

```dart
  test('con unidades y dinero iguales desempata sin mayúsculas', () async {
    final z = await producto('Zanahoria', 1000);
    final a = await producto('arepa', 1000);
    await vender(DateTime(2026, 10, 5, 9),
        [de(z, 'Zanahoria', 1000, 1), de(a, 'arepa', 1000, 1)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.map((p) => p.nombre), ['arepa', 'Zanahoria']);
  });
```

- [ ] **Step 2: Run** `flutter test test/repositories/reporte_ranking_test.dart` — Expected: FAIL (`['Zanahoria', 'arepa']`).

- [ ] **Step 3: Implement.** Importar `'../util/texto_util.dart'` y cambiar el último criterio a
`return claveNombre(a.nombre).compareTo(claveNombre(b.nombre));`. En `Barra`:

```dart
  /// De 0 a 1, respecto a la barra más alta del gráfico (día u hora de más
  /// venta).
  final double fraccion;
```

- [ ] **Step 4: Run** `flutter test test/repositories/ test/screens/reportes/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Break ranking ties case-insensitively and fix the bar fraction doc"`.

---

### Task 7: Verificación final y documentos

- [ ] **Step 1:** `flutter analyze` → `No issues found!`; `flutter test` → todas pasan; `flutter build apk --debug` → compila.
- [ ] **Step 2:** Spec: `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
  `docs/hoja-de-ruta.md`: "Hecho" agrega `- Pulido, tanda 3 — mejoras internas (guardados atómicos, repositorios y Reportes).`;
  "En curso": `- Nada; el pulido acumulado quedó completo.`; "Siguiente": mover ahí
  `- Recordatorios de fiado por WhatsApp.` (sale de "Después").
- [ ] **Step 3: Commit** `git commit -m "Mark polish batch 3 as implemented"`.
