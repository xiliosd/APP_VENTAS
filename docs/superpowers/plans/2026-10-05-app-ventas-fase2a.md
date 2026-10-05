# App de ventas Fase 2A — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar a la UI las capacidades pendientes de la Fase 1 (resetear PIN, varios admins, editar/reactivar productos, historial y saldo vivo del cliente con fiado, resumen e historial por día, historial con gastos y filtro por usuario).

**Architecture:** Mismas capas que la Fase 1: UI Material → providers Riverpod → repositorios → Drift/SQLite. Se agregan métodos a `ProductoRepository` y `FiadoRepository`, un `HistorialRepository` nuevo que combina ventas y gastos, providers `.family` por día/filtro que escuchan `tableUpdates()`, y un widget compartido `SelectorFecha`. Sin cambios de esquema ni dependencias nuevas.

**Tech Stack:** Flutter (Dart ^3.13), flutter_riverpod ^2.6.1, drift ^2.34, flutter_test con `NativeDatabase.memory()`.

**Spec:** `docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md`

## Global Constraints

- Sin dependencias nuevas en `pubspec.yaml` y sin cambios al esquema Drift (`lib/data/database.dart` no se toca; no hace falta correr `build_runner` salvo en un clon nuevo).
- Montos en COP como `int`, sin decimales; se muestran con `formatoMoneda` (`$3.000`).
- Todo texto visible al usuario en español. Las claves de widget (`Key('...')`) en español con `snake_case`, como en la Fase 1.
- Fechas visibles en formato `dd/mm/aaaa`, horas en `hh:mm` (24 h, con cero a la izquierda).
- PIN válido = exactamente 4 dígitos: `^\d{4}$`.
- Providers de lectura sobre datos mutables escuchan `databaseProvider.tableUpdates()` (patrón de `fiado_providers.dart`).
- Claves de día para providers `.family`: siempre normalizadas con `inicioDelDia(...)`.
- Permisos por rol sin cambios: Configuración solo admin; resumen e historial para ambos roles.
- Tests con base Drift en memoria, sin mocks. Ejecutar con `flutter test` desde la raíz del repo.
- Mensajes de commit en inglés, en imperativo (estilo de la Fase 1), terminando con la línea `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Comportamientos que cambian (acordados con el usuario)

Estos tres puntos fueron revisados explícitamente por el usuario; quien implemente no debe "corregirlos" de vuelta:

1. **Detalle del cliente (fiado) ya no se cierra tras registrar un abono.** Se queda abierta, limpia el campo, actualiza el saldo ("Debe: $X") y la lista de movimientos, y muestra un SnackBar **"Abono registrado"**. (Task 7)
2. **Usuarios: el botón pasa a "Agregar usuario"** y el formulario tiene un **selector de rol** (Vendedor / Administrador) que por defecto marca **Vendedor**. (Task 5)
3. **Fuera de alcance de 2A** — no implementar aunque parezca natural:
   - Editar o anular una venta, abono o gasto ya registrado.
   - Eliminar usuarios o cambiar el rol de un usuario existente.
   - Rangos de fechas (semana/mes) en resumen o historial; exportar reportes.
   - Cualquier cosa de nube, OTP o cobro QR (subproyectos 2B/2C/2D).

## Review Focus

Entradas o condiciones que el spec implica pero que es fácil dejar sin probar; cada una tiene su test en la task indicada:

1. **Precio o abono escrito con separador de miles** ("3.000", "$2.000"): un tendero colombiano lo escribe así y espera que valga 3000, no un error ni un "no pasa nada". → `parsearMonto` (Task 1) y tests en Tasks 6 y 7.
2. **Abono mayor que la deuda**: debe rechazarse con mensaje y no registrar nada (si no, el saldo queda negativo y el cliente desaparece de "me deben"). → Task 7.
3. **Ir al día anterior y volver**: la flecha › debe regresar exactamente a "Hoy" y re-usar los datos de hoy (la clave del provider debe ser el día normalizado). → Tasks 8 y 9.
4. **Gasto sin descripción** en el historial: debe mostrarse como "Gasto", no como texto vacío. → Tasks 4 y 10.
5. **PIN con letras, signo o longitud incorrecta en el diálogo de reseteo**: el diálogo muestra el error y no se cierra; el PIN anterior sigue funcionando. → Task 5.

---

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `lib/util/fecha_util.dart` | Modificar | + `formatoFecha`, `formatoHora`, `formatoFechaHora` |
| `lib/util/formato_moneda.dart` | Modificar | + `parsearMonto` (acepta separador de miles) |
| `lib/util/pin_hash.dart` | Modificar | + `esPinValido` |
| `lib/repositories/producto_repository.dart` | Modificar | + `reactivarProducto`, `observarProductosInactivos` |
| `lib/repositories/fiado_repository.dart` | Modificar | + `MovimientoFiado`, `movimientosCliente` |
| `lib/repositories/historial_repository.dart` | Crear | `MovimientoHistorial`, `HistorialRepository.movimientosDelDia` |
| `lib/providers/repository_providers.dart` | Modificar | + `historialRepositoryProvider` |
| `lib/providers/productos_providers.dart` | Modificar | + `productosInactivosProvider` |
| `lib/providers/fiado_providers.dart` | Modificar | + `saldoClienteProvider`, `movimientosClienteProvider` |
| `lib/providers/resumen_providers.dart` | Modificar | providers pasan a `.family<…, DateTime>` |
| `lib/providers/historial_providers.dart` | Reescribir | `FiltroHistorial`, `historialProvider` |
| `lib/widgets/selector_fecha.dart` | Crear | `SelectorFecha` (‹ fecha ›, date picker, tope en hoy) |
| `lib/screens/configuracion/resetear_pin_dialog.dart` | Crear | Diálogo de reseteo de PIN |
| `lib/screens/configuracion/usuarios_screen.dart` | Reescribir | Rol, validación visible, abrir diálogo de PIN |
| `lib/screens/configuracion/editar_producto_dialog.dart` | Crear | Diálogo de edición de producto |
| `lib/screens/configuracion/productos_screen.dart` | Reescribir | Editar al tocar, sección "Inactivos" |
| `lib/screens/fiado/detalle_cliente_screen.dart` | Reescribir | Saldo vivo, movimientos, no cerrar tras abono |
| `lib/screens/home/resumen_screen.dart` | Reescribir | Selector de fecha |
| `lib/screens/historial/historial_screen.dart` | Reescribir | Fecha, filtro usuario, ventas + gastos |
| `README.md` | Modificar | Quitar "Alcance no cubierto en esta fase" |

Tests: los archivos correspondientes bajo `test/` (se indican en cada task).

---

### Task 1: Utilidades de formato de fecha, parseo de montos y validación de PIN

**Files:**
- Modify: `lib/util/fecha_util.dart`
- Modify: `lib/util/formato_moneda.dart`
- Modify: `lib/util/pin_hash.dart`
- Test: `test/util/fecha_util_test.dart`, `test/util/formato_moneda_test.dart`, `test/util/pin_hash_test.dart`

**Interfaces:**
- Consumes: nada nuevo.
- Produces:
  - `String formatoFecha(DateTime fecha)` → `"02/09/2026"`
  - `String formatoHora(DateTime fecha)` → `"07:05"`
  - `String formatoFechaHora(DateTime fecha)` → `"02/09/2026 07:05"`
  - `int? parsearMonto(String texto)` → entero sin signo, o `null` si no es válido. Ignora espacios, `$` y `.` (separador de miles).
  - `bool esPinValido(String pin)` → `true` solo para exactamente 4 dígitos.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar dentro de `main()` en `test/util/fecha_util_test.dart`:

```dart
  test('formatoFecha usa dd/mm/aaaa con ceros a la izquierda', () {
    expect(formatoFecha(DateTime(2026, 9, 2, 7, 5)), '02/09/2026');
  });

  test('formatoHora usa hh:mm en 24 horas con ceros a la izquierda', () {
    expect(formatoHora(DateTime(2026, 9, 2, 7, 5)), '07:05');
    expect(formatoHora(DateTime(2026, 9, 2, 18, 30)), '18:30');
  });

  test('formatoFechaHora une fecha y hora', () {
    expect(formatoFechaHora(DateTime(2026, 9, 2, 7, 5)), '02/09/2026 07:05');
  });
```

Agregar dentro de `main()` en `test/util/formato_moneda_test.dart`:

```dart
  test('parsearMonto acepta dígitos con o sin separador de miles y símbolo', () {
    expect(parsearMonto('3000'), 3000);
    expect(parsearMonto('3.000'), 3000);
    expect(parsearMonto(r'$3.000'), 3000);
    expect(parsearMonto(' 3 000 '), 3000);
  });

  test('parsearMonto rechaza texto, signos, decimales y vacío', () {
    expect(parsearMonto('abc'), isNull);
    expect(parsearMonto('-500'), isNull);
    expect(parsearMonto('12,5'), isNull);
    expect(parsearMonto(''), isNull);
  });
```

Agregar dentro de `main()` en `test/util/pin_hash_test.dart`:

```dart
  test('esPinValido acepta solo exactamente 4 dígitos', () {
    expect(esPinValido('1234'), isTrue);
    expect(esPinValido('0000'), isTrue);
    expect(esPinValido('123'), isFalse);
    expect(esPinValido('12345'), isFalse);
    expect(esPinValido('12a4'), isFalse);
    expect(esPinValido('-123'), isFalse);
    expect(esPinValido(''), isFalse);
  });
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/util`
Expected: FAIL — errores de compilación `formatoFecha`, `parsearMonto`, `esPinValido` no definidos.

- [ ] **Step 3: Implementar**

Agregar al final de `lib/util/fecha_util.dart`:

```dart
String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String formatoFecha(DateTime fecha) =>
    '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year}';

String formatoHora(DateTime fecha) =>
    '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';

String formatoFechaHora(DateTime fecha) =>
    '${formatoFecha(fecha)} ${formatoHora(fecha)}';
```

Agregar al final de `lib/util/formato_moneda.dart`:

```dart
/// Interpreta un monto escrito por el usuario. Acepta el separador de miles
/// colombiano ("3.000"), el símbolo "$" y espacios; rechaza signos y
/// decimales. Devuelve null si el texto no es un entero sin signo.
int? parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s.$]'), '');
  if (!RegExp(r'^\d+$').hasMatch(limpio)) return null;
  return int.tryParse(limpio);
}
```

Agregar al final de `lib/util/pin_hash.dart`:

```dart
bool esPinValido(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/util`
Expected: PASS (todos).

- [ ] **Step 5: Commit**

```bash
git add lib/util test/util
git commit -m "Add date formatting, amount parsing, and PIN validation utils"
```

---

### Task 2: ProductoRepository — reactivar y observar inactivos

**Files:**
- Modify: `lib/repositories/producto_repository.dart`
- Modify: `lib/providers/productos_providers.dart`
- Test: `test/repositories/producto_repository_test.dart`

**Interfaces:**
- Consumes: `ProductoRepository` existente (`crearProducto`, `desactivarProducto`, `observarProductosActivos`).
- Produces:
  - `Future<void> ProductoRepository.reactivarProducto(int id)`
  - `Stream<List<Producto>> ProductoRepository.observarProductosInactivos()`
  - `final productosInactivosProvider = StreamProvider<List<Producto>>` en `productos_providers.dart`

- [ ] **Step 1: Escribir el test que falla**

Agregar dentro de `main()` en `test/repositories/producto_repository_test.dart`:

```dart
  test('reactivarProducto lo devuelve a activos y lo saca de inactivos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect((await repo.observarProductosInactivos().first).single.id, id);
    expect(await repo.observarProductosActivos().first, isEmpty);

    await repo.reactivarProducto(id);

    expect((await repo.observarProductosActivos().first).single.id, id);
    expect(await repo.observarProductosInactivos().first, isEmpty);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/repositories/producto_repository_test.dart`
Expected: FAIL — `observarProductosInactivos` / `reactivarProducto` no definidos.

- [ ] **Step 3: Implementar**

En `lib/repositories/producto_repository.dart`, agregar después de `observarProductosActivos()`:

```dart
  Stream<List<Producto>> observarProductosInactivos() {
    return (_db.select(_db.productos)..where((p) => p.activo.equals(false)))
        .watch();
  }
```

y después de `desactivarProducto(...)`:

```dart
  Future<void> reactivarProducto(int id) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id)))
        .write(const ProductosCompanion(activo: Value(true)));
  }
```

Agregar al final de `lib/providers/productos_providers.dart`:

```dart
final productosInactivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosInactivos();
});
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/repositories/producto_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/producto_repository.dart lib/providers/productos_providers.dart test/repositories/producto_repository_test.dart
git commit -m "Add product reactivation and inactive product stream"
```

---

### Task 3: FiadoRepository — movimientos del cliente

**Files:**
- Modify: `lib/repositories/fiado_repository.dart`
- Test: `test/repositories/fiado_repository_test.dart`

**Interfaces:**
- Consumes: `ventasFiadasCliente(int)`, `pagosCliente(int)` existentes.
- Produces:
  - `enum TipoMovimientoFiado { venta, abono }`
  - `class MovimientoFiado { final TipoMovimientoFiado tipo; final int monto; final DateTime fecha; }` (constructor `const` con nombrados requeridos)
  - `Future<List<MovimientoFiado>> FiadoRepository.movimientosCliente(int clienteId)` — ordenado por fecha descendente.

- [ ] **Step 1: Escribir el test que falla**

Agregar dentro de `main()` en `test/repositories/fiado_repository_test.dart`:

```dart
  test(
      'movimientosCliente mezcla ventas fiadas y abonos del cliente, '
      'más reciente primero', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
      clienteId: clienteId,
      monto: 2000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2),
    );
    await venderFiado(1000, DateTime(2026, 9, 3));
    // Venta de contado del mismo cliente: no es fiado, no debe aparecer.
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 9999,
            fecha: DateTime(2026, 9, 4),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
    // Abono de otro cliente: no debe aparecer.
    final otroCliente = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await repo.registrarPago(
      clienteId: otroCliente,
      monto: 777,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 5),
    );

    final movimientos = await repo.movimientosCliente(clienteId);

    expect(movimientos.map((m) => m.tipo), [
      TipoMovimientoFiado.venta,
      TipoMovimientoFiado.abono,
      TipoMovimientoFiado.venta,
    ]);
    expect(movimientos.map((m) => m.monto), [1000, 2000, 5000]);
    expect(movimientos.first.fecha, DateTime(2026, 9, 3));
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/repositories/fiado_repository_test.dart`
Expected: FAIL — `movimientosCliente` / `TipoMovimientoFiado` no definidos.

- [ ] **Step 3: Implementar**

En `lib/repositories/fiado_repository.dart`, agregar después de la clase `ClienteConSaldo`:

```dart
enum TipoMovimientoFiado { venta, abono }

class MovimientoFiado {
  const MovimientoFiado({
    required this.tipo,
    required this.monto,
    required this.fecha,
  });

  final TipoMovimientoFiado tipo;
  final int monto;
  final DateTime fecha;
}
```

y dentro de `FiadoRepository`, después de `pagosCliente(...)`:

```dart
  Future<List<MovimientoFiado>> movimientosCliente(int clienteId) async {
    final ventas = await ventasFiadasCliente(clienteId);
    final pagos = await pagosCliente(clienteId);
    return [
      for (final v in ventas)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.venta,
          monto: v.monto,
          fecha: v.fecha,
        ),
      for (final p in pagos)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.abono,
          monto: p.monto,
          fecha: p.fecha,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/repositories/fiado_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/fiado_repository.dart test/repositories/fiado_repository_test.dart
git commit -m "Add merged fiado movement history per client"
```

---

### Task 4: HistorialRepository — ventas y gastos del día

**Files:**
- Create: `lib/repositories/historial_repository.dart`
- Modify: `lib/providers/repository_providers.dart`
- Test: `test/repositories/historial_repository_test.dart`

**Interfaces:**
- Consumes: `VentaRepository.ventasDelDia(DateTime, {int? usuarioId})`, `GastoRepository.gastosDelDia(DateTime, {int? usuarioId})`.
- Produces:
  - `enum TipoMovimientoHistorial { venta, gasto }`
  - `class MovimientoHistorial { tipo, int monto, DateTime fecha, int usuarioId, bool esFiado, String? descripcion }`
  - `HistorialRepository(VentaRepository, GastoRepository)` con `Future<List<MovimientoHistorial>> movimientosDelDia(DateTime dia, {int? usuarioId})` — fecha descendente.
  - `final historialRepositoryProvider = Provider<HistorialRepository>` en `repository_providers.dart`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/repositories/historial_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/historial_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventaRepo;
  late GastoRepository gastoRepo;
  late HistorialRepository repo;
  late int ana;
  late int beto;
  final dia = DateTime(2026, 9, 2);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventaRepo = VentaRepository(db);
    gastoRepo = GastoRepository(db);
    repo = HistorialRepository(ventaRepo, gastoRepo);
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    beto = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  Future<void> cargarDia() async {
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 2, 9));
    await ventaRepo.registrarVenta(
        monto: 3000, esFiado: true, usuarioId: beto, fecha: DateTime(2026, 9, 2, 10));
    await gastoRepo.registrarGasto(
        monto: 1000,
        descripcion: 'Hielo',
        usuarioId: beto,
        fecha: DateTime(2026, 9, 2, 11));
  }

  test('movimientosDelDia mezcla ventas y gastos, más reciente primero',
      () async {
    await cargarDia();

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos.map((m) => m.monto), [1000, 3000, 5000]);
    expect(movimientos[0].tipo, TipoMovimientoHistorial.gasto);
    expect(movimientos[0].descripcion, 'Hielo');
    expect(movimientos[0].esFiado, isFalse);
    expect(movimientos[1].tipo, TipoMovimientoHistorial.venta);
    expect(movimientos[1].esFiado, isTrue);
    expect(movimientos[2].usuarioId, ana);
  });

  test('movimientosDelDia filtra por usuario', () async {
    await cargarDia();

    final movimientos = await repo.movimientosDelDia(dia, usuarioId: beto);

    expect(movimientos.map((m) => m.monto), [1000, 3000]);
    expect(movimientos.every((m) => m.usuarioId == beto), isTrue);
  });

  test('movimientosDelDia excluye otros días y conserva gastos sin descripción',
      () async {
    await ventaRepo.registrarVenta(
        monto: 111, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 1, 23, 59));
    await ventaRepo.registrarVenta(
        monto: 222, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 3));
    await gastoRepo.registrarGasto(
        monto: 500, usuarioId: ana, fecha: DateTime(2026, 9, 2, 8));

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos, hasLength(1));
    expect(movimientos.single.monto, 500);
    expect(movimientos.single.descripcion, isNull);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/repositories/historial_repository_test.dart`
Expected: FAIL — `historial_repository.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/repositories/historial_repository.dart`:

```dart
import 'gasto_repository.dart';
import 'venta_repository.dart';

enum TipoMovimientoHistorial { venta, gasto }

class MovimientoHistorial {
  const MovimientoHistorial({
    required this.tipo,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.descripcion,
  });

  final TipoMovimientoHistorial tipo;
  final int monto;
  final DateTime fecha;
  final int usuarioId;

  /// Solo aplica a ventas; siempre false para gastos.
  final bool esFiado;

  /// Solo aplica a gastos; null para ventas o gastos sin descripción.
  final String? descripcion;
}

class HistorialRepository {
  HistorialRepository(this._ventaRepository, this._gastoRepository);

  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;

  Future<List<MovimientoHistorial>> movimientosDelDia(
    DateTime dia, {
    int? usuarioId,
  }) async {
    final ventas =
        await _ventaRepository.ventasDelDia(dia, usuarioId: usuarioId);
    final gastos =
        await _gastoRepository.gastosDelDia(dia, usuarioId: usuarioId);
    return [
      for (final v in ventas)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.venta,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          esFiado: v.esFiado,
        ),
      for (final g in gastos)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.gasto,
          monto: g.monto,
          fecha: g.fecha,
          usuarioId: g.usuarioId,
          descripcion: g.descripcion,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
```

En `lib/providers/repository_providers.dart`, agregar el import `import '../repositories/historial_repository.dart';` (en orden alfabético entre `gasto_repository` y `producto_repository`) y al final:

```dart
final historialRepositoryProvider = Provider(
  (ref) => HistorialRepository(
    ref.watch(ventaRepositoryProvider),
    ref.watch(gastoRepositoryProvider),
  ),
);
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/repositories/historial_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/historial_repository.dart lib/providers/repository_providers.dart test/repositories/historial_repository_test.dart
git commit -m "Add HistorialRepository merging daily sales and expenses"
```

---

### Task 5: Usuarios — selector de rol, validación visible y resetear PIN

Implementa el **comportamiento acordado #2**: botón "Agregar usuario" + selector de rol con Vendedor por defecto.

**Files:**
- Create: `lib/screens/configuracion/resetear_pin_dialog.dart`
- Modify (reescribir): `lib/screens/configuracion/usuarios_screen.dart`
- Test (reescribir): `test/screens/configuracion/usuarios_screen_test.dart`

**Interfaces:**
- Consumes: `esPinValido` (Task 1); `UsuarioRepository.crearUsuario({nombre, rol, pin})`, `resetearPin(int, String)`, `verificarPin(int, String)`; `listaUsuariosProvider`; `usuarioRepositoryProvider`.
- Produces:
  - `ResetearPinDialog({required Usuario usuario})` — `showDialog<bool>` devuelve `true` si guardó.
  - Claves de widget: `campo_nombre_usuario`, `campo_pin_usuario`, `selector_rol`, `boton_crear_usuario`, `usuario_item_<id>`, `campo_nuevo_pin`, `boton_guardar_pin`, `boton_cancelar_pin`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/configuracion/usuarios_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/repositories/usuario_repository.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: UsuariosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('crear un usuario sin tocar el rol crea un vendedor',
      (tester) async {
    await montar(tester);
    expect(find.text('Agregar usuario'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '4321');
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.nombre, 'Beto');
    expect(usuarios.single.rol, 'vendedor');
    expect(find.text('Beto'), findsOneWidget);
  });

  testWidgets('elegir Administrador en el selector crea un admin',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Carla');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '1111');
    await tester.tap(find.text('Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.rol, 'admin');
  });

  testWidgets('PIN inválido al crear muestra error y no crea el usuario',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '12');
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    expect(find.text('El PIN debe tener 4 dígitos'), findsOneWidget);
    expect(await db.select(db.usuarios).get(), isEmpty);
  });

  testWidgets('resetear el PIN de un usuario guarda el nuevo PIN',
      (tester) async {
    final repo = UsuarioRepository(db);
    final id = await repo.crearUsuario(nombre: 'Beto', rol: 'vendedor', pin: '1111');
    await montar(tester);

    await tester.tap(find.byKey(Key('usuario_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Resetear PIN de Beto'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nuevo_pin')), '9999');
    await tester.tap(find.byKey(const Key('boton_guardar_pin')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('PIN actualizado'), findsOneWidget);
    expect(await repo.verificarPin(id, '9999'), isNotNull);
    expect(await repo.verificarPin(id, '1111'), isNull);
  });

  testWidgets('PIN inválido en el reseteo muestra error y no cierra el diálogo',
      (tester) async {
    final repo = UsuarioRepository(db);
    final id = await repo.crearUsuario(nombre: 'Beto', rol: 'vendedor', pin: '1111');
    await montar(tester);

    await tester.tap(find.byKey(Key('usuario_item_$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_nuevo_pin')), '12a4');
    await tester.tap(find.byKey(const Key('boton_guardar_pin')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('El PIN debe tener 4 dígitos'), findsOneWidget);
    expect(await repo.verificarPin(id, '1111'), isNotNull);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/configuracion/usuarios_screen_test.dart`
Expected: FAIL — no se encuentra `Agregar usuario` / las claves nuevas.

- [ ] **Step 3: Implementar el diálogo**

Crear `lib/screens/configuracion/resetear_pin_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../util/pin_hash.dart';

/// Pide un PIN nuevo para [usuario]. Se cierra con `true` si lo guardó.
class ResetearPinDialog extends ConsumerStatefulWidget {
  const ResetearPinDialog({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<ResetearPinDialog> createState() => _ResetearPinDialogState();
}

class _ResetearPinDialogState extends ConsumerState<ResetearPinDialog> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final pin = _pinController.text.trim();
    if (!esPinValido(pin)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }
    await ref
        .read(usuarioRepositoryProvider)
        .resetearPin(widget.usuario.id, pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Resetear PIN de ${widget.usuario.nombre}'),
      content: TextField(
        key: const Key('campo_nuevo_pin'),
        controller: _pinController,
        decoration: InputDecoration(
          labelText: 'Nuevo PIN de 4 dígitos',
          errorText: _error,
        ),
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        autofocus: true,
      ),
      actions: [
        TextButton(
          key: const Key('boton_cancelar_pin'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_guardar_pin'),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/configuracion/usuarios_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../util/pin_hash.dart';
import 'resetear_pin_dialog.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String _rol = 'vendedor';
  String? _errorNombre;
  String? _errorPin;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crearUsuario() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPin = esPinValido(pin) ? null : 'El PIN debe tener 4 dígitos';
    });
    if (_errorNombre != null || _errorPin != null) return;

    await ref.read(usuarioRepositoryProvider).crearUsuario(
          nombre: nombre,
          rol: _rol,
          pin: pin,
        );
    _nombreController.clear();
    _pinController.clear();
    setState(() => _rol = 'vendedor');
    ref.invalidate(listaUsuariosProvider);
  }

  Future<void> _resetearPin(Usuario usuario) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => ResetearPinDialog(usuario: usuario),
    );
    if (actualizado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(
        children: [
          Expanded(
            child: usuariosAsync.when(
              data: (usuarios) => ListView(
                children: usuarios
                    .map((u) => ListTile(
                          key: Key('usuario_item_${u.id}'),
                          title: Text(u.nombre),
                          subtitle: Text(u.rol),
                          trailing: const Icon(Icons.lock_reset),
                          onTap: () => _resetearPin(u),
                        ))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_usuario'),
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _errorNombre,
                  ),
                ),
                TextField(
                  key: const Key('campo_pin_usuario'),
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: 'PIN de 4 dígitos',
                    errorText: _errorPin,
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const Key('selector_rol'),
                  segments: const [
                    ButtonSegment(value: 'vendedor', label: Text('Vendedor')),
                    ButtonSegment(value: 'admin', label: Text('Administrador')),
                  ],
                  selected: {_rol},
                  onSelectionChanged: (seleccion) =>
                      setState(() => _rol = seleccion.first),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_usuario'),
                  onPressed: _crearUsuario,
                  child: const Text('Agregar usuario'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/configuracion/usuarios_screen_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/configuracion/usuarios_screen.dart lib/screens/configuracion/resetear_pin_dialog.dart test/screens/configuracion/usuarios_screen_test.dart
git commit -m "Allow creating admins and resetting PINs from Usuarios"
```

---

### Task 6: Productos — editar y reactivar

**Files:**
- Create: `lib/screens/configuracion/editar_producto_dialog.dart`
- Modify (reescribir): `lib/screens/configuracion/productos_screen.dart`
- Test (reescribir): `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `parsearMonto` (Task 1); `ProductoRepository.actualizarProducto(int, {String? nombre, int? precio})`, `reactivarProducto(int)` (Task 2), `desactivarProducto(int)`; `productosActivosProvider`, `productosInactivosProvider` (Task 2).
- Produces:
  - `EditarProductoDialog({required Producto producto})` — `showDialog<bool>` devuelve `true` si guardó.
  - Claves: `producto_item_<id>`, `boton_desactivar_<id>`, `producto_inactivo_<id>`, `boton_reactivar_<id>`, `campo_editar_nombre`, `campo_editar_precio`, `boton_guardar_producto`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/configuracion/productos_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> crearArepa() => db.into(db.productos).insert(
        ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
      );

  testWidgets('crear un producto lo agrega a la lista visible', (tester) async {
    await montar(tester);

    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
  });

  testWidgets('editar un producto cambia nombre y precio', (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_editar_nombre')), 'Arepa rellena');
    await tester.enterText(
        find.byKey(const Key('campo_editar_precio')), '3.500');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Arepa rellena'), findsOneWidget);
    expect(find.text(r'$3.500'), findsOneWidget);
    final producto = await db.select(db.productos).getSingle();
    expect(producto.nombre, 'Arepa rellena');
    expect(producto.precio, 3500);
  });

  testWidgets('precio inválido al editar muestra error y no guarda',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_editar_precio')), 'abc');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect((await db.select(db.productos).getSingle()).precio, 3000);
  });

  testWidgets('desactivar lo pasa a Inactivos y reactivar lo devuelve',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);
    expect(find.text('Inactivos'), findsNothing);

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsNothing);
    expect(find.text('Inactivos'), findsOneWidget);
    expect(find.byKey(Key('producto_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsOneWidget);
    expect(find.text('Inactivos'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL — crear con "3.000" no agrega el producto; no existe el diálogo ni la sección "Inactivos".

- [ ] **Step 3: Implementar el diálogo**

Crear `lib/screens/configuracion/editar_producto_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';

/// Edita nombre y precio de [producto]. Se cierra con `true` si guardó.
/// Cambiar el precio no afecta ventas ya registradas: cada venta guarda su
/// propio monto.
class EditarProductoDialog extends ConsumerStatefulWidget {
  const EditarProductoDialog({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<EditarProductoDialog> createState() =>
      _EditarProductoDialogState();
}

class _EditarProductoDialogState extends ConsumerState<EditarProductoDialog> {
  late final _nombreController =
      TextEditingController(text: widget.producto.nombre);
  late final _precioController =
      TextEditingController(text: widget.producto.precio.toString());
  String? _errorNombre;
  String? _errorPrecio;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          (precio == null || precio <= 0) ? 'Escribe un precio válido' : null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;

    await ref.read(productoRepositoryProvider).actualizarProducto(
          widget.producto.id,
          nombre: nombre,
          precio: precio,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar producto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('campo_editar_nombre'),
            controller: _nombreController,
            decoration:
                InputDecoration(labelText: 'Nombre', errorText: _errorNombre),
          ),
          TextField(
            key: const Key('campo_editar_precio'),
            controller: _precioController,
            decoration:
                InputDecoration(labelText: 'Precio', errorText: _errorPrecio),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_guardar_producto'),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/configuracion/productos_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';
import 'editar_producto_dialog.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    if (nombre.isEmpty || precio == null || precio <= 0) return;
    await ref
        .read(productoRepositoryProvider)
        .crearProducto(nombre: nombre, precio: precio);
    _nombreController.clear();
    _precioController.clear();
  }

  Future<void> _editar(Producto producto) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => EditarProductoDialog(producto: producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Expanded(
            child: productosAsync.when(
              data: (productos) => ListView(
                children: [
                  ...productos.map((p) => ListTile(
                        key: Key('producto_item_${p.id}'),
                        title: Text(p.nombre),
                        subtitle: Text(formatoMoneda(p.precio)),
                        onTap: () => _editar(p),
                        trailing: IconButton(
                          key: Key('boton_desactivar_${p.id}'),
                          icon: const Icon(Icons.delete),
                          onPressed: () => ref
                              .read(productoRepositoryProvider)
                              .desactivarProducto(p.id),
                        ),
                      )),
                  if (inactivos.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Inactivos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...inactivos.map((p) => ListTile(
                        key: Key('producto_inactivo_${p.id}'),
                        title: Text(p.nombre),
                        subtitle: Text(formatoMoneda(p.precio)),
                        trailing: TextButton(
                          key: Key('boton_reactivar_${p.id}'),
                          onPressed: () => ref
                              .read(productoRepositoryProvider)
                              .reactivarProducto(p.id),
                          child: const Text('Reactivar'),
                        ),
                      )),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_producto'),
                  controller: _nombreController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del producto'),
                ),
                TextField(
                  key: const Key('campo_precio_producto'),
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_producto'),
                  onPressed: _crear,
                  child: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/configuracion/productos_screen.dart lib/screens/configuracion/editar_producto_dialog.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Add product editing and reactivation to Productos"
```

---

### Task 7: Detalle del cliente — saldo vivo, movimientos y abono sin cerrar

Implementa el **comportamiento acordado #1**: tras registrar un abono la pantalla **no se cierra**; limpia el campo, actualiza saldo y movimientos y muestra el SnackBar "Abono registrado".

**Files:**
- Modify: `lib/providers/fiado_providers.dart`
- Modify (reescribir): `lib/screens/fiado/detalle_cliente_screen.dart`
- Test (reescribir): `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `parsearMonto` (Task 1); `formatoFechaHora` (Task 1); `FiadoRepository.saldoCliente(int)`, `registrarPago(...)`, `movimientosCliente(int)` y `TipoMovimientoFiado` (Task 3); `clientesConDeudaProvider`; `sesionProvider`.
- Produces:
  - `final saldoClienteProvider = FutureProvider.autoDispose.family<int, int>` (clave: `clienteId`)
  - `final movimientosClienteProvider = FutureProvider.autoDispose.family<List<MovimientoFiado>, int>` (clave: `clienteId`)
  - `DetalleClienteScreen({required ClienteConSaldo clienteConSaldo})` — misma firma que hoy (la lista de fiado no cambia).
  - Claves: `texto_saldo_cliente`, `campo_monto_abono`, `boton_registrar_abono`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/fiado/detalle_cliente_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Crea un cliente que debe $5.000 (una venta fiada el 01/09/2026 10:00),
  /// abre su detalle con una sesión activa y devuelve el id del cliente.
  Future<int> montarDetalle(WidgetTester tester) async {
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();
    final clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime(2026, 9, 1, 10, 0),
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
    final cliente =
        await (db.select(db.clientes)..where((c) => c.id.equals(clienteId)))
            .getSingle();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DetalleClienteScreen(
            clienteConSaldo: ClienteConSaldo(
              cliente: cliente,
              saldo: 5000,
              fechaDeudaMasAntigua: DateTime(2026, 9, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return clienteId;
  }

  testWidgets('muestra los movimientos del cliente', (tester) async {
    await montarDetalle(tester);

    expect(find.text(r'Debe: $5.000'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Venta fiada'), findsOneWidget);
    expect(find.text('01/09/2026 10:00'), findsOneWidget);
  });

  testWidgets(
      'registrar un abono actualiza saldo y movimientos y la pantalla '
      'sigue abierta', (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '2.000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 3000);
    expect(find.byType(DetalleClienteScreen), findsOneWidget);
    expect(find.text(r'Debe: $3.000'), findsOneWidget);
    expect(find.text('Abono registrado'), findsOneWidget);
    expect(find.text('Abono'), findsOneWidget);
    final campo =
        tester.widget<TextField>(find.byKey(const Key('campo_monto_abono')));
    expect(campo.controller!.text, isEmpty);
  });

  testWidgets('un abono mayor que la deuda muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '9000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
    expect(find.text('Abono'), findsNothing);
  });

  testWidgets('un monto inválido muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), 'abc');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un monto válido'), findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/fiado/detalle_cliente_screen_test.dart`
Expected: FAIL — no existe "Movimientos"; la pantalla se cierra tras el abono; "2.000" no se interpreta.

- [ ] **Step 3: Agregar los providers**

En `lib/providers/fiado_providers.dart`, agregar al final (el import de `fiado_repository.dart` ya existe):

```dart
final saldoClienteProvider =
    FutureProvider.autoDispose.family<int, int>((ref, clienteId) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).saldoCliente(clienteId);
});

final movimientosClienteProvider = FutureProvider.autoDispose
    .family<List<MovimientoFiado>, int>((ref, clienteId) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).movimientosCliente(clienteId);
});
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/fiado/detalle_cliente_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerStatefulWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  /// Cliente y saldo al momento de abrir; el saldo mostrado se lee después
  /// de [saldoClienteProvider] para reflejar abonos hechos en esta pantalla.
  final ClienteConSaldo clienteConSaldo;

  @override
  ConsumerState<DetalleClienteScreen> createState() =>
      _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends ConsumerState<DetalleClienteScreen> {
  final _montoController = TextEditingController();
  String? _errorMonto;

  int get _clienteId => widget.clienteConSaldo.cliente.id;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _registrarAbono() async {
    final monto = parsearMonto(_montoController.text);
    if (monto == null || monto <= 0) {
      setState(() => _errorMonto = 'Escribe un monto válido');
      return;
    }
    final fiadoRepo = ref.read(fiadoRepositoryProvider);
    final saldo = await fiadoRepo.saldoCliente(_clienteId);
    if (monto > saldo) {
      setState(() => _errorMonto =
          'El abono no puede ser mayor que la deuda (${formatoMoneda(saldo)})');
      return;
    }
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await fiadoRepo.registrarPago(
      clienteId: _clienteId,
      monto: monto,
      usuarioId: sesion.id,
    );
    ref.invalidate(clientesConDeudaProvider);
    ref.invalidate(saldoClienteProvider(_clienteId));
    ref.invalidate(movimientosClienteProvider(_clienteId));
    if (!mounted) return;
    _montoController.clear();
    setState(() => _errorMonto = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abono registrado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.clienteConSaldo.cliente;
    final saldo = ref.watch(saldoClienteProvider(_clienteId)).valueOrNull ??
        widget.clienteConSaldo.saldo;
    final movimientosAsync = ref.watch(movimientosClienteProvider(_clienteId));

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debe: ${formatoMoneda(saldo)}',
              key: const Key('texto_saldo_cliente'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_abono'),
              controller: _montoController,
              decoration: InputDecoration(
                labelText: 'Monto del abono',
                errorText: _errorMonto,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_abono'),
              onPressed: _registrarAbono,
              child: const Text('Registrar abono'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: movimientosAsync.when(
                data: (movimientos) => ListView(
                  children: movimientos.map((m) {
                    final esAbono = m.tipo == TipoMovimientoFiado.abono;
                    final color = esAbono ? Colors.green.shade700 : null;
                    return ListTile(
                      leading: Icon(
                        esAbono ? Icons.payments : Icons.shopping_bag,
                        color: color,
                      ),
                      title: Text(
                        formatoMoneda(m.monto),
                        style: TextStyle(color: color),
                      ),
                      subtitle: Text(formatoFechaHora(m.fecha)),
                      trailing: Text(esAbono ? 'Abono' : 'Venta fiada'),
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/fiado`
Expected: PASS (incluye `lista_fiado_screen_test.dart`, que no debe romperse).

- [ ] **Step 6: Commit**

```bash
git add lib/providers/fiado_providers.dart lib/screens/fiado/detalle_cliente_screen.dart test/screens/fiado/detalle_cliente_screen_test.dart
git commit -m "Show live balance and movements in client detail, keep it open after a payment"
```

---

### Task 8: Widget SelectorFecha

**Files:**
- Create: `lib/widgets/selector_fecha.dart`
- Test: `test/widgets/selector_fecha_test.dart`

**Interfaces:**
- Consumes: `inicioDelDia`, `formatoFecha` (Task 1).
- Produces: `SelectorFecha({required DateTime dia, required ValueChanged<DateTime> onCambio})`. Siempre llama `onCambio` con un día normalizado (medianoche). Claves: `boton_dia_anterior`, `boton_elegir_fecha`, `boton_dia_siguiente`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/widgets/selector_fecha_test.dart`:

```dart
import 'package:app_ventas/util/fecha_util.dart';
import 'package:app_ventas/widgets/selector_fecha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime dia;

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SelectorFecha(
            dia: dia,
            onCambio: (nuevo) => setState(() => dia = nuevo),
          ),
        ),
      ),
    );
  }

  setUp(() => dia = inicioDelDia(DateTime.now()));

  testWidgets('muestra Hoy y deshabilita la flecha siguiente en hoy',
      (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Hoy'), findsOneWidget);
    final siguiente =
        tester.widget<IconButton>(find.byKey(const Key('boton_dia_siguiente')));
    expect(siguiente.onPressed, isNull);
  });

  testWidgets('ir al día anterior y volver regresa exactamente a Hoy',
      (tester) async {
    await tester.pumpWidget(harness());
    final hoy = inicioDelDia(DateTime.now());
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pump();

    expect(dia, ayer);
    expect(find.text(formatoFecha(ayer)), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pump();

    expect(dia, hoy);
    expect(find.text('Hoy'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/widgets/selector_fecha_test.dart`
Expected: FAIL — `selector_fecha.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/widgets/selector_fecha.dart`:

```dart
import 'package:flutter/material.dart';

import '../util/fecha_util.dart';

/// Selector de día: ‹ fecha ›. Tocar la fecha abre un calendario. No permite
/// elegir días posteriores a hoy. [onCambio] siempre recibe el día
/// normalizado a medianoche, listo para usarse como clave de provider.
class SelectorFecha extends StatelessWidget {
  const SelectorFecha({super.key, required this.dia, required this.onCambio});

  final DateTime dia;
  final ValueChanged<DateTime> onCambio;

  @override
  Widget build(BuildContext context) {
    final hoy = inicioDelDia(DateTime.now());
    final seleccionado = inicioDelDia(dia);
    final esHoy = seleccionado == hoy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('boton_dia_anterior'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Día anterior',
          onPressed: () => onCambio(DateTime(
              seleccionado.year, seleccionado.month, seleccionado.day - 1)),
        ),
        TextButton(
          key: const Key('boton_elegir_fecha'),
          onPressed: () async {
            final elegido = await showDatePicker(
              context: context,
              initialDate: seleccionado,
              firstDate: DateTime(2000),
              lastDate: hoy,
            );
            if (elegido != null) onCambio(inicioDelDia(elegido));
          },
          child: Text(
            esHoy ? 'Hoy' : formatoFecha(seleccionado),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          key: const Key('boton_dia_siguiente'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Día siguiente',
          onPressed: esHoy
              ? null
              : () => onCambio(DateTime(seleccionado.year, seleccionado.month,
                  seleccionado.day + 1)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/widgets/selector_fecha_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/selector_fecha.dart test/widgets/selector_fecha_test.dart
git commit -m "Add SelectorFecha day navigation widget"
```

---

### Task 9: Resumen por día

**Files:**
- Modify (reescribir): `lib/providers/resumen_providers.dart`
- Modify (reescribir): `lib/screens/home/resumen_screen.dart`
- Test: `test/screens/home/resumen_screen_test.dart`

**Interfaces:**
- Consumes: `SelectorFecha` (Task 8); `inicioDelDia` (Task 1); `ResumenRepository.resumenDelDia(DateTime)`, `resumenPorVendedor(DateTime)`.
- Produces:
  - `resumenDelDiaProvider = FutureProvider.autoDispose.family<ResumenDia, DateTime>` (clave: día normalizado)
  - `resumenPorVendedorProvider = FutureProvider.autoDispose.family<Map<Usuario, ResumenDia>, DateTime>` (clave: día normalizado)

- [ ] **Step 1: Escribir el test que falla**

Agregar dentro de `main()` en `test/screens/home/resumen_screen_test.dart`:

```dart
  testWidgets('navegar al día anterior muestra los totales de ese día',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final ahora = DateTime.now();
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
              monto: 5000, fecha: ahora, usuarioId: usuarioId),
        );
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 7000,
            fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ResumenScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();
    expect(find.text(r'Vendiste: $7.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/screens/home/resumen_screen_test.dart`
Expected: FAIL — no existe `boton_dia_anterior`.

- [ ] **Step 3: Reescribir los providers**

Reemplazar todo `lib/providers/resumen_providers.dart` por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/resumen_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emits whenever any table changes, so that the resumen providers below
/// recompute automatically after a sale/expense is registered instead of
/// keeping a stale total cached (see [_cambiosFiadoProvider] in
/// fiado_providers.dart for the same pattern).
final _cambiosResumenProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

/// The key must be a day normalized with `inicioDelDia`, so that every read
/// of the same day hits the same cached provider.
final resumenDelDiaProvider =
    FutureProvider.autoDispose.family<ResumenDia, DateTime>((ref, dia) {
  ref.watch(_cambiosResumenProvider);
  return ref.watch(resumenRepositoryProvider).resumenDelDia(dia);
});

/// Same key contract as [resumenDelDiaProvider].
final resumenPorVendedorProvider = FutureProvider.autoDispose
    .family<Map<Usuario, ResumenDia>, DateTime>((ref, dia) {
  ref.watch(_cambiosResumenProvider);
  return ref.watch(resumenRepositoryProvider).resumenPorVendedor(dia);
});
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/home/resumen_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/selector_fecha.dart';

class ResumenScreen extends ConsumerStatefulWidget {
  const ResumenScreen({super.key});

  @override
  ConsumerState<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends ConsumerState<ResumenScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenDelDiaProvider(_dia));
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider(_dia));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorFecha(
            dia: _dia,
            onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
          ),
          const SizedBox(height: 8),
          resumenAsync.when(
            data: (resumen) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendiste: ${formatoMoneda(resumen.totalVendido)}'),
                Text('Gastaste: ${formatoMoneda(resumen.totalGastado)}'),
                Text('Por cobrar: ${formatoMoneda(resumen.totalPorCobrar)}'),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          const Text('Por vendedor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          porVendedorAsync.when(
            data: (mapa) => Column(
              children: mapa.entries
                  .map((entrada) => ListTile(
                        title: Text(entrada.key.nombre),
                        trailing:
                            Text(formatoMoneda(entrada.value.totalVendido)),
                      ))
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/home`
Expected: PASS (incluye `home_screen_test.dart`, que no debe romperse).

- [ ] **Step 6: Commit**

```bash
git add lib/providers/resumen_providers.dart lib/screens/home/resumen_screen.dart test/screens/home/resumen_screen_test.dart
git commit -m "Allow browsing the daily summary by day"
```

---

### Task 10: Historial con fecha, filtro por usuario, ventas y gastos

**Files:**
- Modify (reescribir): `lib/providers/historial_providers.dart`
- Modify (reescribir): `lib/screens/historial/historial_screen.dart`
- Test (reescribir): `test/screens/historial/historial_screen_test.dart`

**Interfaces:**
- Consumes: `HistorialRepository.movimientosDelDia`, `MovimientoHistorial`, `TipoMovimientoHistorial`, `historialRepositoryProvider` (Task 4); `SelectorFecha` (Task 8); `inicioDelDia`, `formatoHora` (Task 1); `listaUsuariosProvider`.
- Produces:
  - `typedef FiltroHistorial = ({DateTime dia, int? usuarioId});` (día normalizado)
  - `historialProvider = FutureProvider.autoDispose.family<List<MovimientoHistorial>, FiltroHistorial>`
  - Se elimina `historialDelDiaProvider` (único uso: `HistorialScreen`).
  - Claves: `filtro_usuario`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/historial/historial_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/historial/historial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late int ana;
  late int beto;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    beto = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistorialScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cargarHoy() async {
    await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await gastos.registrarGasto(
        monto: 1000, descripcion: 'Hielo', usuarioId: beto);
    await gastos.registrarGasto(monto: 500, usuarioId: ana);
  }

  testWidgets('muestra ventas y gastos del día con usuario', (tester) async {
    await cargarHoy();
    await montar(tester);

    expect(find.text('Historial'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text('Contado · Ana'), findsOneWidget);
    expect(find.text(r'$1.000'), findsOneWidget);
    expect(find.text('Hielo · Beto'), findsOneWidget);
    expect(find.text(r'$500'), findsOneWidget);
    expect(find.text('Gasto · Ana'), findsOneWidget);
  });

  testWidgets('el filtro por usuario oculta los movimientos de otros',
      (tester) async {
    await cargarHoy();
    await montar(tester);

    await tester.tap(find.byKey(const Key('filtro_usuario')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beto').last);
    await tester.pumpAndSettle();

    expect(find.text('Hielo · Beto'), findsOneWidget);
    expect(find.text(r'$5.000'), findsNothing);
    expect(find.text('Gasto · Ana'), findsNothing);
  });

  testWidgets('una venta registrada con la pantalla abierta aparece sola',
      (tester) async {
    await montar(tester);
    expect(find.text('Sin movimientos este día'), findsOneWidget);

    await ventas.registrarVenta(monto: 8000, esFiado: true, usuarioId: ana);
    await tester.pumpAndSettle();

    expect(find.text(r'$8.000'), findsOneWidget);
    expect(find.text('Fiado · Ana'), findsOneWidget);
  });

  testWidgets('el día anterior muestra solo los movimientos de ese día',
      (tester) async {
    final ahora = DateTime.now();
    await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await ventas.registrarVenta(
      monto: 7000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12),
    );
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();

    expect(find.text(r'$7.000'), findsOneWidget);
    expect(find.text(r'$5.000'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/historial/historial_screen_test.dart`
Expected: FAIL — título "Historial de hoy", sin gastos, sin filtro ni selector.

- [ ] **Step 3: Reescribir los providers**

Reemplazar todo `lib/providers/historial_providers.dart` por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/historial_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Day (normalized with `inicioDelDia`) and optional user to show in the
/// historial. Records compare by value, so equal filters share one provider.
typedef FiltroHistorial = ({DateTime dia, int? usuarioId});

/// Emits whenever any table changes, so the historial refreshes after a sale
/// or expense is registered (same pattern as fiado_providers.dart).
final _cambiosHistorialProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final historialProvider = FutureProvider.autoDispose
    .family<List<MovimientoHistorial>, FiltroHistorial>((ref, filtro) {
  ref.watch(_cambiosHistorialProvider);
  return ref
      .watch(historialRepositoryProvider)
      .movimientosDelDia(filtro.dia, usuarioId: filtro.usuarioId);
});
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/historial/historial_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/historial_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/historial_repository.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/selector_fecha.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());
  int? _usuarioId;

  @override
  Widget build(BuildContext context) {
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};
    final movimientosAsync =
        ref.watch(historialProvider((dia: _dia, usuarioId: _usuarioId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
          SelectorFecha(
            dia: _dia,
            onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<int?>(
              key: const Key('filtro_usuario'),
              isExpanded: true,
              value: _usuarioId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                for (final u in usuarios)
                  DropdownMenuItem<int?>(value: u.id, child: Text(u.nombre)),
              ],
              onChanged: (id) => setState(() => _usuarioId = id),
            ),
          ),
          Expanded(
            child: movimientosAsync.when(
              data: (movimientos) {
                if (movimientos.isEmpty) {
                  return const Center(child: Text('Sin movimientos este día'));
                }
                return ListView(
                  children: movimientos
                      .map((m) => _MovimientoTile(
                            movimiento: m,
                            nombreUsuario: nombres[m.usuarioId] ?? '',
                          ))
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento, required this.nombreUsuario});

  final MovimientoHistorial movimiento;
  final String nombreUsuario;

  @override
  Widget build(BuildContext context) {
    final esGasto = movimiento.tipo == TipoMovimientoHistorial.gasto;
    final colorGasto = Theme.of(context).colorScheme.error;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');

    return ListTile(
      leading: Icon(
        esGasto ? Icons.money_off : Icons.point_of_sale,
        color: esGasto ? colorGasto : null,
      ),
      title: Text(
        formatoMoneda(movimiento.monto),
        style: esGasto ? TextStyle(color: colorGasto) : null,
      ),
      subtitle: Text('$detalle · $nombreUsuario'),
      trailing: Text(formatoHora(movimiento.fecha)),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/historial test/screens/home`
Expected: PASS (los de home siguen pasando porque `HistorialScreen` mantiene su constructor `const`).

- [ ] **Step 6: Commit**

```bash
git add lib/providers/historial_providers.dart lib/screens/historial/historial_screen.dart test/screens/historial/historial_screen_test.dart
git commit -m "Show sales and expenses in Historial with day and user filters"
```

---

### Task 11: README, suite completa y verificación en el emulador

**Files:**
- Modify: `README.md` (sección "Alcance no cubierto en esta fase")
- Modify: `docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md` (línea `**Estado:**`)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: documentación al día; APK verificado a mano.

- [ ] **Step 1: Actualizar el README**

En `README.md`, reemplazar la sección completa que empieza en `## Alcance no cubierto en esta fase` (hasta el final del archivo) por:

```markdown
## Fase 2

La Fase 2 se divide en subproyectos, cada uno con su spec y plan en `docs/superpowers/`:

- **2A — Pantallas pendientes de la Fase 1** (hecho): resetear PIN y varios
  administradores, editar/reactivar productos, historial y saldo vivo del
  cliente con fiado, resumen por día, historial por día y usuario con gastos.
- **2B/2C — Respaldo en la nube (Supabase) e identidad de la tienda por OTP**
  (pendiente). Resuelve el riesgo de pérdida de datos descrito arriba.
- **2D — Cobro digital por QR (Bre-B / Nequi / Daviplata)** (pendiente).

Fuera de alcance por ahora: editar o anular ventas, abonos o gastos ya
registrados; eliminar usuarios o cambiar su rol; rangos de fechas
(semana/mes) y reportes exportables.
```

- [ ] **Step 2: Marcar el spec como implementado**

En `docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md`, cambiar la línea `**Estado:** Borrador para revisión` por `**Estado:** Implementado`.

- [ ] **Step 3: Correr la suite completa y el análisis estático**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y `All tests passed!`. Si `flutter analyze` reporta algo en archivos tocados por este plan, corregirlo antes de seguir.

- [ ] **Step 4: Verificación manual en el emulador**

Run:
```bash
flutter emulators --launch app_ventas_ligero
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Recorrer en la app (con un admin creado en el primer uso):
1. Config → Usuarios: crear "Carla" como Administrador; tocar a Carla, resetear su PIN; cerrar sesión y entrar como Carla con el PIN nuevo.
2. Config → Productos: editar un producto escribiendo el precio "3.500"; desactivarlo y reactivarlo desde "Inactivos".
3. Registrar una venta fiada a un cliente; Fiado → cliente: ver el movimiento, abonar una parte, confirmar que la pantalla sigue abierta con el saldo nuevo y el SnackBar "Abono registrado"; intentar abonar más que la deuda y ver el error.
4. Resumen: ‹ al día anterior y › de vuelta a "Hoy".
5. Registrar un gasto; Historial: ver venta y gasto, filtrar por usuario, ir al día anterior.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md
git commit -m "Document Fase 2A completion and remaining Fase 2 subprojects"
```
