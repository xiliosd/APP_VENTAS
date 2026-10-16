# VeciTienda — Inicio de marca ("el toldo se abre")

Fecha: 2026-10-16. Mejora 2 de las cuatro pedidas el 2026-10-16 (ver `docs/hoja-de-ruta.md`).
Rama: `feature/inicio-de-marca`. Aplica los lineamientos UNIMINUTO v1.2.

## Intención

Hoy la app abre directo en la Bienvenida (crear tienda) o en "¿Quién eres?", con la marca pequeña
arriba. El usuario quiere un inicio más vistoso, con la marca más audaz, que haga sentir que
VeciTienda es **una app moderna y amigable**, y luego sí pasar a crear la tienda.

## Decisiones del usuario

- Dirección visual **B · "El toldo se abre"** (boceto del 2026-10-16): un toldo de franjas verdes y
  blancas baja desde arriba como cuando se abre la tienda, luego aparece el logo en su insignia
  blanca, el nombre "VeciTienda" grande y grueso y el eslogan.
- **Versión completa solo la primera vez** (≈1,5 s); **versión breve en cada arranque**: el toldo
  ya abierto y el logo con un pequeño salto (≈0,5 s).

## Metas

- Pantalla de entrada a pantalla completa con la marca protagonista.
- Transición suave a la pantalla que toque (Bienvenida o "¿Quién eres?"; si hay sesión, Inicio).
- Sin destello blanco entre la pantalla de carga de Android y Flutter.

## No metas

- Cambiar el logo, la paleta o el eslogan.
- Sonido.
- Dependencias nuevas (no se usa `flutter_native_splash`: se editan los recursos de Android a mano).

## Anti-metas

- Que el inicio haga esperar: nunca más de ≈1,5 s y siempre se puede saltar tocando.
- Que se repita la versión completa cada vez.
- Que en "reducir movimiento" haya animación.

## Cómo funciona

### Pantalla `InicioMarcaScreen`

- Fondo: `fondo` del tema (claro `#F8FAFC`; oscuro, el azul noche `#0B1220`).
- **Toldo**: franja superior de ≈ 28 % de la altura con 6 gajos redondeados abajo, alternando verde
  y blanco con borde verde, como el boceto B. Es el toldo "físico" de la marca: usa colores fijos
  en ambos temas, el verde `#16A34A` (constante nueva `ColoresApp.verdeMarca`, junto a
  `blancoMarca`) y el blanco de `blancoMarca`; no el `marcaVerde` del tema, que en oscuro es más
  claro (*decisión mía*).
- **Insignia**: cuadrado blanco redondeado (≈ 96 dp, radio ≈ 26) con `assets/marca/isotipo.png`,
  sombra suave.
- **Nombre**: "VeciTienda" con la tipografía de títulos de la app (Nunito, peso 900), ≈ 34 sp, en
  `primario`.
- **Eslogan**: `MarcaApp.slogan`, `textoSecundario`.
- Respeta la letra grande del celular sin desbordar (prueba a 2,0×).

### Versión completa (primer arranque)

1. 0–450 ms: el toldo baja (escala vertical 0 → 1 desde arriba) con la curva `Movimiento.resorte`.
2. 350–850 ms: la insignia sube y aparece; después el nombre y el eslogan, escalonados.
3. ≈ 1,5 s: pasa sola a la pantalla siguiente con un desvanecido.
- Se marca como vista en preferencias (`inicio_completo_visto = true`) al empezar, para que un
  cierre a mitad no la repita.

### Versión breve (los demás arranques)

- Toldo ya abierto; la insignia aparece con un pequeño salto (`Movimiento.resorte`); nombre y
  eslogan ya visibles. Pasa a la siguiente a los ≈ 500 ms.

### Comunes

- Tocar en cualquier parte salta al siguiente paso de inmediato.
- Con "reducir movimiento" (`Movimiento.reducido`): todo quieto y pasa a los ≈ 300 ms.
- `Semantics`: la pantalla se anuncia como "VeciTienda, la tranquilidad de tu tienda, en tu
  bolsillo"; el logo mantiene su `semanticLabel`.
- Contraste: verde y azul de marca sobre su fondo cumplen ≥ 4,5:1 en el texto (el nombre va en
  `primario`, que ya cumple en ambos temas).

### Dónde se muestra

- `RaizApp` muestra `InicioMarcaScreen` una vez por arranque del proceso, antes de decidir entre
  Inicio, Bienvenida o "¿Quién eres?". La consulta de si hay usuarios corre mientras tanto, así
  que el inicio no alarga la espera real. Si esa consulta tarda más, el inicio se queda quieto en
  su estado final hasta que termine.
- Cerrar sesión o volver a "¿Quién eres?" no lo muestra de nuevo (solo al abrir la app).

### Pantalla de carga de Android

- `launch_background.xml` (y su versión para noche) usa el mismo color de fondo que el inicio (claro
  `#F8FAFC`, oscuro `#0B1220`) en vez del blanco, para que no haya destello.
- En Android 12+ (`values-v31` y `values-night-v31`) se fija `android:windowSplashScreenBackground`
  con esos colores y `android:windowSplashScreenAnimatedIcon` con un ícono transparente, para que
  el sistema muestre solo el color y no un logo en círculo que luego "salte" a la insignia de
  Flutter (*decisión mía*).
- Los recursos de Android siguen el modo del **sistema**. Si en la app se eligió una apariencia
  distinta a la del celular, puede verse un cambio de color al abrir; se acepta, porque evitarlo
  exige código nativo y es un caso poco común (*decisión mía*).

## Pruebas

- Primer arranque: se ve el toldo, la insignia, el nombre y el eslogan; queda marcado
  `inicio_completo_visto`; tras ≈ 1,5 s pasa a la Bienvenida.
- Arranque siguiente: versión breve; pasa a "¿Quién eres?" a los ≈ 500 ms.
- Tocar salta de inmediato.
- Reducir movimiento: sin animación y pasa enseguida.
- No se repite al cerrar sesión.
- Modo oscuro y letra 2,0× sin desbordes; `Semantics` presente.
- Las pruebas existentes que montan `RaizApp` siguen pasando (el inicio debe poder saltarse o
  terminar en ellas).

## Queda al criterio de quien lo construya

- Las medidas exactas del toldo y la sombra, cuidando que se vea como el boceto B.
- Si el toldo se dibuja con widgets o con `CustomPainter`.
- La forma de saltar el inicio en las pruebas existentes (p. ej. preferencia ya marcada y breve
  con duración cero en pruebas, o avanzar el reloj).
