# Código de barras: escanear, autocompletar y vender

**Fecha:** 2026-10-12
**Estado:** Implementado (falta probar la cámara con productos reales)
**Base:** master con la renovación R1–R4 y el buscador fijo de la venta (fb154d6, 727 pruebas).

## Contexto y objetivo

El tendero quiere escanear el código de barras de un producto con la cámara para:

1. **Crear productos más rápido**: el nombre, la marca, el tamaño, el envase y el tipo se
   autocompletan desde Open Food Facts (base gratuita y abierta) cuando hay internet; si no
   aparece, se llenan a mano.
2. **Vender escaneando**, sin perder la venta manual (mosaicos, buscador, botón − y "Otro
   monto") para lo que no tiene código.
3. **Buscar y filtrar** por marca y por tipo, en la venta y en Productos.

Decisiones del usuario: los datos extra sirven para identificar, buscar y filtrar (los
reportes por marca/tipo quedan para después; los datos se guardan desde ya). Escanear en la
venta un código desconocido abre una hoja rápida para crearlo, y un vendedor también puede
hacerlo.

## 1. Datos

### 1.1 Esquema (versión 7 → 8)

Columnas nuevas en `Productos`, todas opcionales:

| Columna | Tipo | Notas |
|---|---|---|
| `codigoBarras` | texto, nulo | Sin espacios; solo dígitos y letras del código leído |
| `marca` | texto, nulo | Libre, recortado |
| `tamano` | texto, nulo | Libre ("1,5 L", "400 ml", "500 g") |
| `envase` | texto, nulo | Clave del catálogo fijo (§1.3) |
| `tipo` | texto, nulo | Clave del catálogo fijo (§1.3) |

Migración `from < 8`: `addColumn` de las cinco. Los productos existentes quedan con nulos.
La unicidad del código entre productos **activos** se valida en el repositorio (no con un
índice único, porque un producto inactivo puede conservar su código).

### 1.2 Repositorio (`ProductoRepository`)

- `guardarProducto(...)` acepta `codigoBarras`, `marca`, `tamano`, `envase`, `tipo`
  (opcionales). Un texto vacío o solo espacios se guarda como nulo.
- Si `codigoBarras` no es nulo y otro producto **activo** (distinto id) ya lo tiene, lanza
  `CodigoRepetido(nombreDelOtro)`; la pantalla muestra "Ese código ya es de {nombre}".
- `Future<Producto?> productoPorCodigo(String codigo)`: el producto con ese código, activo o
  inactivo (prefiere el activo si hubiera ambos).
- `Future<List<String>> marcasUsadas()`: marcas distintas de los productos activos, en orden
  alfabético, para sugerir.

### 1.3 Catálogo fijo (`lib/util/catalogo_producto.dart`)

Tipos (clave → nombre): `bebidas` Bebidas · `lacteos` Lácteos · `panaderia` Panadería ·
`abarrotes` Granos y abarrotes · `snacks` Snacks y dulces · `aseo_personal` Aseo personal ·
`aseo_hogar` Aseo del hogar · `licores` Licores · `carnes` Carnes y embutidos · `fruver`
Frutas y verduras · `otros` Otros.

Envases: `botella_plastica` Botella plástica · `botella_vidrio` Botella de vidrio · `lata`
Lata · `caja` Caja o tetrapak · `bolsa` Bolsa · `paquete` Paquete · `frasco` Frasco ·
`granel` Granel · `otro` Otro.

Funciones puras:
- `String? tipoDesdeOff(List<String> etiquetasCategoria)`: recorre las etiquetas (de la más
  específica a la más general) y devuelve la primera clave que coincida con una tabla de
  palabras (p. ej. `beverages`, `sodas`, `waters`, `juices` → `bebidas`; `dairies`, `milks`,
  `yogurts`, `cheeses` → `lacteos`; `breads` → `panaderia`; `snacks`, `chocolates`,
  `candies`, `biscuits` → `snacks`; `alcoholic-beverages`, `beers`, `wines` → `licores`;
  `cereals`, `rices`, `pastas`, `legumes`, `oils`, `sugars` → `abarrotes`; `meats`,
  `sausages` → `carnes`; `fruits`, `vegetables` → `fruver`). `licores` gana sobre `bebidas`
  si ambas coinciden. Sin coincidencia → `null` (nunca `otros` automático).
- `String? envaseDesdeOff(List<String> etiquetasEnvase)`: `plastic-bottle`/`pet-bottle` →
  `botella_plastica`; `glass-bottle` → `botella_vidrio`; `can` → `lata`; `tetra-pak`/
  `carton`/`box` → `caja`; `bag`/`sachet` → `bolsa`; `jar` → `frasco`; `packet`/`wrapper` →
  `paquete`. Sin coincidencia → `null`.
- `String nombreTipo(String clave)` y `String nombreEnvase(String clave)`.

### 1.4 Open Food Facts (`lib/servicios/open_food_facts.dart`)

- `class DatosProducto { String? nombre, marca, tamano, envase, tipo; }`.
- `abstract class ConsultaProducto { Future<DatosProducto?> buscar(String codigo); }` y su
  implementación `OpenFoodFacts({Uri base = https://world.openfoodfacts.org})` con `dart:io`
  `HttpClient` (sin dependencia nueva; la base se cambia en pruebas por un servidor local):
  `GET https://world.openfoodfacts.org/api/v2/product/{codigo}?fields=product_name,product_name_es,brands,quantity,packaging_tags,categories_tags`
  con cabecera `User-Agent: VeciTienda/1.0 (Android)` y tiempo límite de **5 s**.
- Respuesta con `status == 1` → `DatosProducto` (nombre: `product_name_es` si existe, si no
  `product_name`; marca: la primera de `brands` separada por coma; tamaño: `quantity`;
  envase y tipo: por §1.3). Cualquier otra cosa (404, `status 0`, tiempo agotado, sin
  internet, JSON dañado) → `null`. Nunca propaga excepciones.
- `consultaProductoProvider` (Riverpod) para reemplazarla en pruebas.

## 2. Escáner

- Dependencia nueva: `mobile_scanner` (versión estable fijada en el plan). Agrega el permiso
  de cámara de Android por su manifiesto.
- `abstract class LectorCodigo { Future<String?> leer(BuildContext context); }`, con
  `lectorCodigoProvider`. La implementación real abre `EscanerScreen`; las pruebas usan un
  lector falso.
- `EscanerScreen` (`lib/screens/escaner/escaner_screen.dart`): vista de cámara a pantalla
  completa (fondo `velo`), recuadro guía redondeado, botón de linterna, texto "Apunta al
  código de barras" y botón "Escribir código" (abre un diálogo con un campo numérico).
  Formatos: EAN-13, EAN-8, UPC-A, UPC-E, Code 128. Al leer el primer código válido:
  `Vibracion.exito()` y se cierra devolviendo el código. Si el permiso de cámara se niega o
  no hay cámara: mensaje "No podemos usar la cámara" con el botón "Escribir código".

## 3. Ficha de producto (`producto_screen.dart`)

- Tarjeta DATOS: nuevo campo **Código de barras** (`campo_codigo_producto`) con un botón
  `IconButton` de escáner (`boton_escanear_producto`, tooltip "Escanear").
- Al obtener un código (escáner o escrito y confirmado), si el producto es nuevo o el campo
  de nombre está vacío, consulta Open Food Facts mostrando "Buscando…"
  (`texto_buscando_producto`) y llena **solo los campos vacíos** (nombre, marca, tamaño,
  envase, tipo). Si no hay datos: aviso "No lo encontramos, llénalo a mano".
- Campos nuevos en DATOS: **Marca** (`campo_marca`, `Autocomplete` con `marcasUsadas`),
  **Tamaño** (`campo_tamano`), **Envase** (`selector_envase`) y **Tipo** (`selector_tipo`)
  como `DropdownButtonFormField` con "Sin elegir" + el catálogo.
- La vista previa muestra "Marca · Tamaño" bajo el nombre cuando existen.
- Guardar con código repetido: el error "Ese código ya es de {nombre}" aparece bajo el campo
  del código y no se guarda.

## 4. Productos (`productos_screen.dart`)

- El buscador también coincide con marca y tamaño (misma normalización sin tildes) y con el
  código exacto.
- Chips de tipo (`filtro_tipo_producto_{clave}` y `filtro_tipo_producto_todos`) arriba de la
  lista cuando hay al menos 2 tipos en uso; se combinan con el buscador.
- Cada fila muestra "Marca · Tamaño" (`detalle_producto_{id}`) si tiene alguno.

## 5. Nueva venta (`registrar_venta_screen.dart`)

- **Botón de escáner** en la barra superior (`boton_escanear_venta`, tooltip "Escanear").
- Al leer un código:
  - **Producto activo con ese código** → `agregarProducto` y aviso "{nombre} agregado" (la
    vibración ya la dio el escáner al leer).
  - **Producto inactivo con ese código** → aviso de error "Ese código es de {nombre}
    (inactivo). Reactívalo en Productos".
  - **Código desconocido** → **hoja rápida** "Nuevo producto" (`hoja_producto_rapido`): código
    (solo lectura), nombre, precio (obligatorio, enfocado si ya hay nombre), marca, tamaño,
    envase y tipo, autocompletados desde Open Food Facts con "Buscando…". "Guardar y
    agregar" (`boton_guardar_producto_rapido`) crea el producto (sin proveedor ni control de
    existencias) y lo agrega al ticket. Disponible para administradores y vendedores.
- Una lectura del **mismo código** dentro de 1,5 s de la anterior se ignora.
- **Buscador**: coincide también con marca y tamaño. Si el texto es un código exacto de un
  producto activo y se pulsa Enter (`onSubmitted`), se agrega ese producto y se limpia el
  buscador (así funciona un lector físico que escribe y envía Enter).
- **Chips de tipo** (`filtro_tipo_venta_{clave}`, `filtro_tipo_venta_todos`) bajo el
  buscador cuando el buscador se muestra y hay al menos 2 tipos en uso.
- Los mosaicos muestran "{tamaño} · {precio}" como subtítulo cuando hay tamaño.
- La venta manual queda igual (mosaicos, botón −, "Otro monto", montos rápidos).

## Fuera de alcance

Reportes por marca/tipo, escanear en Recibir mercancía, imágenes del producto, subir datos a
Open Food Facts, códigos por peso (balanza), iOS.

## Pruebas

- **Migración** v7 → v8 conserva productos y deja nulos los campos nuevos.
- **Repositorio**: guarda/lee los campos; vacíos → nulo; `productoPorCodigo` (activo,
  inactivo, inexistente); `CodigoRepetido` con otro activo; el mismo producto puede volver
  a guardar su código; un inactivo no bloquea; `marcasUsadas`.
- **Catálogo**: `tipoDesdeOff` (bebidas, lácteos, licores gana a bebidas, desconocido →
  null) y `envaseDesdeOff` (plástico, lata, desconocido → null).
- **OpenFoodFacts** con un `HttpClient` simulado (servidor local en `HttpServer` de
  `dart:io`, puerto efímero): respuesta completa, `status 0`, 404, JSON dañado y tiempo
  agotado → null.
- **Ficha**: escanear (lector falso) + consulta falsa llena solo lo vacío; "No lo
  encontramos"; código repetido muestra el error; selectores de envase y tipo guardan la
  clave.
- **Productos**: busca por marca y por código; chips de tipo filtran.
- **Venta**: escanear producto conocido lo suma; desconocido abre la hoja, exige precio, y
  al guardar crea y agrega; un vendedor también; inactivo avisa; doble lectura en 1,5 s se
  ignora; código exacto + Enter en el buscador agrega; chips de tipo filtran; subtítulo con
  tamaño.
- **Modo oscuro y letra 2,0×**: ficha, hoja rápida y venta con chips, sin excepciones.

## Entrega

Rama `codigo-barras`; plan en `docs/superpowers/plans/`; APK al final (probar la cámara con
productos reales); actualizar `docs/hoja-de-ruta.md`.
