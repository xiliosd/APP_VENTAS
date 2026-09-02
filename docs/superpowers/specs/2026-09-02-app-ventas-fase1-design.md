# App de gestión de ventas para vendedores informales — Fase 1 (núcleo local)

**Fecha:** 2026-09-02
**Estado:** Aprobado para pasar a plan de implementación
**Fuente:** `Plan_App_Ventas_Informales_MVP.docx`

## Contexto y alcance

El documento fuente especifica un MVP completo (V1) que incluye registro de venta rápido,
fiado, resumen diario, funcionamiento 100% offline, cobro digital vía QR (Bre-B/Nequi/Daviplata)
y registro sin fricción vía OTP por SMS/WhatsApp, con sincronización a un backend Supabase.

Ese alcance completo es demasiado grande para un solo plan de implementación, y una parte
depende de proveedores externos (pasarela de pagos, WhatsApp Business API, backend). Este
spec cubre únicamente la **Fase 1**: el núcleo de la app funcionando completamente en el
dispositivo, sin backend ni servicios externos. Cobro por QR, OTP/SMS y sincronización con
Supabase quedan explícitamente fuera de este spec y se abordarán en una Fase 2 posterior.

A diferencia del documento original (que marcaba "multi-usuario con roles" como fuera de
alcance de V1), el usuario del proyecto pidió explícitamente soportar **multiusuario con
roles dentro de una misma tienda** (admin / vendedor) desde esta Fase 1, ya que varias
personas pueden operar el mismo dispositivo en un negocio.

## Objetivo de la Fase 1

Un vendedor o tienda pequeña puede, sin ningún registro externo ni conexión a internet:

- Dar de alta usuarios de la tienda (admin y vendedores) con PIN local.
- Registrar ventas en pocos toques (catálogo de productos frecuentes + montos rápidos + monto libre).
- Marcar ventas como fiado, asociarlas a un cliente, y registrar abonos posteriores.
- Registrar gastos simples del negocio.
- Ver un resumen diario en lenguaje cotidiano: cuánto se vendió, cuánto se gastó, cuánto deben los clientes — desglosado por vendedor y en total.

## Arquitectura

- **Flutter** (Dart) — proyecto Android como objetivo principal; sin cambios de arquitectura necesarios para soportar iOS a futuro.
- Capas:
  - **UI**: pantallas y widgets.
  - **Estado**: Riverpod (providers) — simple y testeable sin necesidad de un framework más pesado.
  - **Repositorios**: una clase repositorio por entidad, que encapsula el acceso a datos y expone operaciones de dominio (ej. `calcularSaldoCliente`, `registrarVenta`).
  - **Persistencia**: Drift (SQLite tipado) como única fuente de verdad. Sin red, sin backend, sin sincronización en esta fase.
- Localización: español (Colombia). Moneda: COP, formateada sin decimales (`$3.000`).
- Sin autenticación por SMS/OTP en esta fase — el "login" es una selección de usuario local + PIN de 4 dígitos (ver más abajo), pensado para compartir un mismo dispositivo entre el admin y sus vendedores, no para autenticación remota.

## Modelo de datos

| Entidad | Campos | Notas |
|---|---|---|
| `Usuario` | id, nombre, rol (`admin` \| `vendedor`), pin (4 dígitos) | El PIN se compara localmente; no hay recuperación remota (el admin puede resetear el PIN de un vendedor desde Configuración). |
| `Producto` | id, nombre, precio, activo | Solo el admin lo gestiona. Se muestra como botón en la grilla de "productos frecuentes". |
| `Cliente` | id, nombre, teléfono (opcional), notas (opcional) | Se puede crear al vuelo desde el flujo de venta fiada. |
| `Venta` | id, monto, productoId (opcional), fecha/hora, esFiado (bool), clienteId (si esFiado), usuarioId | `usuarioId` es quien la registró. |
| `PagoFiado` | id, clienteId, monto, fecha, usuarioId | Abono (parcial o total) contra la deuda de un cliente. |
| `Gasto` | id, monto, descripción (opcional), fecha, usuarioId | |

**Cálculo de saldo por cliente:** `saldo = Σ(ventas fiado del cliente) − Σ(pagos del cliente)`.
La lista de fiado se ordena por la venta fiada más antigua sin saldar primero (antigüedad de la deuda, no fecha de creación del cliente).

**Resumen diario:** total vendido, total gastado y total por cobrar (fiado generado ese día),
calculados tanto en agregado de la tienda como desglosados por `usuarioId`, para el día actual
y navegable a días anteriores.

## Permisos por rol

| Acción | Admin | Vendedor |
|---|---|---|
| Registrar venta | ✅ | ✅ |
| Marcar fiado / registrar abonos | ✅ | ✅ |
| Registrar gastos | ✅ | ✅ |
| Ver resumen del día (general y por vendedor) | ✅ | ✅ |
| Gestionar catálogo de productos | ✅ | ❌ |
| Gestionar usuarios (crear vendedores, asignar/resetear PIN) | ✅ | ❌ |

La UI oculta (no solo deshabilita) las acciones no permitidas para el rol activo: un vendedor
nunca ve la entrada de menú "Configuración" (productos y usuarios).

## Pantallas y flujos

1. **Selección de usuario + PIN**: pantalla inicial con la lista de usuarios de la tienda
   (nombre + ícono); al tocar uno se pide el PIN de 4 dígitos en un teclado numérico grande.
   Si no existe ningún usuario aún (primer uso), se fuerza la creación de un admin inicial.
2. **Inicio / Resumen del día**: totales del día (vendido, gastado, por cobrar) en lenguaje
   simple, con desglose por vendedor visible para ambos roles. Accesos directos grandes:
   "+ Venta" y "+ Gasto".
3. **Registrar venta**: grilla de productos frecuentes (si existen) + botones de montos rápidos
   ($1.000/$2.000/$5.000/$10.000...) + campo de monto libre; checkbox "Fiado" que despliega un
   selector de cliente existente o creación rápida (solo nombre).
4. **Fiado — lista "me deben"**: clientes con saldo pendiente, ordenados por deuda más antigua
   primero. Tocar un cliente abre su detalle: historial de ventas fiadas y pagos, botón
   "Registrar abono".
5. **Configuración → Productos** (solo admin): crear/editar/desactivar productos del catálogo.
6. **Configuración → Usuarios** (solo admin): crear vendedores, asignar/resetear PIN, ver
   quién es cada rol.
7. **Historial**: lista de ventas y gastos, filtrable por día y por usuario.

## Fuera de alcance en esta Fase 1

- Cobro digital vía QR (Bre-B / Nequi / Daviplata) — Fase 2.
- Autenticación remota por OTP (SMS/WhatsApp) — Fase 2. El login por PIN local es exclusivo
  de esta fase, para separar responsabilidades entre usuarios del mismo dispositivo.
- Sincronización/backup con Supabase u otro backend — Fase 2. Todos los datos viven únicamente
  en el dispositivo; se documentará este riesgo (pérdida de datos si se pierde el celular) para
  cuando se aborde la Fase 2.
- Multi-sucursal (varias tiendas independientes) — el documento original lo excluye y el pedido
  del usuario fue multiusuario dentro de **una** tienda, no multi-tienda.
- Recordatorios automáticos por WhatsApp, reportes exportables, modo de alta accesibilidad
  visual — quedan como V2 según el documento original, no se abordan aquí.

## Pruebas

- **Unit tests**: cálculo de saldo por cliente (incluyendo pagos parciales y múltiples ventas
  fiadas), cálculo de totales del resumen diario (general y por usuario), ordenamiento de la
  lista de fiado por antigüedad, validación de permisos por rol.
- **Widget tests**: flujo de registrar venta (producto, monto rápido, monto libre, marcar
  fiado), flujo de registrar abono, flujo de login por PIN (PIN correcto/incorrecto), ocultamiento
  de opciones de admin para el rol vendedor.
