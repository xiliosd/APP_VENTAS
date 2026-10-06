# Fase 2D — Cobro por QR

**Fecha:** 2026-10-05
**Estado:** Borrador para revisión
**Base:** master con Fase 1, 2A, 2E, 2B+2C y marca VeciTienda integradas.

## Objetivo

El tendero puede cobrar por transferencia (Nequi, Daviplata, Bre-B o su banco) mostrando en el
celular el QR que su billetera le dio, y al final del día sabe cuánto recibió en efectivo y
cuánto por transferencia, contando ventas de contado y abonos de fiado.

## Decisiones tomadas con el usuario

- **Origen del QR:** el tendero sube la foto/captura del QR que le da su billetera o banco. La
  app no genera QR (el formato EMVCo de Bre-B no se puede validar sin cuentas reales).
- **Un solo QR por tienda** (Bre-B es interoperable).
- **Los abonos de fiado también llevan medio de pago.**
- **Cobro con confirmación:** la venta/abono por transferencia se guarda solo cuando el tendero
  toca "Recibido". La app no verifica el pago; el tendero lo ve en su propia billetera.
- **Datos en la base:** la imagen del QR y el medio de pago viven en SQLite, así viajan en el
  respaldo a la nube sin cambios en esa parte.

## Modelo de datos (esquema v1 → v2)

- `Ventas.medioPago` y `PagosFiado.medioPago`: `TEXT NOT NULL DEFAULT 'efectivo'`, valores
  `'efectivo' | 'transferencia'`. En Dart, `enum MedioPago { efectivo, transferencia }` con
  conversión a texto (`lib/data/medio_pago.dart`). Las ventas fiadas guardan `'efectivo'` (valor
  por defecto) y no se cuentan en los totales por medio de pago: aún no se han pagado.
- Tabla nueva `ConfiguracionTienda` (`@DataClassName('ConfiguracionTiendaFila')`):
  `id INTEGER PRIMARY KEY` (siempre 1), `imagenQr BLOB NULL`.
- `schemaVersion = 2` con `MigrationStrategy`:
  - `onCreate`: `m.createAll()`.
  - `onUpgrade` desde 1: `addColumn(ventas, ventas.medioPago)`,
    `addColumn(pagosFiado, pagosFiado.medioPago)`, `createTable(configuracionTienda)`.
- Restaurar un respaldo v1 funciona: el restaurador ya acepta versiones ≤ la actual y Drift
  migra al abrir. Un respaldo v2 en una app v1 se sigue rechazando (comportamiento existente).

## Repositorios

- `ConfiguracionRepository` (nuevo): `Future<Uint8List?> imagenQr()`,
  `Stream<Uint8List?> observarImagenQr()`, `Future<void> guardarImagenQr(Uint8List bytes)`
  (upsert de la fila 1), `Future<void> quitarImagenQr()`.
- `VentaRepository.registrarVenta(..., MedioPago medioPago = MedioPago.efectivo)`.
- `FiadoRepository.registrarPago(..., MedioPago medioPago = MedioPago.efectivo)` y
  `pagosDelDia(DateTime dia, {int? usuarioId})`.
- `ResumenDia` suma `recibidoEfectivo` y `recibidoTransferencia`: ventas **de contado** del día
  más abonos del día, separados por medio. Respetan el filtro `usuarioId` como el resto.

## Pantallas

### Ajustes → "Cobro por QR" (solo admin)
- Nueva entrada en Ajustes que abre `ConfigurarQrScreen`.
- Muestra el QR actual (o un estado vacío "Aún no has cargado tu QR") y el texto de ayuda:
  *"Descarga tu QR desde la app de Nequi, Daviplata o tu banco y cárgalo aquí."*
- **"Cargar QR"**: `image_picker` desde la galería con `maxWidth/maxHeight: 1024` e
  `imageQuality: 85`; guarda los bytes. **"Quitar"** (solo si hay QR) lo borra.
- La selección de imagen pasa por una abstracción `SelectorImagen` inyectada por provider, para
  probar sin la galería real. Si no se elige nada, no pasa nada; si falla la lectura, aviso
  *"No se pudo cargar la imagen, prueba con otra"*.

### Nueva venta
- Con **Contado**, debajo aparece el selector **Efectivo / Transferencia** (empieza en
  Efectivo y vuelve a Efectivo al vaciar el ticket o tras cobrar). Con **Fiado** no aparece.
- Con Transferencia el botón dice **"Cobrar $X por QR"** y abre la pantalla de cobro por QR;
  la venta se registra solo si vuelve confirmada.

### Pantalla "Cobro por QR" (`CobroQrScreen`, reutilizable)
- Recibe el monto y devuelve `true` si el tendero toca **"Recibido"**, `false`/`null` si toca
  **"Cancelar"** o vuelve atrás.
- Fondo blanco; arriba el monto en letra grande y *"Pide al cliente que escanee y digite este
  valor"*; al centro la imagen del QR lo más grande posible.
- Sin QR cargado: mensaje *"Aún no has cargado tu QR"* y, solo para admin, botón
  **"Configurar QR"** que abre `ConfigurarQrScreen`. "Recibido" sigue disponible (sirve para
  transferencias hechas por llave o número).
- Tras "Recibido" en una venta: se registra con `MedioPago.transferencia`, se vacía el ticket y
  se muestra el aviso habitual con **Deshacer**.

### Abono de fiado
- La hoja de abono suma el selector **Efectivo / Transferencia**. Con Transferencia, al guardar
  abre `CobroQrScreen` con el valor del abono; el abono se registra solo con "Recibido".
- En los movimientos del cliente, el abono por transferencia muestra la etiqueta **"QR"**.

### Inicio
- La tarjeta azul "Ventas del día" agrega una línea:
  *"Recibido: efectivo $X · transferencias $Y"* (ventas de contado + abonos del día).

### Historial
- Las ventas por transferencia muestran la etiqueta **"QR"** junto al detalle.

## Pruebas

- Migración: una base creada con el esquema v1 (SQL de la versión 1) abre en v2, conserva sus
  ventas/abonos como `efectivo` y tiene la tabla de configuración.
- `ConfiguracionRepository`: guardar, reemplazar, leer, quitar.
- Repositorios: registrar venta/abono con medio; `pagosDelDia`; `ResumenDia` separa efectivo y
  transferencia, excluye ventas fiadas, incluye abonos y respeta `usuarioId`.
- Widget: selector de medio solo con Contado; "Cobrar $X por QR"; "Recibido" guarda como
  transferencia y "Cancelar" deja el ticket intacto; sin QR muestra el mensaje y el botón
  "Configurar QR" solo al admin; abono por transferencia; línea "Recibido" en Inicio; etiqueta
  "QR" en historial y en movimientos del cliente; Ajustes carga y quita el QR con un
  `SelectorImagen` falso; el vendedor no ve la entrada "Cobro por QR".
- Respaldo: una copia que incluye la imagen del QR se restaura con la imagen intacta.
- Manual: cargar una captura real de QR en el emulador y escanearla con otro celular.

## Fuera de alcance

- Generar QR propios o con monto (EMVCo / Bre-B).
- Verificar automáticamente que el pago llegó (requiere convenio con banco o pasarela).
- Varios QR por tienda, otros medios (tarjeta), gastos por medio de pago, cuadre de caja con
  base inicial.
- Subir el brillo de la pantalla al mostrar el QR.
