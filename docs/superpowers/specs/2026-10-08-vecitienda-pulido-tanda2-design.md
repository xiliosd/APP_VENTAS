# Pulido — Tanda 2: letra grande y marca

**Fecha:** 2026-10-08
**Estado:** Aprobado el diseño en conversación; falta plan
**Base:** master con la tanda 1 (484cadf, 507 pruebas).

## Objetivo

Que los textos no se partan ni se desborden con letra grande del sistema y cerrar los detalles
visuales que quedaron pendientes al aplicar la marca VeciTienda. Sin cambios de base de datos
ni librerías nuevas en la app (el script de íconos sigue usando Pillow, fuera de la app).

## Alcance

### A. Letra grande

1. **Barras de Reportes** (`lib/screens/reportes/barras_por_dia.dart`, `Barra`): los anchos de
   la etiqueta (64) y del monto (84) se multiplican por `MediaQuery.textScalerOf(context)`
   (`scale(64)`, `scale(84)`), y ambos textos van con `maxLines: 1` y `softWrap: false`.
   Aplica a "Ventas por día" y a "Horas de más venta", que usan la misma `Barra`.
2. **Encabezado de Inicio** (`lib/screens/home/home_screen.dart`): en Inicio la `AppBar`
   usa `toolbarHeight: max(kToolbarHeight, scale(20) * 1.3 + scale(12) * 1.3 + 16)`;
   "Hola, X" y el nombre de la tienda van con `maxLines: 1` y `overflow: ellipsis`.
3. **Grupo de "Por pedir"** (`lib/screens/inventario/inventario_screen.dart`): el encabezado de
   cada grupo pasa de `Row` a `OverflowBar` (alineado a los extremos; si no caben, el botón
   "Ver pedido sugerido" baja y se alinea a la derecha).

Prueba de cada uno con `textScaleFactorTestValue = 2`: sin excepciones de desborde y los textos
indicados en una sola línea.

### B. Marca

4. **Sin línea gris bajo el encabezado azul:** en Inicio, `shape: const Border()` en la `AppBar`
   (las demás pestañas conservan el borde del tema).
5. **Título del PIN en Nunito:** "Hola, X" de `ingresar_pin_screen.dart` usa
   `estiloTitulo(tamano: 22)`.
6. **Azul claro de marca:** nuevo `ColoresApp.primarioSuave = Color(0xFFDDE5F0)` (15 % de
   `#1A539B` sobre blanco). Reemplaza `0xFFDBE4FF` (indicador de la barra inferior en
   `tema_app.dart`) y `0xFFE8EDF8` (círculo de `EstadoVacio`). No quedan hex sueltos fuera de
   `colores_app.dart`.
7. **Guardia de Nunito:** prueba que recorre `lib/` y falla si `familiaTitulos` o `'Nunito'`
   aparecen fuera de `lib/ui/tipografia.dart` (todo título de marca pasa por `estiloTitulo`, que
   fija el eje `wght`; sin él la fuente variable sale con peso 200).
8. **Corte automático del isotipo** (`tool/generar_iconos.py`): en vez de `FIN_ISOTIPO = 0.59`,
   se busca de arriba hacia abajo la primera banda horizontal sin tinta (al menos 1 % de la
   altura) después de la primera fila con tinta; se corta ahí. Si no la encuentra, el script
   falla con un mensaje claro.
9. **Sin halo en el borde:** los píxeles semitransparentes del borde guardan el color de la
   tinta ya separado del blanco: `c' = clamp((c − 255·(1 − a)) / a)` por canal, con `a` en 0–1.
10. **Ícono monocromo (Android 13+):** el script genera `ic_launcher_monochrome.png` por
    densidad (silueta blanca con el alfa del primer plano) y agrega
    `<monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>` al XML adaptativo.
    Se vuelven a generar todos los íconos y el isotipo.

`test/marca/recursos_marca_test.dart` se amplía: existe el monocromo en cada densidad con el
tamaño del primer plano, y el XML adaptativo lo nombra.

## Pruebas

Tests primero en 1–7 y 10 (pantallas, tema, guardia de Nunito y recursos). 8 y 9 se verifican
corriendo el script y revisando el isotipo resultante a ojo; la prueba de recursos sigue
pasando. Al terminar: suite completa verde, `flutter analyze` sin problemas y el APK compila.

## Fuera de alcance

Mejoras internas sin efecto visible (tanda 3).
