# Pulido — Tanda 3: mejoras internas

**Fecha:** 2026-10-08
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con las tandas 1 y 2 (b68fa31, 516 pruebas).

## Objetivo

Cerrar las mejoras internas anotadas en las revisiones de las fases 3A–4C: que un fallo a mitad
de camino no deje datos a medias, que los repositorios no se construyan entre sí y que Reportes
no haga trabajo de más. El tendero no ve cambios, salvo que errores raros ya no dejan datos
sueltos. Sin cambios de esquema (v7) ni dependencias nuevas.

## Alcance

### 1. Guardar un producto en una sola transacción

Nuevo `lib/repositories/catalogo_repository.dart`:

```dart
/// Un proveedor del producto en el formulario; proveedorId null = nuevo.
class ProveedorEnFormulario {
  const ProveedorEnFormulario({this.proveedorId, required this.nombre,
      required this.precioCompra, required this.preferido});
  final int? proveedorId;
  final String nombre;
  final int precioCompra;
  final bool preferido;
}

/// Existencias pedidas en el formulario (null = no controla).
class ControlEnFormulario {
  const ControlEnFormulario({this.hayAhora, required this.minimo, this.pedirHasta});
  final int? hayAhora; // solo al activar el control
  final int minimo;
  final int? pedirHasta;
}

class CatalogoRepository {
  CatalogoRepository(this._db, this._productos, this._proveedores, this._inventario);
  Future<int> guardarProductoCompleto({int? id, required String nombre,
      required int precio, required List<ProveedorEnFormulario> proveedores,
      ControlEnFormulario? control, required bool controlabaAntes,
      required Usuario por});
}
```

Dentro de **una** `_db.transaction`: crea los proveedores nuevos (o reutiliza el de igual
nombre con `buscarPorNombre`), llama a `guardarProducto`, y luego `activarControl` (si se activa),
`cambiarLimites` (si controla) o `desactivarControl` (si deja de controlar). Si cualquier paso
lanza, no queda nada guardado y el error sube igual. `ProductoScreen._guardar` usa solo este
método; desaparecen `_productoIdGuardado` y la asignación de `proveedorId` a las filas (un
reintento parte de cero). Provider `catalogoRepositoryProvider`.

Resuelve además dos pendientes previos: proveedor nuevo que quedaba suelto si fallaba el guardado
y conteo inicial duplicado al reintentar tras activar el control.

### 2. Cliente nuevo dentro de la corrección

`CorreccionRepository.corregirVenta` recibe `String? clienteNuevo`. Si `esFiado`, `clienteId` es
null y `clienteNuevo` tiene texto, el cliente se obtiene o crea (misma regla que
`ClienteRepository.obtenerOCrearCliente`) **dentro** de la transacción de la corrección. Una venta
fiada sigue necesitando `clienteId` o `clienteNuevo`. `HojaMovimiento` deja de llamar a
`obtenerOCrearCliente` y pasa `clienteNuevo`.

### 3. Repositorios de fiado y corrección sin construirse entre sí

- Nueva función `Future<int> saldoDeCliente(AppDatabase db, int clienteId)` en
  `fiado_repository.dart` (ventas fiadas no anuladas − abonos no anulados).
  `FiadoRepository.saldoCliente` la usa; `CorreccionRepository.corregirPago` también, sin crear
  un `FiadoRepository`.
- `FiadoRepository(this._db, {CorreccionRepository? correcciones})`: usa la recibida (o una
  propia si no se pasa, para no romper pruebas). `fiadoRepositoryProvider` le pasa
  `correccionRepositoryProvider`.

### 4. Aviso de cambios de Reportes con autoDispose

`_cambiosReporteProvider` pasa a `StreamProvider.autoDispose` con `name: 'cambiosReporte'`
(su único consumidor ya es autoDispose). Al cerrar Reportes deja de escuchar la base.

### 5. Deuda de Reportes en una sola lectura

`FiadoRepository.deudasTotalesAl(Iterable<DateTime> dias) → Future<Map<DateTime, int>>`: lee una
vez las ventas fiadas y abonos no anulados hasta el cierre del día más tardío y calcula la deuda
de cada día (misma regla que `deudaTotalAl`: saldos a favor cuentan 0). `deudaTotalAl` la usa con
un solo día. `ReporteRepository.comparar` pide las 4 fechas (inicio−1 y fin de cada periodo) en
una sola llamada y se las pasa a la construcción de cada reporte; `reporte(inicio, fin)` público
pide sus 2 fechas en una llamada.

### 6. Desempate del ranking sin mayúsculas

En el orden de "Productos más vendidos", el último criterio compara `claveNombre(a.nombre)` con
`claveNombre(b.nombre)` (de `util/texto_util.dart`).

### 7. Comentario de `Barra.fraccion`

"De 0 a 1, respecto a la barra más alta del gráfico (día u hora de más venta)."

## Pruebas

Tests primero:
1. Si el último paso falla (p. ej. "Pedir hasta" menor que el mínimo), no queda producto,
   proveedor nuevo ni conteo; el caso feliz guarda todo; reutiliza un proveedor por nombre.
2. Una corrección que falla (venta anulada) no crea el cliente nuevo; una que funciona lo crea
   y lo asigna.
3. `FiadoRepository` usa el `CorreccionRepository` recibido; `saldoDeCliente` da lo mismo que
   antes.
4. Con un `ProviderObserver`, al cerrar la última escucha del reporte se descarta
   `cambiosReporte`.
5. `comparar` llama una sola vez a `deudasTotalesAl` y nunca a `deudaTotalAl`; los valores de
   deuda no cambian (pruebas de reporte existentes).
6. Con unidades y dinero iguales, "arepa" va antes que "Zanahoria".

7 es solo comentario. Al terminar: suite verde, `flutter analyze` limpio, APK compila.

## Fuera de alcance

Otros providers `_cambios*` sin autoDispose (sus consumidores no son autoDispose); el patrón
`scale()` de `mosaico.dart`.
