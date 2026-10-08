# Pulido Tanda 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los 18 detalles visibles anotados en las revisiones de las fases 3A–4C.

**Architecture:** Cambios pequeños y localizados en repositorios (reglas y validaciones) y
pantallas (mensajes, estados y edición). Sin cambios de esquema (sigue v7) ni librerías nuevas.
Cada tarea es independiente salvo la 8 (usa `cambiarLimites` en Producto) y la 7 (misma
pantalla de Producto; hacer 7 antes de 8).

**Tech Stack:** Flutter, Riverpod 2, Drift (SQLite), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-08-vecitienda-pulido-tanda1-design.md`

## Global Constraints

- Esquema de base de datos v7 sin cambios; sin dependencias nuevas.
- Textos de la app en español, con los textos exactos de la especificación.
- Montos con `formatoMoneda` (`$1.500`); signo menos tipográfico `−` ya existente donde aplique.
- Tests primero; `flutter test` completo verde, `flutter analyze` sin problemas, APK compila.
- Comandos: `flutter test <ruta>`; desde la raíz `D:/personales/proyectos/APP_VENTAS`.
- Rama: `pulido-tanda1` creada desde `master`.

## Review Focus

- Corregir un abono **bajando** el monto o solo cambiando el medio de pago, de un cliente con
  saldo a favor, debe seguir funcionando (el tope aplica solo si sube) — Task 2.
- Nombre de proveedor nuevo igual a uno **inactivo** debe reutilizar ese (no duplicar) — Task 6/7.
- Reintentar guardar un producto después de un fallo no crea el proveedor nuevo dos veces — Task 7.
- Bajar mínimo y "Pedir hasta" a la vez (p. ej. 5/8 → 2/3) guarda sin error — Task 8.
- Diálogo de cantidad con texto vacío o letras muestra error y no cierra — Task 9.

---

### Task 1: Validar líneas al registrar una venta

**Files:**
- Modify: `lib/repositories/venta_repository.dart` (inicio de `registrarVenta`)
- Test: `test/repositories/venta_validacion_test.dart` (nuevo)

**Interfaces:**
- Produces: `registrarVenta` lanza `ArgumentError('Cada línea necesita cantidad y precio mayores que 0')`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });
  tearDown(() => db.close());

  for (final (nombre, cantidad, precio) in [
    ('cantidad 0', 0, 1000),
    ('cantidad negativa', -1, 1000),
    ('precio 0', 1, 0),
  ]) {
    test('rechaza una línea con $nombre sin guardar nada', () async {
      await expectLater(
        repo.registrarVenta(
          monto: cantidad * precio,
          esFiado: false,
          usuarioId: ana,
          lineas: [
            LineaNueva(
                descripcion: 'Arepa', precioUnitario: precio, cantidad: cantidad),
          ],
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.ventas).get(), isEmpty);
    });
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/venta_validacion_test.dart`
Expected: FAIL (no lanza; la venta se guarda).

- [ ] **Step 3: Write minimal implementation**

En `registrarVenta`, antes de `if (lineas.isNotEmpty) {`:

```dart
    for (final linea in lineas) {
      if (linea.cantidad <= 0 || linea.precioUnitario <= 0) {
        throw ArgumentError(
            'Cada línea necesita cantidad y precio mayores que 0');
      }
    }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/repositories/venta_validacion_test.dart test/repositories/venta_repository_test.dart test/repositories/lineas_venta_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/venta_repository.dart test/repositories/venta_validacion_test.dart
git commit -m "Reject sale lines with zero or negative quantity or price"
```

---

### Task 2: Corrección — tope del abono y correcciones sin cambios

**Files:**
- Modify: `lib/repositories/correccion_repository.dart`
- Test: `test/repositories/correccion_pulido_test.dart` (nuevo)

**Interfaces:**
- Consumes: `FiadoRepository(db).saldoCliente(int clienteId) → Future<int>`.
- Produces: `corregirPago` lanza `CorreccionInvalida('El abono no puede ser mayor que la deuda ($X)')`; `corregirVenta/corregirPago/corregirGasto` no escriben ni registran nada si nada cambia.

- [ ] **Step 1: Write the failing tests**

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
  late Usuario ana;
  late int pedro;
  final hoy = DateTime(2026, 10, 8, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db, reloj: () => DateTime(2026, 10, 8, 15));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });
  tearDown(() => db.close());

  Future<List<Correccion>> correcciones() => db.select(db.correcciones).get();

  group('tope del abono', () {
    // Debe 10.000, abonó 4.000: queda 6.000; el abono puede subir hasta 10.000.
    Future<int> abono() async {
      await VentaRepository(db).registrarVenta(
          monto: 10000, esFiado: true, clienteId: pedro, usuarioId: ana.id,
          fecha: hoy);
      return FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 4000, usuarioId: ana.id, fecha: hoy);
    }

    test('subir hasta la deuda se permite', () async {
      final id = await abono();
      await repo.corregirPago(id,
          monto: 10000, medioPago: MedioPago.efectivo, por: ana);
      expect(await FiadoRepository(db).saldoCliente(pedro), 0);
    });

    test('pasar la deuda se rechaza con el máximo', () async {
      final id = await abono();
      await expectLater(
        repo.corregirPago(id,
            monto: 10001, medioPago: MedioPago.efectivo, por: ana),
        throwsA(isA<CorreccionInvalida>().having((e) => e.mensaje, 'mensaje',
            r'El abono no puede ser mayor que la deuda ($10.000)')),
      );
      expect(await correcciones(), isEmpty);
    });

    test('bajar o cambiar el medio siempre se permite, aun con saldo a favor',
        () async {
      // Abonó 2.000 sin deber nada: saldo −2.000.
      final id = await FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);
      await repo.corregirPago(id,
          monto: 2000, medioPago: MedioPago.transferencia, por: ana);
      await repo.corregirPago(id,
          monto: 1000, medioPago: MedioPago.transferencia, por: ana);
      expect(await correcciones(), hasLength(2));
    });
  });

  group('sin cambios no se registra corrección', () {
    test('venta fiada con el mismo cliente', () async {
      final id = await VentaRepository(db).registrarVenta(
          monto: 5000, esFiado: true, clienteId: pedro, usuarioId: ana.id,
          fecha: hoy);
      await repo.corregirVenta(id,
          monto: 5000, esFiado: true, clienteId: pedro, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('venta con líneas y las mismas cantidades', () async {
      final ventas = VentaRepository(db);
      final id = await ventas.registrarVenta(
        monto: 7000, esFiado: false, usuarioId: ana.id, fecha: hoy,
        lineas: const [
          LineaNueva(descripcion: 'Arepa', precioUnitario: 3500, cantidad: 2),
        ],
      );
      final linea = (await ventas.lineasDeVenta(id)).single;
      await repo.corregirVenta(id,
          monto: 7000, esFiado: false, cantidades: {linea.id: 2}, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('abono igual', () async {
      final id = await FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);
      await repo.corregirPago(id,
          monto: 2000, medioPago: MedioPago.efectivo, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('gasto con la misma descripción entre espacios', () async {
      final id = await GastoRepository(db).registrarGasto(
          monto: 1000, descripcion: 'Hielo', usuarioId: ana.id, fecha: hoy);
      await repo.corregirGasto(id, monto: 1000, descripcion: ' Hielo ', por: ana);
      expect(await correcciones(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/correccion_pulido_test.dart`
Expected: FAIL ("pasar la deuda" no lanza; los de "sin cambios" registran una corrección).

- [ ] **Step 3: Implement**

En `correccion_repository.dart` agregar `import 'fiado_repository.dart';`.

`corregirVenta`: reemplazar el cuerpo de la transacción para calcular primero y escribir
después:

```dart
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final lineas = await _lineas(id);
      var montoFinal = monto;
      final nuevas = <int, int>{};
      if (lineas.isEmpty) {
        _validarMonto(monto);
      } else {
        var suma = 0;
        for (final linea in lineas) {
          final cantidad = cantidades?[linea.id] ?? linea.cantidad;
          if (cantidad < 0) {
            throw const CorreccionInvalida('Cantidad inválida');
          }
          nuevas[linea.id] = cantidad;
          suma += linea.precioUnitario * cantidad;
        }
        if (nuevas.values.every((c) => c == 0)) {
          throw const CorreccionInvalida('Para quitar todo, anula la venta');
        }
        // Sin cambios de cantidad, un monto distinto a la suma es un total
        // tecleado que no puede aplicarse: el total sale de las líneas.
        if (cantidades == null && monto != suma) {
          throw const CorreccionInvalida(
              'El total de una venta con productos sale de sus líneas');
        }
        montoFinal = suma;
      }
      final cambianLineas =
          lineas.any((l) => nuevas[l.id] != l.cantidad);
      final igual = !cambianLineas &&
          montoFinal == venta.monto &&
          esFiado == venta.esFiado &&
          (esFiado
              ? clienteId == venta.clienteId
              : medioPago == venta.medioPago);
      if (igual) return;
      final antes = await _antesVenta(venta, lineas);
      for (final linea in lineas) {
        final cantidad = nuevas[linea.id]!;
        if (cantidad == 0) {
          await (_db.delete(_db.lineasVenta)
                ..where((l) => l.id.equals(linea.id)))
              .go();
        } else if (cantidad != linea.cantidad) {
          await (_db.update(_db.lineasVenta)
                ..where((l) => l.id.equals(linea.id)))
              .write(LineasVentaCompanion(cantidad: Value(cantidad)));
        }
      }
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id))).write(
        VentasCompanion(
          monto: Value(montoFinal),
          esFiado: Value(esFiado),
          clienteId: Value(esFiado ? clienteId : null),
          medioPago: Value(esFiado ? MedioPago.efectivo : medioPago),
        ),
      );
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.corregido, por, antes);
    });
```

`corregirPago`, dentro de la transacción tras `_comprobar`:

```dart
      if (monto == pago.monto && medioPago == pago.medioPago) return;
      if (monto > pago.monto) {
        final maximo =
            await FiadoRepository(_db).saldoCliente(pago.clienteId) + pago.monto;
        if (monto > maximo) {
          throw CorreccionInvalida('El abono no puede ser mayor que la deuda '
              '(${formatoMoneda(maximo < 0 ? 0 : maximo)})');
        }
      }
```

`corregirGasto`, dentro de la transacción tras `_comprobar`:

```dart
      final igual = monto == gasto.monto &&
          (descripcion?.trim() ?? '') == (gasto.descripcion?.trim() ?? '');
      if (igual) return;
```

Actualizar el doc de la clase `CorreccionInvalida`: "monto en 0, venta fiada sin cliente,
abono mayor que la deuda o movimiento ya anulado".

- [ ] **Step 4: Run tests**

Run: `flutter test test/repositories/correccion_pulido_test.dart test/repositories/correccion_repository_test.dart test/repositories/correccion_lineas_test.dart test/repositories/anulados_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/correccion_repository.dart test/repositories/correccion_pulido_test.dart
git commit -m "Cap corrected payments at the debt and skip no-op corrections"
```

---

### Task 3: Hoja de corrección — mensajes claros y línea en 0 recuperable

**Files:**
- Modify: `lib/screens/correccion/hoja_movimiento.dart`
- Test: `test/screens/correccion/hoja_movimiento_test.dart`

**Interfaces:**
- Consumes: `PermisoDenegado`, `CorreccionInvalida.mensaje` (de `correccion_repository.dart`); el tope de Task 2.

- [ ] **Step 1: Write the failing tests**

Agregar a los imports del test: `import 'package:app_ventas/providers/repository_providers.dart';`.
Agregar al final de `main()`:

```dart
  testWidgets('un abono mayor que la deuda muestra el motivo', (tester) async {
    final (container, ana) = await sesion();
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final fecha = DateTime.now();
    await VentaRepository(db).registrarVenta(
        monto: 5000, esFiado: true, clienteId: pedro, usuarioId: ana.id,
        fecha: fecha);
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
    await tester.tap(find.byKey(const Key('tecla_monto_0'))); // 20.000
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('sin permiso al guardar lo dice claramente', (tester) async {
    final container = await containerConSesion(db, overrides: [
      correccionRepositoryProvider.overrideWithValue(_RepoSinPermiso(db)),
    ]);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final id = await VentaRepository(db)
        .registrarVenta(monto: 5000, esFiado: false, usuarioId: ana.id);
    await abrir(tester, container, deVenta(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect(find.text('Ya no puedes corregir este movimiento'), findsOneWidget);
  });
```

Y fuera de `main()`:

```dart
/// Siempre niega el permiso al corregir.
class _RepoSinPermiso extends CorreccionRepository {
  _RepoSinPermiso(super.db);

  @override
  Future<void> corregirVenta(
    int id, {
    required int monto,
    required bool esFiado,
    int? clienteId,
    MedioPago medioPago = MedioPago.efectivo,
    Map<int, int>? cantidades,
    required Usuario por,
  }) async =>
      throw const PermisoDenegado();
}
```

Reemplazar el test `'restar hasta 0 quita la línea'` por:

```dart
  testWidgets('restar hasta 0 deja la línea tachada y se puede recuperar',
      (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    final coca = lineas[1].id;
    await tester.tap(find.byKey(Key('restar_linea_$coca')));
    await tester.pump();

    expect(tester.widget<Text>(find.byKey(Key('cantidad_linea_$coca'))).data,
        '0');
    expect(
        tester.widget<Text>(find.byKey(Key('nombre_linea_$coca'))).style
            ?.decoration,
        TextDecoration.lineThrough);
    expect(
        tester.widget<IconButton>(find.byKey(Key('restar_linea_$coca')))
            .onPressed,
        isNull);
    expect(find.byKey(Key('quitar_linea_$coca')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('total_correccion')),
            matching: find.text(r'$7.000')),
        findsOneWidget);

    await tester.tap(find.byKey(Key('sumar_linea_$coca')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(Key('cantidad_linea_$coca'))).data,
        '1');
    expect(guardarHabilitado(tester), isFalse);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/correccion/hoja_movimiento_test.dart`
Expected: FAIL (mensaje genérico; la línea en 0 desaparece).

- [ ] **Step 3: Implement**

En `hoja_movimiento.dart` importar `'../../repositories/correccion_repository.dart'`.
Agregar al estado:

```dart
  /// Texto para el usuario según por qué falló guardar o anular.
  String _motivo(Object error) => switch (error) {
        PermisoDenegado() => 'Ya no puedes corregir este movimiento',
        CorreccionInvalida(:final mensaje) => mensaje,
        _ => 'No se pudo guardar, intenta de nuevo',
      };
```

En `_guardar` y `_anular` cambiar `} catch (_) {` + `_error = 'No se pudo guardar, intenta de nuevo'`
por:

```dart
    } catch (e) {
      if (mounted) setState(() => _error = _motivo(e));
```

En `_formulario` cambiar `if (_cantidad(linea) > 0) _filaLinea(linea),` por `_filaLinea(linea),`
(dentro del `for`). Reemplazar `_filaLinea`:

```dart
  Widget _filaLinea(LineaVenta linea) {
    final cantidad = _cantidad(linea);
    final quitada = cantidad == 0;
    void cambiar(int nueva) => setState(() {
          _cantidades[linea.id] = nueva;
          _error = null;
        });
    return Row(
      children: [
        Expanded(
          child: Text(
            linea.descripcion,
            key: Key('nombre_linea_${linea.id}'),
            style: quitada
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: ColoresApp.textoSecundario,
                  )
                : null,
          ),
        ),
        IconButton(
          key: Key('restar_linea_${linea.id}'),
          tooltip: 'Restar',
          icon: const Icon(Icons.remove_rounded),
          onPressed: quitada ? null : () => cambiar(cantidad - 1),
        ),
        Text('$cantidad', key: Key('cantidad_linea_${linea.id}')),
        IconButton(
          key: Key('sumar_linea_${linea.id}'),
          tooltip: 'Sumar',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => cambiar(cantidad + 1),
        ),
        if (!quitada)
          IconButton(
            key: Key('quitar_linea_${linea.id}'),
            tooltip: 'Quitar',
            icon: const Icon(Icons.delete_outline_rounded),
            color: ColoresApp.sale,
            onPressed: () => cambiar(0),
          ),
      ],
    );
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/correccion/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/correccion/hoja_movimiento.dart test/screens/correccion/hoja_movimiento_test.dart
git commit -m "Show why a correction failed and keep zeroed lines recoverable"
```

---

### Task 4: Historial trae el nombre del cliente

**Files:**
- Modify: `lib/repositories/cliente_repository.dart`, `lib/repositories/historial_repository.dart`, `lib/providers/repository_providers.dart:50-56`, `lib/screens/historial/historial_screen.dart`
- Test: `test/repositories/historial_repository_test.dart`

**Interfaces:**
- Produces: `ClienteRepository.nombresPorId(Iterable<int> ids) → Future<Map<int, String>>`; `MovimientoHistorial.nombreCliente` (`String?`); `HistorialRepository(venta, gasto, correccion, cliente)`.

- [ ] **Step 1: Write the failing test**

En el test: importar `package:app_ventas/repositories/cliente_repository.dart`; en `setUp`
construir `repo = HistorialRepository(ventaRepo, gastoRepo, CorreccionRepository(db), ClienteRepository(db));`. Agregar:

```dart
  test('las ventas fiadas traen el nombre del cliente', () async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await ventaRepo.registrarVenta(
        monto: 3000, esFiado: true, clienteId: pedro, usuarioId: ana,
        fecha: DateTime(2026, 9, 2, 10));
    await ventaRepo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 9, 2, 9));

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos.map((m) => m.nombreCliente), ['Don Pedro', null]);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/historial_repository_test.dart`
Expected: FAIL de compilación (constructor y `nombreCliente` no existen).

- [ ] **Step 3: Implement**

`cliente_repository.dart`, agregar `import 'package:drift/drift.dart';` si falta y:

```dart
  /// Nombre de cada cliente de [ids], por id.
  Future<Map<int, String>> nombresPorId(Iterable<int> ids) async {
    if (ids.isEmpty) return {};
    final filas = await (_db.select(_db.clientes)
          ..where((c) => c.id.isIn(ids)))
        .get();
    return {for (final c in filas) c.id: c.nombre};
  }
```

`historial_repository.dart`: importar `cliente_repository.dart`; agregar a
`MovimientoHistorial` el campo `this.nombreCliente,` en el constructor y

```dart
  /// Solo aplica a ventas fiadas.
  final String? nombreCliente;
```

Constructor: `HistorialRepository(this._ventaRepository, this._gastoRepository, this._correccionRepository, this._clienteRepository);` con `final ClienteRepository _clienteRepository;`. En
`movimientosDelDia`, tras leer las ventas:

```dart
    final nombres = await _clienteRepository.nombresPorId(
        {for (final v in ventas) if (v.clienteId != null) v.clienteId!});
```

y en el `MovimientoHistorial` de ventas: `nombreCliente: nombres[v.clienteId],`.

`repository_providers.dart`: agregar `ref.watch(clienteRepositoryProvider),` como cuarto
argumento (el provider ya existe en ese archivo; si no, buscarlo con
`grep -rn clienteRepositoryProvider lib/providers`).

`historial_screen.dart`: quitar el mapa `clientes` del `build` y su import de
`clientes_providers.dart` si queda sin uso; usar
`MovimientoEditable.desdeHistorial(m, nombreCliente: m.nombreCliente)`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/repositories/historial_repository_test.dart test/screens/historial/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/cliente_repository.dart lib/repositories/historial_repository.dart lib/providers/repository_providers.dart lib/screens/historial/historial_screen.dart test/repositories/historial_repository_test.dart
git commit -m "Load customer names with the history so they never show empty"
```

---

### Task 5: Reportes — año en otros años, error amable y pérdidas

**Files:**
- Modify: `lib/util/periodo.dart`, `lib/screens/reportes/reportes_screen.dart`
- Test: `test/util/periodo_test.dart`, `test/screens/reportes/reportes_screen_test.dart`

**Interfaces:**
- Produces: `Periodo.titulo(DateTime hoy) → String` (antes getter).

- [ ] **Step 1: Write the failing tests**

En `periodo_test.dart` reemplazar cada `.titulo` por `.titulo(DateTime(2026, 10, 7))` y agregar
al grupo `semana`:

```dart
    test('una semana de otro año lleva el año', () {
      final hoy = DateTime(2026, 10, 7);
      expect(Periodo.de(TipoPeriodo.semana, DateTime(2025, 10, 8)).titulo(hoy),
          'Semana del 6 al 12 oct. 2025');
      expect(Periodo.de(TipoPeriodo.semana, DateTime(2025, 10, 1)).titulo(hoy),
          'Semana del 29 sep. al 5 oct. 2025');
    });
```

En `reportes_screen_test.dart` agregar los imports
`package:app_ventas/providers/reporte_providers.dart` y
`package:app_ventas/ui/colores_app.dart`, y los tests:

```dart
  testWidgets('si falla muestra un mensaje y deja reintentar', (tester) async {
    var intentos = 0;
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        comparacionReporteProvider.overrideWith((ref, consulta) async {
          intentos++;
          throw StateError('falla');
        }),
      ],
      child: MaterialApp(
          theme: temaApp(), home: ReportesScreen(reloj: () => hoy)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el reporte'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    await tester.tap(find.byKey(const Key('reintentar_reporte')));
    await tester.pumpAndSettle();
    expect(intentos, 2);
  });

  testWidgets('un producto vendido con pérdida dice cuánto pierde',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 4000, preferido: true),
      ],
    );
    await VentaRepository(db).registrarVenta(
      monto: 7000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 9),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
      ],
    );
    await montar(tester);

    expect(find.text(r'Pérdida en productos: $1.000'), findsOneWidget);
    final linea = find.text(r'1. Arepa · 2 u · $7.000 · pierde $1.000');
    expect(linea, findsOneWidget);
    expect(tester.widget<Text>(linea).style?.color, ColoresApp.sale);
  });

  testWidgets('una semana del año pasado muestra el año', (tester) async {
    await montar(tester, reloj: () => DateTime(2027, 1, 20));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('periodo_anterior')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Semana del 21 al 27 dic. 2026'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/util/periodo_test.dart test/screens/reportes/reportes_screen_test.dart`
Expected: FAIL (compilación de `titulo(...)`, texto de error crudo, "gana -$1.000").

- [ ] **Step 3: Implement**

`periodo.dart`, reemplazar el getter `titulo`:

```dart
  /// "Semana del 5 al 11 oct.", "Semana del 28 sep. al 4 oct.",
  /// "Semana del 28 dic. al 3 ene. 2027", "Semana del 6 al 12 oct. 2025"
  /// (de otro año que [hoy]) u "Octubre 2026".
  String titulo(DateTime hoy) {
    if (tipo == TipoPeriodo.mes) {
      return '${_mesesLargos[inicio.month - 1]} ${inicio.year}';
    }
    final a = inicio;
    final b = ultimoDia;
    final mesA = _mesesCortos[a.month - 1];
    final mesB = _mesesCortos[b.month - 1];
    final anio = a.year != b.year || b.year != hoy.year ? ' ${b.year}' : '';
    if (a.month != b.month) {
      return 'Semana del ${a.day} $mesA al ${b.day} $mesB$anio';
    }
    return 'Semana del ${a.day} al ${b.day} $mesB$anio';
  }
```

`reportes_screen.dart`:
- `_periodo.titulo` → `_periodo.titulo(_hoy)`.
- `error: (e, st) => Text('Error: $e'),` →

```dart
            error: (e, st) => EstadoVacio(
              icono: Icons.error_outline_rounded,
              titulo: 'No se pudo cargar el reporte',
              accion: TextButton(
                key: const Key('reintentar_reporte'),
                onPressed: () => ref.invalidate(comparacionReporteProvider(
                    (periodo: _periodo, hoy: _hoy))),
                child: const Text('Reintentar'),
              ),
            ),
```

- "Ganancia en productos":

```dart
              child: Text(
                r.gananciaProductos < 0
                    ? 'Pérdida en productos: ${formatoMoneda(-r.gananciaProductos)}'
                    : 'Ganancia en productos: ${formatoMoneda(r.gananciaProductos)}',
                key: const Key('texto_ganancia_productos'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: r.gananciaProductos < 0 ? ColoresApp.sale : null,
                ),
              ),
```

- Línea del ranking:

```dart
              child: Text(
                '${i + 1}. ${p.nombre} · ${p.unidades} u · '
                '${formatoMoneda(p.dinero)}'
                '${switch (p.ganancia) {
                  null => '',
                  final g when g < 0 => ' · pierde ${formatoMoneda(-g)}',
                  final g => ' · gana ${formatoMoneda(g)}',
                }}',
                key: Key('ranking_$i'),
                style: (p.ganancia ?? 0) < 0
                    ? const TextStyle(color: ColoresApp.sale)
                    : null,
              ),
```

Si `grep -rn "\.titulo\b" lib test` muestra otro uso de `Periodo.titulo`, pasarle `hoy`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/util/periodo_test.dart test/screens/reportes/ test/repositories/reporte_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/util/periodo.dart lib/screens/reportes/reportes_screen.dart test/util/periodo_test.dart test/screens/reportes/reportes_screen_test.dart
git commit -m "Show the year for past periods, a friendly report error and losses"
```

---

### Task 6: Proveedores sin nombres repetidos

**Files:**
- Modify: `lib/util/texto_util.dart`, `lib/repositories/proveedor_repository.dart`, `lib/screens/configuracion/proveedores_screen.dart`
- Test: `test/repositories/proveedor_duplicados_test.dart` (nuevo), `test/screens/configuracion/proveedores_screen_test.dart`

**Interfaces:**
- Produces: `String claveNombre(String nombre)` (minúsculas, espacios recortados y colapsados); `ProveedorRepository.buscarPorNombre(String nombre) → Future<Proveedor?>` (activos o no); `crear`/`actualizar` lanzan `ArgumentError('Ya existe un proveedor con ese nombre')`.

- [ ] **Step 1: Write the failing tests**

`test/repositories/proveedor_duplicados_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProveedorRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProveedorRepository(db);
  });
  tearDown(() => db.close());

  test('crear rechaza un nombre repetido sin importar mayúsculas ni espacios',
      () async {
    await repo.crear(nombre: 'Postobón');
    await expectLater(
      repo.crear(nombre: '  postobón '),
      throwsA(isA<ArgumentError>().having(
          (e) => e.message, 'message', 'Ya existe un proveedor con ese nombre')),
    );
    expect(await repo.todos(), hasLength(1));
  });

  test('cuenta también los inactivos', () async {
    final id = await repo.crear(nombre: 'Alpina');
    await repo.desactivar(id);
    expect(() => repo.crear(nombre: 'ALPINA'), throwsArgumentError);
    expect((await repo.buscarPorNombre('alpina  '))?.id, id);
  });

  test('actualizar permite su propio nombre pero no el de otro', () async {
    final a = await repo.crear(nombre: 'Alpina');
    await repo.crear(nombre: 'Postobón');
    await repo.actualizar(a, nombre: 'alpina');
    expect(() => repo.actualizar(a, nombre: 'Postobón'), throwsArgumentError);
  });

  test('buscarPorNombre colapsa espacios internos', () async {
    final id = await repo.crear(nombre: 'Don  Juan');
    expect((await repo.buscarPorNombre('don juan'))?.id, id);
    expect(await repo.buscarPorNombre('Otro'), isNull);
  });
}
```

En `proveedores_screen_test.dart`:

```dart
  testWidgets('un nombre repetido muestra el error y no se guarda',
      (tester) async {
    await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_proveedor')), 'postobón');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe un proveedor con ese nombre'), findsOneWidget);
    expect(await db.select(db.proveedores).get(), hasLength(1));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/proveedor_duplicados_test.dart test/screens/configuracion/proveedores_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement**

`texto_util.dart`:

```dart
/// Forma de comparar nombres: sin mayúsculas y con los espacios recortados
/// y colapsados ("  Don  Juan " → "don juan").
String claveNombre(String nombre) =>
    nombre.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
```

`proveedor_repository.dart` (importar `'../util/texto_util.dart'`):

```dart
  /// Proveedor (activo o no) con el mismo nombre que [nombre], según
  /// [claveNombre].
  Future<Proveedor?> buscarPorNombre(String nombre) async {
    final clave = claveNombre(nombre);
    for (final p in await todos()) {
      if (claveNombre(p.nombre) == clave) return p;
    }
    return null;
  }

  Future<void> _sinRepetir(String nombre, {int? salvo}) async {
    final existente = await buscarPorNombre(nombre);
    if (existente != null && existente.id != salvo) {
      throw ArgumentError('Ya existe un proveedor con ese nombre');
    }
  }
```

En `crear`, antes del insert: `await _sinRepetir(nombre);` (convertir el cuerpo a `async` con
`return await ...` o `final limpio = _nombreValido(nombre); await _sinRepetir(limpio);`). En
`actualizar`, antes del update: `await _sinRepetir(nombre, salvo: id);`.

`proveedores_screen.dart` `_guardar`: envolver la llamada al repo:

```dart
    try {
      ...
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } finally {
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/repositories/proveedor_duplicados_test.dart test/repositories/proveedor_repository_test.dart test/screens/configuracion/proveedores_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/util/texto_util.dart lib/repositories/proveedor_repository.dart lib/screens/configuracion/proveedores_screen.dart test/repositories/proveedor_duplicados_test.dart test/screens/configuracion/proveedores_screen_test.dart
git commit -m "Reject duplicate supplier names, including inactive ones"
```

---

### Task 7: Producto — editar precio de compra y proveedor nuevo solo al guardar

**Files:**
- Modify: `lib/screens/configuracion/producto_screen.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `ProveedorRepository.buscarPorNombre`, `claveNombre` (Task 6).

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('editar el precio de compra conserva el preferido',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Coca',
      precio: 1500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 900, preferido: true),
      ],
    );
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('editar_proveedor_$postobon')));
    await tester.pumpAndSettle();
    expect(find.text('900'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_precio_compra')), '1.000');
    await tester.tap(find.byKey(const Key('boton_guardar_precio_compra')));
    await tester.pumpAndSettle();
    await guardar(tester);

    final vinculo = (await ProductoRepository(db).proveedoresDe(id)).single;
    expect((vinculo.precioCompra, vinculo.preferido), (1000, true));
  });

  testWidgets('cancelar el producto no deja creado el proveedor nuevo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), 'Alpina');
    await tester.enterText(find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    expect(find.text('Alpina'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  testWidgets('un nombre nuevo igual a uno existente usa ese proveedor',
      (tester) async {
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    await ProveedorRepository(db).desactivar(alpina);
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Avena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), ' alpina ');
    await tester.enterText(find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect(await db.select(db.proveedores).get(), hasLength(1));
    final id = (await db.select(db.productos).getSingle()).id;
    expect((await ProductoRepository(db).proveedoresDe(id)).single.proveedorId,
        alpina);
  });

  testWidgets('no se agrega dos veces el mismo proveedor nuevo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    for (final nombre in ['Alpina', 'ALPINA']) {
      await tester.ensureVisible(
          find.byKey(const Key('boton_agregar_proveedor')));
      await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('campo_nuevo_proveedor')), nombre);
      await tester.enterText(
          find.byKey(const Key('campo_precio_compra')), '1.500');
      await tester.tap(
          find.byKey(const Key('boton_agregar_proveedor_producto')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ese proveedor ya está en el producto'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement**

En `producto_screen.dart` importar `'../../util/texto_util.dart'`.

`_Fila`: `int? proveedorId;` (mutable, null = proveedor nuevo aún sin crear),
`int precioCompra;` (mutable) y

```dart
  /// Identifica la fila en las claves de prueba y al excluir repetidos.
  String get clave => proveedorId?.toString() ?? 'nuevo_${claveNombre(nombre)}';
```

En el `build`, las claves `fila_proveedor_`, `preferido_` y `quitar_proveedor_` usan
`${f.clave}`. Envolver el nombre y el precio de cada fila en un área tocable:

```dart
                Expanded(
                  child: InkWell(
                    key: Key('editar_proveedor_${f.clave}'),
                    onTap: () => _editarPrecio(f),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.nombre,
                            style: TextStyle(
                              color: f.activo ? null : ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                        Text(formatoMoneda(f.precioCompra)),
                      ],
                    ),
                  ),
                ),
```

(eliminando el `Expanded` del nombre y el `Text(formatoMoneda(...))` anteriores).

Nuevo método del estado:

```dart
  Future<void> _editarPrecio(_Fila fila) async {
    final precio = await mostrarHojaInferior<int>(
      context,
      titulo: fila.nombre,
      builder: (_) => _HojaPrecioCompra(precio: fila.precioCompra),
    );
    if (precio != null) setState(() => fila.precioCompra = precio);
  }
```

`_agregarProveedor`: pasar también

```dart
        excluir: {for (final f in _filas) if (f.proveedorId != null) f.proveedorId!},
        excluirNombres: {for (final f in _filas) claveNombre(f.nombre)},
```

`_guardar`, justo antes de `guardarProducto` (dentro del `try`):

```dart
      final proveedores = ref.read(proveedorRepositoryProvider);
      for (final f in _filas.where((f) => f.proveedorId == null)) {
        f.proveedorId = (await proveedores.buscarPorNombre(f.nombre))?.id ??
            await proveedores.crear(nombre: f.nombre);
      }
```

y en la lista de `ProveedorDeProducto` usar `proveedorId: f.proveedorId!`.

`_HojaAgregarProveedor`: nuevo parámetro `required this.excluirNombres` (`Set<String>`).
Reemplazar el bloque `try` de `_agregar`:

```dart
    try {
      var proveedor = _elegido;
      if (proveedor == null) {
        proveedor = await ref
            .read(proveedorRepositoryProvider)
            .buscarPorNombre(nombreNuevo);
        final repetido = proveedor == null
            ? widget.excluirNombres.contains(claveNombre(nombreNuevo))
            : widget.excluir.contains(proveedor.id);
        if (repetido) {
          if (mounted) {
            setState(() => _error = 'Ese proveedor ya está en el producto');
          }
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _Fila(
          proveedorId: proveedor?.id,
          nombre: proveedor?.nombre ?? nombreNuevo.trim(),
          activo: proveedor?.activo ?? true,
          precioCompra: precio,
          preferido: false,
        ),
      );
    } finally {
```

Nueva hoja al final del archivo:

```dart
/// Cambia el precio de compra de un proveedor ya agregado. Devuelve el precio.
class _HojaPrecioCompra extends StatefulWidget {
  const _HojaPrecioCompra({required this.precio});

  final int precio;

  @override
  State<_HojaPrecioCompra> createState() => _HojaPrecioCompraState();
}

class _HojaPrecioCompraState extends State<_HojaPrecioCompra> {
  late final _precio = TextEditingController(text: '${widget.precio}');
  String? _error;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  void _guardar() {
    final precio = parsearMonto(_precio.text);
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Escribe un precio válido');
      return;
    }
    Navigator.of(context).pop(precio);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_precio_compra'),
          controller: _precio,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Precio de compra',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_precio_compra'),
          texto: 'Guardar',
          onPressed: _guardar,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/configuracion/`
Expected: PASS (incluido `'agregar un proveedor nuevo desde el producto'`).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/producto_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Edit purchase prices in place and create new suppliers only on save"
```

---

### Task 8: Mínimo y "Pedir hasta" coherentes

**Files:**
- Modify: `lib/repositories/inventario_repository.dart:217-227`, `lib/screens/configuracion/producto_screen.dart` (`_guardar`)
- Test: `test/repositories/inventario_limites_test.dart` (nuevo), `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Produces: `InventarioRepository.cambiarLimites(int productoId, {required int minimo, int? pedirHasta}) → Future<void>`.

- [ ] **Step 1: Write the failing tests**

`test/repositories/inventario_limites_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late int arepa;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => DateTime(2026, 10, 8, 8));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3000));
    await repo.activarControl(arepa, cantidad: 10, minimo: 5, por: ana);
    await repo.cambiarPedirHasta(arepa, 8);
  });
  tearDown(() => db.close());

  Future<Producto> producto() =>
      (db.select(db.productos)..where((p) => p.id.equals(arepa))).getSingle();

  test('cambiarMinimo no pasa de "Pedir hasta"', () async {
    await expectLater(repo.cambiarMinimo(arepa, 9), throwsArgumentError);
    expect((await producto()).minimo, 5);
  });

  test('cambiarLimites sube o baja los dos a la vez', () async {
    await repo.cambiarLimites(arepa, minimo: 10, pedirHasta: 20);
    expect(((await producto()).minimo, (await producto()).pedirHasta), (10, 20));
    await repo.cambiarLimites(arepa, minimo: 2, pedirHasta: 3);
    expect(((await producto()).minimo, (await producto()).pedirHasta), (2, 3));
    await repo.cambiarLimites(arepa, minimo: 4, pedirHasta: null);
    expect((await producto()).pedirHasta, isNull);
  });

  test('cambiarLimites rechaza "Pedir hasta" menor que el mínimo', () async {
    await expectLater(repo.cambiarLimites(arepa, minimo: 6, pedirHasta: 5),
        throwsArgumentError);
    await expectLater(
        repo.cambiarLimites(arepa, minimo: -1), throwsArgumentError);
    expect(((await producto()).minimo, (await producto()).pedirHasta), (5, 8));
  });

  test('dejar de controlar borra "Pedir hasta"', () async {
    await repo.desactivarControl(arepa);
    final p = await producto();
    expect((p.controlaExistencias, p.pedirHasta), (false, null));
  });
}
```

En `productos_screen_test.dart`:

```dart
  testWidgets('subir mínimo y "Pedir hasta" juntos se guarda', (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    final inv = InventarioRepository(db);
    await inv.activarControl(id, cantidad: 10, minimo: 3, por: beto);
    await inv.cambiarPedirHasta(id, 12);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_minimo')));
    await tester.enterText(find.byKey(const Key('campo_minimo')), '15');
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '20');
    await guardar(tester);

    final p = await db.select(db.productos).getSingle();
    expect((p.minimo, p.pedirHasta), (15, 20));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/inventario_limites_test.dart test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (`cambiarLimites` no existe). Nota: el test de pantalla puede fallar por el
choque con el valor anterior una vez agregada la validación de `cambiarMinimo`.

- [ ] **Step 3: Implement**

`inventario_repository.dart`:

```dart
  /// Deja de controlar existencias; el historial se conserva y "pedir hasta"
  /// se borra (al activarlo de nuevo se vuelve a pedir el mínimo).
  Future<void> desactivarControl(int productoId) =>
      (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
        const ProductosCompanion(
          controlaExistencias: Value(false),
          pedirHasta: Value(null),
        ),
      );

  Future<void> cambiarMinimo(int productoId, int minimo) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    final producto = await (_db.select(_db.productos)
          ..where((p) => p.id.equals(productoId)))
        .getSingle();
    final pedirHasta = producto.pedirHasta;
    if (pedirHasta != null && minimo > pedirHasta) {
      throw ArgumentError('El mínimo no puede ser mayor que "Pedir hasta"');
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(minimo: Value(minimo)));
  }

  /// Cambia el mínimo y "pedir hasta" (null lo borra) en una sola escritura;
  /// "pedir hasta" debe ser ≥ mínimo.
  Future<void> cambiarLimites(
    int productoId, {
    required int minimo,
    int? pedirHasta,
  }) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    if (pedirHasta != null && pedirHasta < minimo) {
      throw ArgumentError('Debe ser mayor o igual que el mínimo');
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(
          minimo: Value(minimo),
          pedirHasta: Value(pedirHasta),
        ));
  }
```

`producto_screen.dart` `_guardar`, reemplazar el bloque de inventario:

```dart
      final inventario = ref.read(inventarioRepositoryProvider);
      if (_controla && !_controlabaAlAbrir) {
        await inventario.activarControl(
          productoId,
          cantidad: hay!,
          minimo: minimo!,
          por: ref.read(sesionProvider).usuarioActivo!,
        );
      }
      if (_controla) {
        await inventario.cambiarLimites(
          productoId,
          minimo: minimo!,
          pedirHasta: pedirHasta,
        );
      } else if (_controlabaAlAbrir) {
        await inventario.desactivarControl(productoId);
      }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/repositories/ test/screens/configuracion/ test/screens/inventario/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/inventario_repository.dart lib/screens/configuracion/producto_screen.dart test/repositories/inventario_limites_test.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Keep minimum and order-up-to consistent and clear it when control is off"
```

---

### Task 9: Escribir la cantidad en Recibir mercancía y Pedido sugerido

**Files:**
- Create: `lib/ui/dialogo_cantidad.dart`
- Modify: `lib/screens/inventario/recibir_mercancia_screen.dart`, `lib/screens/inventario/pedido_sugerido_screen.dart`
- Test: `test/ui/dialogo_cantidad_test.dart` (nuevo), `test/screens/inventario/recibir_mercancia_screen_test.dart`, `test/screens/inventario/pedido_sugerido_screen_test.dart`

**Interfaces:**
- Produces: `Future<int?> pedirCantidad(BuildContext context, {required int actual, int minimo = 0})`; claves `campo_cantidad`, `aceptar_cantidad`.

- [ ] **Step 1: Write the failing tests**

`test/ui/dialogo_cantidad_test.dart`:

```dart
import 'package:app_ventas/ui/dialogo_cantidad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int? Function()> abrir(WidgetTester tester, {int minimo = 0}) async {
    int? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              resultado = await pedirCantidad(context, actual: 3, minimo: minimo),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return () => resultado;
  }

  testWidgets('devuelve el número escrito', (tester) async {
    final resultado = await abrir(tester);
    expect(find.text('3'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_cantidad')), '24');
    await tester.tap(find.byKey(const Key('aceptar_cantidad')));
    await tester.pumpAndSettle();
    expect(resultado(), 24);
  });

  for (final texto in ['', 'abc', '0']) {
    testWidgets('con "$texto" y mínimo 1 muestra error y no cierra',
        (tester) async {
      await abrir(tester, minimo: 1);
      await tester.enterText(find.byKey(const Key('campo_cantidad')), texto);
      await tester.tap(find.byKey(const Key('aceptar_cantidad')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un número desde 1'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }

  testWidgets('cancelar devuelve null', (tester) async {
    final resultado = await abrir(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado(), isNull);
  });
}
```

En `recibir_mercancia_screen_test.dart`, al final del test
`'arranca con el proveedor y las líneas que recibe'` (antes de cambiar de proveedor) agregar:

```dart
    await tester.tap(find.byKey(Key('cantidad_recibir_$arepa')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cantidad')), '10');
    await tester.tap(find.byKey(const Key('aceptar_cantidad')));
    await tester.pumpAndSettle();
    expect(find.text(r'Total $25.000'), findsOneWidget);
```

En `pedido_sugerido_screen_test.dart`, al final de
`'muestra sugeridos, precios y total, y se puede editar'`:

```dart
    await tester.tap(find.byKey(Key('cantidad_pedido_$pan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cantidad')), '0');
    await tester.tap(find.byKey(const Key('aceptar_cantidad')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(Key('cantidad_pedido_$pan'))).data, '0');
```

(Si ese test ya edita cantidades antes, ajustar el total esperado que siga; la línea nueva
solo verifica la cantidad.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/dialogo_cantidad_test.dart test/screens/inventario/`
Expected: FAIL

- [ ] **Step 3: Implement**

`lib/ui/dialogo_cantidad.dart`:

```dart
import 'package:flutter/material.dart';

/// Pide una cantidad entera ≥ [minimo], empezando en [actual]. Null si se
/// cancela.
Future<int?> pedirCantidad(
  BuildContext context, {
  required int actual,
  int minimo = 0,
}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _DialogoCantidad(actual: actual, minimo: minimo),
    );

class _DialogoCantidad extends StatefulWidget {
  const _DialogoCantidad({required this.actual, required this.minimo});

  final int actual;
  final int minimo;

  @override
  State<_DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<_DialogoCantidad> {
  late final _campo = TextEditingController(text: '${widget.actual}');
  String? _error;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _aceptar() {
    final n = int.tryParse(_campo.text.trim());
    if (n == null || n < widget.minimo) {
      setState(() => _error = 'Escribe un número desde ${widget.minimo}');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cantidad'),
      content: TextField(
        key: const Key('campo_cantidad'),
        controller: _campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('aceptar_cantidad'),
          onPressed: _aceptar,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
```

`recibir_mercancia_screen.dart` (importar `'../../ui/dialogo_cantidad.dart'`), reemplazar el
`Text('${l.cantidad}', key: ...)` por:

```dart
                        InkWell(
                          onTap: () async {
                            final n = await pedirCantidad(context,
                                actual: l.cantidad, minimo: 1);
                            if (n != null && mounted) {
                              setState(() => l.cantidad = n);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            child: Text(
                              '${l.cantidad}',
                              key: Key('cantidad_recibir_${l.producto.id}'),
                            ),
                          ),
                        ),
```

`pedido_sugerido_screen.dart` (importar el diálogo), reemplazar el `Text('${_cantidad(l)}', ...)`
por:

```dart
                    InkWell(
                      onTap: () async {
                        final n =
                            await pedirCantidad(context, actual: _cantidad(l));
                        if (n != null && mounted) {
                          setState(() => _cantidades[l.producto.id] = n);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        child: Text(
                          '${_cantidad(l)}',
                          key: Key('cantidad_pedido_${l.producto.id}'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/ui/dialogo_cantidad_test.dart test/screens/inventario/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/dialogo_cantidad.dart lib/screens/inventario/recibir_mercancia_screen.dart lib/screens/inventario/pedido_sugerido_screen.dart test/ui/dialogo_cantidad_test.dart test/screens/inventario/recibir_mercancia_screen_test.dart test/screens/inventario/pedido_sugerido_screen_test.dart
git commit -m "Let quantities be typed when receiving goods and in the suggested order"
```

---

### Task 10: Pedido sugerido — subtotal por fila, cargando y vacío

**Files:**
- Modify: `lib/screens/inventario/pedido_sugerido_screen.dart`
- Test: `test/screens/inventario/pedido_sugerido_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

En `'muestra sugeridos, precios y total, y se puede editar'` cambiar
`expect(find.text(r'$900 c/u'), findsOneWidget);` por
`expect(find.text(r'22 × $900 = $19.800'), findsOneWidget);`. Agregar imports
`dart:async`, `package:app_ventas/providers/inventario_providers.dart`,
`package:app_ventas/screens/inventario/pedido_sugerido_screen.dart`,
`package:flutter_riverpod/flutter_riverpod.dart`, y los tests:

```dart
  Future<Proveedor> proveedorSinPedido() async {
    final id = await ProveedorRepository(db).crear(nombre: 'Alpina');
    return (db.select(db.proveedores)..where((p) => p.id.equals(id)))
        .getSingle();
  }

  testWidgets('sin nada que pedir lo dice', (tester) async {
    final proveedor = await proveedorSinPedido();
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: PedidoSugeridoScreen(proveedor: proveedor)));
    await tester.pumpAndSettle();

    expect(find.text('No hay nada por pedir a este proveedor'), findsOneWidget);
    expect(find.byKey(const Key('boton_recibir_pedido')), findsNothing);
  });

  testWidgets('mientras carga muestra el indicador', (tester) async {
    final proveedor = await proveedorSinPedido();
    final container = await containerConSesion(db, overrides: [
      sugerenciaPedidoProvider.overrideWith(
          (ref, id) => Completer<List<LineaSugerida>>().future),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: PedidoSugeridoScreen(proveedor: proveedor)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No hay nada por pedir a este proveedor'), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/pedido_sugerido_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement**

En `pedido_sugerido_screen.dart` importar `'../../ui/estado_vacio.dart'`. En `build`:

```dart
    final pedido = ref.watch(sugerenciaPedidoProvider(widget.proveedor?.id));
    final lineas = pedido.valueOrNull ?? const <LineaSugerida>[];
```

(el resto de cálculos igual). Antes del `ListView`, elegir el cuerpo:

```dart
      body: !pedido.hasValue
          ? pedido.hasError
                ? const EstadoVacio(
                    icono: Icons.error_outline_rounded,
                    titulo: 'No se pudo cargar el pedido',
                  )
                : const Center(child: CircularProgressIndicator())
          : lineas.isEmpty
          ? const EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'No hay nada por pedir a este proveedor',
            )
          : ListView(
              ... // el ListView actual sin cambios salvo el texto de precio
            ),
```

Texto de precio de cada fila:

```dart
                          Text(
                            l.precio == null
                                ? 'Sin precio'
                                : '${_cantidad(l)} × ${formatoMoneda(l.precio!)}'
                                      ' = ${formatoMoneda(_cantidad(l) * l.precio!)}',
                            key: Key('precio_pedido_${l.producto.id}'),
                            style: gris,
                          ),
```

Revisar con `grep -n "c/u" test lib -r` que no quede otro uso.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/inventario/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/pedido_sugerido_screen.dart test/screens/inventario/pedido_sugerido_screen_test.dart
git commit -m "Show row subtotals plus loading and empty states in the suggested order"
```

---

### Task 11: Inventario — mensaje al vendedor y detalle de un producto que salió

**Files:**
- Modify: `lib/screens/inventario/inventario_screen.dart:80-88`, `lib/screens/inventario/detalle_inventario_screen.dart:37-48`
- Test: `test/screens/inventario/inventario_screen_test.dart`, `test/screens/inventario/detalle_inventario_screen_test.dart` (nuevo)

- [ ] **Step 1: Write the failing tests**

En `inventario_screen_test.dart` (usa `montar(tester, rol:)` y `pintar(tester, container)`;
revisar su firma exacta en las líneas 24-40):

```dart
  testWidgets('el vendedor sin productos con control ve a quién pedírselo',
      (tester) async {
    final (container, _) = await montar(tester, rol: 'vendedor');
    await pintar(tester, container);

    expect(find.text('Pídele al administrador que lo active'), findsOneWidget);
    expect(find.text('Actívalo en Ajustes → Productos'), findsNothing);
  });
```

`test/screens/inventario/detalle_inventario_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('un producto sin control lo dice en vez de quedarse cargando',
      (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3000));
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: DetalleInventarioScreen(productoId: arepa)));
    await tester.pumpAndSettle();

    expect(find.text('Este producto ya no controla existencias'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/inventario_screen_test.dart test/screens/inventario/detalle_inventario_screen_test.dart`
Expected: FAIL (el detalle se queda cargando: `pumpAndSettle` puede agotar el tiempo por el indicador animado, lo cual también cuenta como falla).

- [ ] **Step 3: Implement**

`inventario_screen.dart` (importar `'../../providers/sesion_provider.dart'`):

```dart
        if (controlados.isEmpty)
          EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Aún no controlas existencias',
            mensaje: ref.watch(sesionProvider).esAdmin
                ? 'Actívalo en Ajustes → Productos'
                : 'Pídele al administrador que lo active',
          )
```

`detalle_inventario_screen.dart` (importar `'../../ui/estado_vacio.dart'`):

```dart
    final control = ref.watch(productosConControlProvider);
    final item = (control.valueOrNull ?? const [])
        .where((c) => c.producto.id == productoId)
        .firstOrNull;
    ...
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: control.hasValue
            ? const EstadoVacio(
                icono: Icons.inventory_2_outlined,
                titulo: 'Este producto ya no controla existencias',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/inventario/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/inventario_screen.dart lib/screens/inventario/detalle_inventario_screen.dart test/screens/inventario/inventario_screen_test.dart test/screens/inventario/detalle_inventario_screen_test.dart
git commit -m "Tell sellers who enables stock control and handle products that left it"
```

---

### Task 12: Verificación final y documentos

**Files:**
- Modify: `docs/hoja-de-ruta.md`, `docs/superpowers/specs/2026-10-08-vecitienda-pulido-tanda1-design.md` (Estado)

- [ ] **Step 1: Suite, análisis y APK**

Run: `flutter analyze` → Expected: `No issues found!`
Run: `flutter test` → Expected: todas pasan (más de 464).
Run: `flutter build apk --debug` → Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 2: Documentos**

- Spec: `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
- `docs/hoja-de-ruta.md`: en "Hecho" agregar
  `- Pulido, tanda 1 — 18 detalles visibles de las fases 3A–4C.`; en "En curso" poner
  `- Pulido, tandas 2 (letra grande y marca) y 3 (mejoras internas).`; reemplazar la sección
  "Siguiente" (que aún describe la Fase 4 como pendiente) por las tandas 2 y 3 del pulido y,
  después, recordatorios de fiado por WhatsApp; en "Después" quitar la línea del pulido
  acumulado.

- [ ] **Step 3: Commit**

```bash
git add docs/hoja-de-ruta.md docs/superpowers/specs/2026-10-08-vecitienda-pulido-tanda1-design.md
git commit -m "Mark polish batch 1 as implemented"
```
