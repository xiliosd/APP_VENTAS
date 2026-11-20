# Super vendedor y "cada vendedor ve lo suyo" — diseño corto

Fecha: 2026-11-20 · Tamaño: cambio pequeño (diseño corto)

## Por qué

En la tienda hay vendedores de confianza que, además de vender, necesitan agregar y editar
productos, manejar proveedores y hacer pedidos cuando el dueño no está. No son un segundo
dueño: no manejan usuarios, PIN, celulares, QR, respaldo ni ven las ganancias. Además, cada
vendedor debe ver en su Inicio solo sus propias ventas, no las de toda la tienda.

## Metas

1. **Super vendedor:** un vendedor con un permiso extra que puede:
   - ver la pestaña **Ajustes** con solo **Productos** y **Proveedores** (crear y editar);
   - usar **Editar producto** donde hoy solo lo ve el admin (venta, detalle de inventario,
     consultar precio);
   - escribir el **costo** del producto al crearlo o editarlo (opción C elegida);
   - hacer pedidos (ya puede) y **corregir o anular cualquier pedido**, no solo los suyos
     (`pedido_repository.dart:180`, `pedido_por_llegar_screen.dart:163`).
2. **Cada vendedor ve lo suyo** (vendedor y super vendedor; el admin igual que hoy):
   - Inicio: totales del día y gráfica de la semana solo con sus movimientos
     (`resumenDelDia` ya acepta `usuarioId`; `ventasDiarias` necesita el mismo filtro);
     sin la tarjeta "Por vendedor".
   - Historial: fijo en el propio usuario, sin los botones "Todos" ni de compañeros.

## No metas

- El super vendedor **no** ve Reportes ni ganancias, no pone el nombre de la tienda, no ve
  Clientes, Usuarios, Celulares, Cobro por QR ni Respaldo.
- No hay permisos sueltos por persona ni un tercer rol en la nube.
- Inventario, aviso "por pedir" y pestaña Fiado no cambian: son de la tienda, no de cada
  persona.

## Enfoques considerados

- **A. Permiso extra encima del rol `vendedor` — ELEGIDO.** Columna booleana nueva en
  `usuarios` (BD local v12) que viaja con la sincronización de filas existente. La nube no
  cambia: sigue viendo un `vendedor`, así que unirse, aprobar y desactivar funcionan igual.
- B. Tercer rol `supervendedor`: más explícito, pero exige migración Supabase
  (`solicitar_ingreso` solo acepta `vendedor`) y revisar cada `rol == 'vendedor'`.
- C. Permisos sueltos por persona: más flexible, no pedido, complica la pantalla.

## Decisiones del usuario

- Enfoque A.
- Costo: el super vendedor puede escribirlo y verlo en el formulario de producto, pero nunca
  ve Reportes ni ganancias.
- Inicio del vendedor solo con sus ventas.

## Decisiones mías (corregibles)

- En **Usuarios**, al crear o editar un vendedor, un interruptor *"Puede manejar productos,
  proveedores y pedidos"*; en la lista se muestra la etiqueta **"Super vendedor"**. El
  interruptor no aparece para administradores.
- Un getter central en la sesión (p. ej. `puedeAdministrarCatalogo` = admin o vendedor con el
  permiso) reemplaza los `esAdmin` de esas pantallas; la regla de pedidos va en `permisos.dart`
  para no repetirla.
- Historial también se limita al propio vendedor, para no dejar visible lo que se esconde en
  Inicio.
- En Inicio, lo que es deuda de la tienda ("por cobrar", clientes con deuda) sigue siendo de
  toda la tienda, porque cualquier vendedor cobra fiado a cualquier cliente; lo vendido,
  recibido y gastado se filtra al vendedor.
- Celulares sincronizados con versión anterior de la app ignoran la columna nueva: el super
  vendedor se comporta como vendedor normal hasta que actualicen.
- Preguntas frecuentes: se actualiza el tema de usuarios para explicar el super vendedor.

## Restricción conocida

Los permisos se aplican en la app de cada celular, no en la nube (igual que hoy con el
vendedor normal); no es un riesgo nuevo.

## Para quien construye

Migración Drift v11 → v12 con prueba de migración; pruebas de widget para cada pantalla que
cambia de `esAdmin` al permiso nuevo; pruebas del filtro por usuario en resumen, semana e
historial; `dart format` solo en archivos tocados y `flutter analyze` limpio.
