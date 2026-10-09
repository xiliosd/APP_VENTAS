# Renovación R1 — Base (modo oscuro y estilo Expressive) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Toda la app con colores por tema (claro y oscuro "Azul noche"), selector de
apariencia, formas Expressive, tipografía enfatizada, movimiento con resorte, vibración y
montos animados, sin cambiar la distribución de ninguna pantalla.

**Architecture:** `ColoresApp` pasa de constantes estáticas a un `ThemeExtension` con dos
instancias (`claro`, `oscuro`) leído con `ColoresApp.of(context)`; `tema_app.dart` construye
`temaClaro()`/`temaOscuro()` desde un mismo constructor. Un `aparienciaProvider` (Riverpod +
`shared_preferences`) da el `ThemeMode`. Movimiento y vibración viven en módulos propios
(`movimiento.dart`, `vibracion.dart`) que los componentes consumen.

**Tech Stack:** Flutter 3.47, Riverpod 2, shared_preferences 2.5.5, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-vecitienda-renovacion-r1-design.md`

## Global Constraints

- Sin dependencias nuevas; sin cambios de esquema de base de datos.
- No cambia la distribución ni los textos de ninguna pantalla (solo colores, formas, movimiento,
  vibración y la entrada "Apariencia" del menú de la cuenta).
- Contraste texto/fondo ≥ 4,5:1 (texto grande ≥ 3:1) en ambos modos.
- Ningún `Color(0x…)`, `Colors.white*` ni `Colors.black*` fuera de `lib/ui/colores_app.dart`.
- Todas las duraciones y curvas salen de `lib/ui/movimiento.dart`; con
  `MediaQuery.disableAnimationsOf(context)` todo es instantáneo.
- Áreas de toque ≥ 48 dp; la letra grande del celular sigue funcionando.
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- No aplicar `dart format` a archivos enteros (genera ruido); formatear solo lo cambiado.
- Rama `renovacion-r1` desde `master`.

## Review Focus

- Un monto que cambia mientras su animación de conteo sigue en curso (dos ventas seguidas):
  termina en el último valor, no en el intermedio — Task 6.
- Abrir la app con modo oscuro forzado y el celular en claro (y al revés): manda la elección
  guardada, no el sistema — Task 2.
- Letra grande del celular + modo oscuro en Inicio (vista angosta): sin desbordes — Task 7.
- Pantalla del QR de cobro en modo oscuro: el código sigue sobre fondo blanco para poder
  escanearse — Task 1.
- Una pantalla reconstruida por un dato nuevo (stream) no repite la entrada escalonada — Task 6.

---

### Task 1: Paleta por tema y migración de colores

**Files:**
- Modify: `lib/ui/colores_app.dart` (reescrito), `lib/ui/tema_app.dart`, `lib/ui/tipografia.dart`,
  `lib/main.dart`, y todos los archivos de `lib/` que usan `ColoresApp.` (40) o colores sueltos
  (lista en Step 6).
- Modify tests: `test/support/montaje.dart`, `test/ui/tema_app_test.dart`,
  `test/ui/componentes_test.dart`, `test/screens/home/home_screen_test.dart`,
  `test/screens/home/resumen_screen_test.dart`,
  `test/screens/inventario/inventario_screen_test.dart`,
  `test/screens/reportes/reportes_screen_test.dart` y todo test que llame `temaApp()` (11 archivos).
- Create: `test/ui/colores_sueltos_test.dart`

**Interfaces — Produces:**
- `class ColoresApp extends ThemeExtension<ColoresApp>` con campos `fondo, superficie, borde,
  texto, textoSecundario, primario, sobrePrimario, primarioSuave, tarjetaPrincipal,
  sobreTarjetaPrincipal, marcaVerde, entra, rellenoEntra, sobreEntra, entraSuave, sale,
  sobreSale, saleSuave, fiado, fiadoSuave, fondoAviso, textoAviso, accionAviso` (todos `Color`).
- `static const ColoresApp claro`, `static const ColoresApp oscuro`,
  `static const Color blancoMarca`, `static const List<Color> paletaAvatar`.
- `static ColoresApp of(BuildContext context)`.
- `ThemeData temaClaro()`, `ThemeData temaOscuro()` (se elimina `temaApp()`).
- `TextStyle estiloTitulo({double tamano = 24, Color? color})`.
- `Monto.colorDe(TonoMonto tono, ColoresApp c)`.

- [ ] **Step 1: Crear la rama**

```bash
git checkout -b renovacion-r1
```

- [ ] **Step 2: Escribir las pruebas nuevas de paleta (fallan)**

Reemplazar en `test/ui/tema_app_test.dart` los tests `'los pares de texto y fondo cumplen
contraste 4.5:1'`, `'el tema usa el color primario, el fondo y la fuente Inter'`,
`'la paleta es la de VeciTienda'`, `'el verde de marca solo se usa en gráficos…'` y
`'los tonos claros salen del azul de marca'` por:

```dart
Map<String, (Color, Color)> paresDe(ColoresApp c) => {
      'texto/fondo': (c.texto, c.fondo),
      'texto/superficie': (c.texto, c.superficie),
      'secundario/fondo': (c.textoSecundario, c.fondo),
      'secundario/superficie': (c.textoSecundario, c.superficie),
      'primario/superficie': (c.primario, c.superficie),
      'primario/fondo': (c.primario, c.fondo),
      'primario/primarioSuave': (c.primario, c.primarioSuave),
      'sobrePrimario/primario': (c.sobrePrimario, c.primario),
      'sobreTarjeta/tarjeta': (c.sobreTarjetaPrincipal, c.tarjetaPrincipal),
      'entra/superficie': (c.entra, c.superficie),
      'sobreEntra/rellenoEntra': (c.sobreEntra, c.rellenoEntra),
      'sale/superficie': (c.sale, c.superficie),
      'sobreSale/sale': (c.sobreSale, c.sale),
      'fiado/superficie': (c.fiado, c.superficie),
      'fiado/fiadoSuave': (c.fiado, c.fiadoSuave),
      'texto/fiadoSuave': (c.texto, c.fiadoSuave),
      'textoAviso/fondoAviso': (c.textoAviso, c.fondoAviso),
      'accionAviso/fondoAviso': (c.accionAviso, c.fondoAviso),
    };

for (final (nombre, c) in [('claro', ColoresApp.claro), ('oscuro', ColoresApp.oscuro)]) {
  test('modo $nombre: los pares de texto y fondo cumplen 4.5:1', () {
    paresDe(c).forEach((par, colores) {
      expect(contraste(colores.$1, colores.$2), greaterThanOrEqualTo(4.5),
          reason: '$nombre $par');
    });
  });

  test('modo $nombre: el verde de marca se distingue (≥ 3:1) sobre la superficie', () {
    expect(contraste(c.marcaVerde, c.superficie), greaterThanOrEqualTo(3));
  });
}

test('los avatares tienen texto blanco legible', () {
  for (final color in ColoresApp.paletaAvatar) {
    expect(contraste(ColoresApp.blancoMarca, color), greaterThanOrEqualTo(4.5),
        reason: '$color');
  }
});

test('la paleta clara es la de VeciTienda y la oscura es Azul noche', () {
  expect(ColoresApp.claro.primario, const Color(0xFF1A539B));
  expect(ColoresApp.claro.marcaVerde, const Color(0xFF16A34A));
  expect(ColoresApp.claro.fondo, const Color(0xFFF8FAFC));
  expect(ColoresApp.claro.texto, const Color(0xFF1E293B));
  expect(ColoresApp.claro.primarioSuave, const Color(0xFFDDE5F0));
  expect(ColoresApp.oscuro.fondo, const Color(0xFF0B1220));
  expect(ColoresApp.oscuro.superficie, const Color(0xFF131C2E));
  expect(ColoresApp.oscuro.tarjetaPrincipal, const Color(0xFF1B3A66));
});

test('cada tema registra su paleta, su brillo, su fondo y la fuente Inter', () {
  final claro = temaClaro();
  final oscuro = temaOscuro();
  expect(claro.extension<ColoresApp>(), ColoresApp.claro);
  expect(oscuro.extension<ColoresApp>(), ColoresApp.oscuro);
  expect(claro.brightness, Brightness.light);
  expect(oscuro.brightness, Brightness.dark);
  expect(claro.colorScheme.primary, ColoresApp.claro.primario);
  expect(oscuro.scaffoldBackgroundColor, ColoresApp.oscuro.fondo);
  expect(oscuro.textTheme.bodyMedium!.fontFamily, 'Inter');
  expect(claro.navigationBarTheme.indicatorColor, ColoresApp.claro.primarioSuave);
});
```

En el resto del archivo, `temaApp()` → `temaClaro()`.

Crear `test/ui/colores_sueltos_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún color suelto fuera de colores_app.dart', () {
    final patron = RegExp(r'Color\(0x|Colors\.(white|black)');
    final fuera = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (ruta.endsWith('lib/ui/colores_app.dart')) continue;
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (patron.hasMatch(lineas[i])) fuera.add('$ruta:${i + 1}');
      }
    }
    expect(fuera, isEmpty, reason: 'Usar ColoresApp.of(context)');
  });
}
```

- [ ] **Step 3: Ejecutar y ver que fallan**

Run: `flutter test test/ui/tema_app_test.dart test/ui/colores_sueltos_test.dart`
Expected: FAIL de compilación (`ColoresApp.claro`, `temaClaro` no existen).

- [ ] **Step 4: Reescribir `lib/ui/colores_app.dart`**

```dart
import 'package:flutter/material.dart';

/// Tokens de color de la app: uno por modo (claro y oscuro "Azul noche").
/// Las pantallas los leen con `ColoresApp.of(context)`; nunca hex sueltos.
@immutable
class ColoresApp extends ThemeExtension<ColoresApp> {
  const ColoresApp({
    required this.fondo,
    required this.superficie,
    required this.borde,
    required this.texto,
    required this.textoSecundario,
    required this.primario,
    required this.sobrePrimario,
    required this.primarioSuave,
    required this.tarjetaPrincipal,
    required this.sobreTarjetaPrincipal,
    required this.marcaVerde,
    required this.entra,
    required this.rellenoEntra,
    required this.sobreEntra,
    required this.entraSuave,
    required this.sale,
    required this.sobreSale,
    required this.saleSuave,
    required this.fiado,
    required this.fiadoSuave,
    required this.fondoAviso,
    required this.textoAviso,
    required this.accionAviso,
  });

  final Color fondo;
  final Color superficie;
  final Color borde;
  final Color texto;
  final Color textoSecundario;

  /// Marca, selección, enlaces y relleno del botón primario.
  final Color primario;
  final Color sobrePrimario;

  /// Fondos de selección e íconos, indicador de la navegación.
  final Color primarioSuave;

  /// Tarjeta del monto del día y encabezado del Inicio.
  final Color tarjetaPrincipal;
  final Color sobreTarjetaPrincipal;

  /// Verde de la marca (acentos). En claro **nunca para texto** (3.1:1).
  final Color marcaVerde;

  /// Dinero que entra (texto): ventas, ganancia, abonos.
  final Color entra;

  /// Relleno del botón Cobrar / confirmar, y su texto.
  final Color rellenoEntra;
  final Color sobreEntra;
  final Color entraSuave;

  /// Dinero que sale, errores y acciones destructivas.
  final Color sale;
  final Color sobreSale;
  final Color saleSuave;

  /// Fiado y por cobrar.
  final Color fiado;
  final Color fiadoSuave;

  /// Aviso flotante (SnackBar).
  final Color fondoAviso;
  final Color textoAviso;
  final Color accionAviso;

  static const claro = ColoresApp(
    fondo: Color(0xFFF8FAFC),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFE5E7EB),
    texto: Color(0xFF1E293B),
    textoSecundario: Color(0xFF64748B),
    primario: Color(0xFF1A539B),
    sobrePrimario: Color(0xFFFFFFFF),
    primarioSuave: Color(0xFFDDE5F0),
    tarjetaPrincipal: Color(0xFF1A539B),
    sobreTarjetaPrincipal: Color(0xFFFFFFFF),
    marcaVerde: Color(0xFF16A34A),
    entra: Color(0xFF15803D),
    rellenoEntra: Color(0xFF15803D),
    sobreEntra: Color(0xFFFFFFFF),
    entraSuave: Color(0xFFBBF7D0),
    sale: Color(0xFFDC2626),
    sobreSale: Color(0xFFFFFFFF),
    saleSuave: Color(0xFFFECACA),
    fiado: Color(0xFFB45309),
    fiadoSuave: Color(0xFFFEF3C7),
    fondoAviso: Color(0xFF1E293B),
    textoAviso: Color(0xFFFFFFFF),
    accionAviso: Color(0xFF93C5FD),
  );

  static const oscuro = ColoresApp(
    fondo: Color(0xFF0B1220),
    superficie: Color(0xFF131C2E),
    borde: Color(0xFF243049),
    texto: Color(0xFFE2E8F0),
    textoSecundario: Color(0xFF94A3B8),
    primario: Color(0xFF9CC0F0),
    sobrePrimario: Color(0xFF0B1F3F),
    primarioSuave: Color(0xFF1E3A5F),
    tarjetaPrincipal: Color(0xFF1B3A66),
    sobreTarjetaPrincipal: Color(0xFFF1F5F9),
    marcaVerde: Color(0xFF4ADE80),
    entra: Color(0xFF4ADE80),
    rellenoEntra: Color(0xFF22C55E),
    sobreEntra: Color(0xFF052E16),
    entraSuave: Color(0xFF14532D),
    sale: Color(0xFFF87171),
    sobreSale: Color(0xFF450A0A),
    saleSuave: Color(0xFF7F1D1D),
    fiado: Color(0xFFFBBF24),
    fiadoSuave: Color(0xFF2A2010),
    fondoAviso: Color(0xFFE2E8F0),
    textoAviso: Color(0xFF0B1220),
    accionAviso: Color(0xFF1A539B),
  );

  /// Blanco fijo (no cambia por tema): insignia del logo y fondo del QR, que
  /// debe ser blanco para escanearse. También el texto de los avatares.
  static const blancoMarca = Color(0xFFFFFFFF);

  /// Colores de los avatares (iguales en ambos modos, texto [blancoMarca]).
  static const paletaAvatar = [
    Color(0xFF1A539B),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF15803D),
  ];

  static ColoresApp of(BuildContext context) =>
      Theme.of(context).extension<ColoresApp>() ?? claro;

  @override
  ColoresApp copyWith() => this;

  @override
  ColoresApp lerp(ColoresApp? otro, double t) {
    if (otro == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresApp(
      fondo: l(fondo, otro.fondo),
      superficie: l(superficie, otro.superficie),
      borde: l(borde, otro.borde),
      texto: l(texto, otro.texto),
      textoSecundario: l(textoSecundario, otro.textoSecundario),
      primario: l(primario, otro.primario),
      sobrePrimario: l(sobrePrimario, otro.sobrePrimario),
      primarioSuave: l(primarioSuave, otro.primarioSuave),
      tarjetaPrincipal: l(tarjetaPrincipal, otro.tarjetaPrincipal),
      sobreTarjetaPrincipal: l(sobreTarjetaPrincipal, otro.sobreTarjetaPrincipal),
      marcaVerde: l(marcaVerde, otro.marcaVerde),
      entra: l(entra, otro.entra),
      rellenoEntra: l(rellenoEntra, otro.rellenoEntra),
      sobreEntra: l(sobreEntra, otro.sobreEntra),
      entraSuave: l(entraSuave, otro.entraSuave),
      sale: l(sale, otro.sale),
      sobreSale: l(sobreSale, otro.sobreSale),
      saleSuave: l(saleSuave, otro.saleSuave),
      fiado: l(fiado, otro.fiado),
      fiadoSuave: l(fiadoSuave, otro.fiadoSuave),
      fondoAviso: l(fondoAviso, otro.fondoAviso),
      textoAviso: l(textoAviso, otro.textoAviso),
      accionAviso: l(accionAviso, otro.accionAviso),
    );
  }
}
```

- [ ] **Step 5: Temas claro y oscuro en `lib/ui/tema_app.dart`**

Renombrar `temaApp()` a un constructor privado `_tema(ColoresApp c, Brightness brillo)` y
exponer:

```dart
/// Temas de la app; todas las pantallas los heredan de MaterialApp.
ThemeData temaClaro() => _tema(ColoresApp.claro, Brightness.light);
ThemeData temaOscuro() => _tema(ColoresApp.oscuro, Brightness.dark);
```

Dentro de `_tema`: `ColorScheme.fromSeed(seedColor: c.primario, brightness: brillo,
primary: c.primario, onPrimary: c.sobrePrimario, secondary: c.entra, onSecondary:
c.sobreEntra, error: c.sale, onError: c.sobreSale, surface: c.superficie, onSurface: c.texto,
onSurfaceVariant: c.textoSecundario, outline: c.borde, outlineVariant: c.borde)`; en
`ThemeData` agregar `brightness: brillo` y `extensions: [c]`; cada `ColoresApp.x` pasa a `c.x`
(quitando `const` donde haga falta). El SnackBar usa `c.fondoAviso`, `c.textoAviso`,
`c.accionAviso`; el FAB `c.primario`/`c.sobrePrimario`. `titleTextStyle:
estiloTitulo(tamano: 20, color: c.texto)`. Las formas no cambian en esta tarea.

`lib/ui/tipografia.dart`: quitar el import de `colores_app.dart` y cambiar la firma a
`TextStyle estiloTitulo({double tamano = 24, Color? color})` (con `color` null el texto hereda
el color del tema).

`lib/main.dart`: `theme: temaClaro(), darkTheme: temaOscuro(),` (el `themeMode` llega en la
Task 2; por ahora sigue al sistema).

`test/support/montaje.dart`: `appDePrueba` recibe un parámetro opcional
`ThemeData? tema` y usa `theme: tema ?? temaClaro()`.

- [ ] **Step 6: Migrar `lib/` a `ColoresApp.of(context)`**

Regla para cada archivo de la lista de `grep -rln "ColoresApp\." lib`:
- Al inicio del `build` (o del método que tenga `context`): `final c = ColoresApp.of(context);`
  y `ColoresApp.x` → `c.x`. Quitar `const` de los constructores que ahora usan `c`.
- Si un widget o función no tiene `context`, recibirlo como parámetro (p. ej.
  `Monto.colorDe(TonoMonto tono, ColoresApp c)`); si es una lista constante de nivel superior
  con colores (p. ej. `_paleta` de `avatar_inicial.dart`), usar `ColoresApp.paletaAvatar`.
- `ColoresApp.marcaVerde` en `marca_app.dart` y el resto de usos de marca también salen del tema.

Reemplazo de los colores sueltos (salida de
`grep -rn "Color(0x\|Colors\.\(white\|black\)" lib`):

| Archivo:línea | Antes | Después |
|---|---|---|
| `home_screen.dart:78-81` | `ColoresApp.primario` / `Colors.white` en la barra del Inicio | `c.tarjetaPrincipal` / `c.sobreTarjetaPrincipal` (título con `estiloTitulo(tamano: 20, color: c.sobreTarjetaPrincipal)`) |
| `home_screen.dart:101` | `Colors.white70` | `c.sobreTarjetaPrincipal.withValues(alpha: 0.75)` |
| `home_screen.dart:155` | anillo `Colors.white` | `c.sobreTarjetaPrincipal` |
| `home_screen.dart:190` | insignia `Colors.white` | `ColoresApp.blancoMarca` |
| `resumen_screen.dart:140` | `ColoresApp.primario` (tarjeta ventas) | `c.tarjetaPrincipal` |
| `resumen_screen.dart:149,156,164` | `Colors.white70` | `c.sobreTarjetaPrincipal.withValues(alpha: 0.75)` |
| `cobro_qr_screen.dart:46,49` | `Colors.white` | `ColoresApp.blancoMarca` (el QR siempre sobre blanco) |
| `avatar_inicial.dart:5-12,40` | `_paleta`, `Colors.white` | `ColoresApp.paletaAvatar`, `ColoresApp.blancoMarca` |
| `boton_principal.dart:39-41` | `entra` / `Colors.white` | `c.rellenoEntra` / `c.sobreEntra` |
| `monto.dart:32` | `TonoMonto.claro => Colors.white` | `TonoMonto.claro => c.sobreTarjetaPrincipal` |
| `mosaico.dart:92` | `Colors.white` (insignia) | `c.sobrePrimario` |
| `selector_segmentado.dart:33` | `Colors.white` | `c.sobrePrimario` |
| `tarjeta_monto.dart:34` | `Colors.white70` | `c.sobreTarjetaPrincipal.withValues(alpha: 0.75)` |
| `tema_app.dart` | `Colors.white`, `Color(0xFF93C5FD)` | tokens de Step 5 |

- [ ] **Step 7: Migrar las pruebas existentes**

En los tests: `temaApp()` → `temaClaro()`; `ColoresApp.x` → `ColoresApp.claro.x` (las pruebas
montan el tema claro). En `home_screen_test.dart:118-119`:

```dart
expect(barra().backgroundColor, ColoresApp.claro.tarjetaPrincipal);
expect(barra().foregroundColor, ColoresApp.claro.sobreTarjetaPrincipal);
```

En `test/ui/componentes_test.dart` el test de color de `Monto` sigue esperando
`ColoresApp.claro.sale`.

Agregar a `test/screens/qr/` (en el archivo de pruebas de `cobro_qr_screen` que ya existe) un
test que monte la pantalla con `tema: temaOscuro()` y verifique que el `Scaffold` tiene
`backgroundColor == ColoresApp.blancoMarca`.

- [ ] **Step 8: Verificar**

Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: todas en verde (530 previas + nuevas).

Si algún par de contraste del modo oscuro no llega a 4,5:1, ajustar la luminosidad del color
en `ColoresApp.oscuro` conservando el tono y actualizar la tabla de la especificación.

- [ ] **Step 9: Commit**

```bash
git add -A lib test docs/superpowers/specs/2026-10-09-vecitienda-renovacion-r1-design.md
git commit -m "Read colors from the theme and add the Azul noche dark palette"
```

---

### Task 2: Selector de apariencia

**Files:**
- Create: `lib/providers/apariencia_provider.dart`, `lib/screens/home/hoja_apariencia.dart`,
  `test/providers/apariencia_provider_test.dart`, `test/screens/home/hoja_apariencia_test.dart`
- Modify: `lib/main.dart` (`AppVentas` pasa a `ConsumerWidget`),
  `lib/screens/home/home_screen.dart` (`_MenuCuenta`)

**Interfaces:**
- Consumes: `preferenciasProvider` (`lib/respaldo/respaldo_provider.dart`), `temaClaro()`,
  `temaOscuro()`, `SelectorSegmentado` (`lib/ui/selector_segmentado.dart`),
  `mostrarHojaInferior<T>(BuildContext, {required String titulo, required WidgetBuilder builder})`
  (`lib/ui/hoja_inferior.dart`).
- Produces: `final aparienciaProvider = NotifierProvider<AparienciaNotifier, ThemeMode>`;
  `AparienciaNotifier.elegir(ThemeMode modo)`; `Future<void> mostrarHojaApariencia(BuildContext)`.

- [ ] **Step 1: Test del provider (falla)**

```dart
import 'package:app_ventas/providers/apariencia_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> contenedor(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)]);
}

void main() {
  test('sin elección guardada sigue al sistema', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    expect(c.read(aparienciaProvider), ThemeMode.system);
  });

  test('elegir oscuro lo guarda y lo conserva al reabrir', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    await c.read(aparienciaProvider.notifier).elegir(ThemeMode.dark);
    expect(c.read(aparienciaProvider), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('apariencia'), 'oscuro');

    final otra = ProviderContainer(
        overrides: [preferenciasProvider.overrideWithValue(prefs)]);
    addTearDown(otra.dispose);
    expect(otra.read(aparienciaProvider), ThemeMode.dark);
  });

  test('un valor ilegible se toma como Automático', () async {
    final c = await contenedor({'apariencia': 'violeta'});
    addTearDown(c.dispose);
    expect(c.read(aparienciaProvider), ThemeMode.system);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/providers/apariencia_provider_test.dart` — Expected: FAIL (no existe el archivo).

- [ ] **Step 3: Implementar `lib/providers/apariencia_provider.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

const _clave = 'apariencia';
const _valores = {
  ThemeMode.system: 'sistema',
  ThemeMode.light: 'claro',
  ThemeMode.dark: 'oscuro',
};

/// Apariencia elegida en este celular: Automático (sigue al sistema), Claro u
/// Oscuro. Si no hay elección o no se entiende, Automático.
class AparienciaNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return _valores.entries
            .where((e) => e.value == guardado)
            .map((e) => e.key)
            .firstOrNull ??
        ThemeMode.system;
  }

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    await ref.read(preferenciasProvider).setString(_clave, _valores[modo]!);
  }
}

final aparienciaProvider =
    NotifierProvider<AparienciaNotifier, ThemeMode>(AparienciaNotifier.new);
```

- [ ] **Step 4: Run** `flutter test test/providers/apariencia_provider_test.dart` — Expected: PASS.

- [ ] **Step 5: Test de la hoja y del menú (falla)**

`test/screens/home/hoja_apariencia_test.dart`: montar `HomeScreen` con `containerConSesion`
(agregando `preferenciasProvider.overrideWithValue(prefs)` a `overrides`) dentro de un
`MaterialApp` que lea `aparienciaProvider` igual que `AppVentas`:

```dart
testWidgets('desde el menú de la cuenta se elige el modo oscuro', (tester) async {
  // ...montaje con UncontrolledProviderScope + Consumer que arma
  // MaterialApp(theme: temaClaro(), darkTheme: temaOscuro(),
  //   themeMode: ref.watch(aparienciaProvider), home: const HomeScreen())
  await tester.tap(find.byKey(const Key('menu_cuenta')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_apariencia')));
  await tester.pumpAndSettle();
  expect(find.text('Automático'), findsOneWidget);
  expect(find.text('Claro'), findsOneWidget);
  await tester.tap(find.text('Oscuro'));
  await tester.pumpAndSettle();

  final contexto = tester.element(find.byType(HomeScreen));
  expect(Theme.of(contexto).brightness, Brightness.dark);
  expect(container.read(aparienciaProvider), ThemeMode.dark);
});

testWidgets('un vendedor también ve Apariencia', (tester) async {
  // containerConSesion(db, rol: 'vendedor', overrides: [...prefs])
  await tester.tap(find.byKey(const Key('menu_cuenta')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('boton_apariencia')), findsOneWidget);
});
```

- [ ] **Step 6: Run** `flutter test test/screens/home/hoja_apariencia_test.dart` — Expected: FAIL.

- [ ] **Step 7: Implementar hoja, menú y `main.dart`**

`lib/screens/home/hoja_apariencia.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/apariencia_provider.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/selector_segmentado.dart';

/// Hoja para elegir Automático / Claro / Oscuro; el cambio se aplica al tocar.
Future<void> mostrarHojaApariencia(BuildContext context) {
  return mostrarHojaInferior<void>(
    context,
    titulo: 'Apariencia',
    builder: (_) => Consumer(
      builder: (context, ref, _) => SelectorSegmentado<ThemeMode>(
        valor: ref.watch(aparienciaProvider),
        opciones: const {
          ThemeMode.system: 'Automático',
          ThemeMode.light: 'Claro',
          ThemeMode.dark: 'Oscuro',
        },
        onCambio: (modo) => ref.read(aparienciaProvider.notifier).elegir(modo),
      ),
    ),
  );
}
```

`_MenuCuenta` en `home_screen.dart`: `onSelected` distingue el valor:

```dart
onSelected: (valor) {
  if (valor == 'apariencia') {
    mostrarHojaApariencia(context);
  } else {
    ref.read(sesionProvider.notifier).cerrarSesion();
  }
},
itemBuilder: (_) => [
  const PopupMenuItem<String>(
    key: Key('boton_apariencia'),
    value: 'apariencia',
    child: Row(children: [
      Icon(Icons.dark_mode_outlined),
      SizedBox(width: 12),
      Text('Apariencia'),
    ]),
  ),
  // ...el PopupMenuItem de cerrar sesión sin cambios
],
```

`lib/main.dart`: `AppVentas` pasa a `ConsumerWidget` y agrega
`themeMode: ref.watch(aparienciaProvider)`.

- [ ] **Step 8: Run** `flutter test test/screens/home/ test/providers/` y `flutter analyze` — Expected: PASS / sin problemas.

- [ ] **Step 9: Commit**

```bash
git add lib/providers/apariencia_provider.dart lib/screens/home lib/main.dart test/providers/apariencia_provider_test.dart test/screens/home/hoja_apariencia_test.dart
git commit -m "Let any user pick automatic, light or dark appearance"
```

---

### Task 3: Módulos de movimiento y vibración

**Files:**
- Create: `lib/ui/movimiento.dart`, `lib/ui/vibracion.dart`, `test/ui/movimiento_test.dart`,
  `test/support/vibraciones.dart`

**Interfaces — Produces:**
- `abstract final class Movimiento { static const Curve resorte; static const Curve enfatizada;
  static const Duration corta, media, larga, conteo; static bool reducido(BuildContext);
  static Duration duracion(BuildContext, Duration d); }`
- `abstract final class Vibracion { static void toque(); static void exito(); static void error(); }`
- Test helper `List<String> registrarVibraciones(WidgetTester tester)` que devuelve la lista
  (viva) de tipos (`'HapticFeedbackType.selectionClick'`, …).

- [ ] **Step 1: Tests (fallan)**

`test/support/vibraciones.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intercepta el canal de plataforma y anota cada vibración pedida.
List<String> registrarVibraciones(WidgetTester tester) {
  final registro = <String>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
    if (llamada.method == 'HapticFeedback.vibrate') {
      registro.add(llamada.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return registro;
}
```

`test/ui/movimiento_test.dart`:

```dart
import 'package:app_ventas/ui/movimiento.dart';
import 'package:app_ventas/ui/vibracion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/vibraciones.dart';

void main() {
  testWidgets('con reducir movimiento las duraciones son cero', (tester) async {
    late Duration normal, reducida;
    await tester.pumpWidget(Builder(builder: (context) {
      normal = Movimiento.duracion(context, Movimiento.media);
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          reducida = Movimiento.duracion(context, Movimiento.media);
          return const SizedBox();
        }),
      );
    }));
    expect(normal, Movimiento.media);
    expect(reducida, Duration.zero);
  });

  test('el resorte rebota por encima de 1 y termina en 1', () {
    final valores = [for (var t = 0.0; t <= 1.0; t += 0.05) Movimiento.resorte.transform(t)];
    expect(valores.any((v) => v > 1.0), isTrue);
    expect(Movimiento.resorte.transform(1.0), closeTo(1.0, 1e-6));
  });

  testWidgets('cada vibración usa su tipo', (tester) async {
    final registro = registrarVibraciones(tester);
    Vibracion.toque();
    Vibracion.exito();
    Vibracion.error();
    await tester.pump();
    expect(registro, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/ui/movimiento_test.dart` — Expected: FAIL (no existen).

- [ ] **Step 3: Implementar**

`lib/ui/movimiento.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Duraciones y curvas de toda la app (estilo Material 3 Expressive). Ningún
/// otro archivo define las suyas.
abstract final class Movimiento {
  /// Con rebote: presionar, aparecer.
  static const Curve resorte = Cubic(0.34, 1.6, 0.5, 1);

  /// Entrar y salir.
  static const Curve enfatizada = Curves.easeInOutCubicEmphasized;

  static const corta = Duration(milliseconds: 150);
  static const media = Duration(milliseconds: 300);
  static const larga = Duration(milliseconds: 500);
  static const conteo = Duration(milliseconds: 700);

  /// El celular pide quitar animaciones.
  static bool reducido(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], o cero si el celular pide quitar animaciones.
  static Duration duracion(BuildContext context, Duration d) =>
      reducido(context) ? Duration.zero : d;
}
```

`lib/ui/vibracion.dart`:

```dart
import 'package:flutter/services.dart';

/// Vibraciones de la app. Respetan la configuración de vibración del celular.
abstract final class Vibracion {
  /// Tocar una tecla, un producto o un botón; cambiar de pestaña.
  static void toque() => HapticFeedback.selectionClick();

  /// Algo se registró bien (aviso de confirmación).
  static void exito() => HapticFeedback.mediumImpact();

  /// PIN incorrecto o falta un dato.
  static void error() => HapticFeedback.heavyImpact();
}
```

- [ ] **Step 4: Run** `flutter test test/ui/movimiento_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/movimiento.dart lib/ui/vibracion.dart test/ui/movimiento_test.dart test/support/vibraciones.dart
git commit -m "Add shared motion tokens and haptic helpers"
```

---

### Task 4: Formas, tipografía y transiciones en el tema

**Files:**
- Modify: `lib/ui/tema_app.dart`, `lib/ui/tarjeta_monto.dart`, `lib/ui/avisos.dart`,
  `lib/screens/home/resumen_screen.dart` (radio 24 y monto 36 en la tarjeta de ventas),
  `test/ui/tema_app_test.dart`, `test/ui/componentes_test.dart`

**Interfaces:**
- Consumes: `Movimiento.larga` (Task 3), `ColoresApp` (Task 1).
- Produces: constantes en `tema_app.dart`: `const radioTarjeta = 18.0`,
  `const radioTarjetaPrincipal = 24.0`, `const radioCampo = 14.0`, `const radioHoja = 28.0`.

- [ ] **Step 1: Tests (fallan)**

En `test/ui/tema_app_test.dart` reemplazar `'los botones principales tienen radio 16'` por:

```dart
for (final (nombre, tema) in [('claro', temaClaro()), ('oscuro', temaOscuro())]) {
  test('modo $nombre: formas Expressive', () {
    expect(tema.filledButtonTheme.style!.shape!.resolve({}), isA<StadiumBorder>());
    expect(tema.outlinedButtonTheme.style!.shape!.resolve({}), isA<StadiumBorder>());
    final tarjeta = tema.cardTheme.shape! as RoundedRectangleBorder;
    expect(tarjeta.borderRadius, BorderRadius.circular(radioTarjeta));
    final hoja = tema.bottomSheetTheme.shape! as RoundedRectangleBorder;
    expect(hoja.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(radioHoja)));
    final dialogo = tema.dialogTheme.shape! as RoundedRectangleBorder;
    expect(dialogo.borderRadius, BorderRadius.circular(radioHoja));
    expect(tema.snackBarTheme.shape, isA<StadiumBorder>());
    final campo = tema.inputDecorationTheme.border! as OutlineInputBorder;
    expect(campo.borderRadius, BorderRadius.circular(radioCampo));
    expect(tema.appBarTheme.titleTextStyle!.fontSize, 22);
    expect(tema.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadeForwardsPageTransitionsBuilder>());
  });
}

test('en claro las tarjetas no tienen borde gris; en oscuro tampoco', () {
  for (final tema in [temaClaro(), temaOscuro()]) {
    final forma = tema.cardTheme.shape! as RoundedRectangleBorder;
    expect(forma.side, BorderSide.none);
  }
});
```

En `test/ui/componentes_test.dart` agregar:

```dart
testWidgets('TarjetaMonto sin color de borde no dibuja borde y usa radio 18',
    (tester) async {
  await tester.pumpWidget(_app(const TarjetaMonto(etiqueta: 'Gastos', valor: 1)));
  final material = tester.widget<Material>(find.descendant(
      of: find.byType(TarjetaMonto), matching: find.byType(Material)).first);
  final forma = material.shape! as RoundedRectangleBorder;
  expect(forma.side, BorderSide.none);
  expect(forma.borderRadius, BorderRadius.circular(radioTarjeta));
});
```

- [ ] **Step 2: Run** `flutter test test/ui/` — Expected: FAIL (constantes y formas nuevas no existen).

- [ ] **Step 3: Implementar**

`tema_app.dart` (dentro de `_tema`):
- Constantes públicas de nivel superior: `radioTarjeta = 18.0`, `radioTarjetaPrincipal = 24.0`,
  `radioCampo = 14.0`, `radioHoja = 28.0`.
- `filledButtonTheme` y `outlinedButtonTheme`: `shape: const StadiumBorder()` (alto mínimo 52).
- `elevatedButtonTheme` (teclas): radio `radioCampo`.
- `cardTheme`: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta))`
  sin `side`.
- `inputDecorationTheme`: bordes con radio `radioCampo`.
- `bottomSheetTheme`: arriba `radioHoja`; `dialogTheme`: `radioHoja`.
- `snackBarTheme.shape: const StadiumBorder()`; `floatingActionButtonTheme.shape`: radio
  `radioTarjeta`.
- `appBarTheme.titleTextStyle: estiloTitulo(tamano: 22, color: c.texto)`.
- `pageTransitionsTheme: const PageTransitionsTheme(builders: {
  TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder() })`.

`tarjeta_monto.dart`: radio `radioTarjeta` en `shape` e `InkWell`; el borde solo se dibuja
cuando hay `colorBorde` (`side: colorBorde == null || fondo != null ? BorderSide.none :
BorderSide(color: colorBorde!, width: 1.5)`). Quitar el default gris y actualizar el comentario.

`resumen_screen.dart` (`_Tarjetas`): la tarjeta `tarjeta_ventas` usa
`BorderRadius.circular(radioTarjetaPrincipal)` y `Monto(..., tamano: 36, ...)`.

`avisos.dart`: pasar `snackBarAnimationStyle: const AnimationStyle(duration: Movimiento.larga)`
a `showSnackBar` (la vibración llega en la Task 5).

- [ ] **Step 4: Run** `flutter test` completo y `flutter analyze` — Expected: verde / sin problemas. Si un test de pantalla dependía del borde gris de `TarjetaMonto`, ajustarlo a que no haya borde.

- [ ] **Step 5: Commit**

```bash
git add lib/ui lib/screens/home/resumen_screen.dart test/ui
git commit -m "Apply Expressive shapes, bigger titles and fade-forward transitions"
```

---

### Task 5: Botón que se aplasta y vibración en componentes

**Files:**
- Modify: `lib/ui/boton_principal.dart`, `lib/ui/teclado_monto.dart`, `lib/ui/mosaico.dart`,
  `lib/ui/avisos.dart`, `lib/widgets/teclado_numerico.dart`,
  `lib/screens/home/home_screen.dart` (`onDestinationSelected`),
  `lib/screens/login/ingresar_pin_screen.dart` (PIN incorrecto)
- Test: `test/ui/componentes_test.dart`, `test/ui/teclado_monto_test.dart`,
  `test/screens/login/` (archivo de pruebas de `ingresar_pin_screen` existente)

**Interfaces:**
- Consumes: `Movimiento.resorte`, `Movimiento.corta`, `Movimiento.media`,
  `Movimiento.duracion` (Task 3); `Vibracion.*` (Task 3); `registrarVibraciones` (Task 3).
- Produces: `class Aplastable extends StatefulWidget { const Aplastable({required Widget child,
  required bool habilitado}); }` en `lib/ui/boton_principal.dart` (privado `_Aplastable` si
  nadie más lo usa).

- [ ] **Step 1: Tests (fallan)**

En `test/ui/componentes_test.dart`:

```dart
testWidgets('BotonPrincipal vibra al tocarlo y se encoge mientras se presiona',
    (tester) async {
  final registro = registrarVibraciones(tester);
  await tester.pumpWidget(_app(BotonPrincipal(texto: 'Cobrar', onPressed: () {})));
  double escala() => tester
      .widget<AnimatedScale>(find.descendant(
          of: find.byType(BotonPrincipal), matching: find.byType(AnimatedScale)))
      .scale;
  expect(escala(), 1.0);

  final gesto = await tester.startGesture(tester.getCenter(find.text('Cobrar')));
  await tester.pump();
  expect(escala(), 0.94);
  await gesto.up();
  await tester.pumpAndSettle();
  expect(escala(), 1.0);
  expect(registro, ['HapticFeedbackType.selectionClick']);
});

testWidgets('BotonPrincipal deshabilitado no vibra ni se encoge', (tester) async {
  final registro = registrarVibraciones(tester);
  await tester.pumpWidget(_app(const BotonPrincipal(texto: 'Cobrar', onPressed: null)));
  await tester.tap(find.text('Cobrar'), warnIfMissed: false);
  await tester.pumpAndSettle();
  expect(registro, isEmpty);
});

testWidgets('avisar vibra como éxito', (tester) async {
  final registro = registrarVibraciones(tester);
  await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
          onPressed: () => avisar(context, 'Venta registrada'),
          child: const Text('ir')))));
  await tester.tap(find.text('ir'));
  await tester.pumpAndSettle();
  expect(registro, contains('HapticFeedbackType.mediumImpact'));
});
```

En `test/ui/teclado_monto_test.dart`: tocar `tecla_monto_5` registra
`'HapticFeedbackType.selectionClick'`. En el test de `Mosaico` (en `componentes_test.dart` o
donde exista): tocar un mosaico registra `selectionClick`. En el archivo de pruebas de
`ingresar_pin_screen`: tocar una tecla registra `selectionClick` y un PIN incorrecto registra
`'HapticFeedbackType.heavyImpact'`.

- [ ] **Step 2: Run** `flutter test test/ui test/screens/login` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`boton_principal.dart`:

```dart
/// Se encoge al presionar y vuelve con rebote (Material 3 Expressive).
class _Aplastable extends StatefulWidget {
  const _Aplastable({required this.child, required this.habilitado});
  final Widget child;
  final bool habilitado;
  @override
  State<_Aplastable> createState() => _AplastableState();
}

class _AplastableState extends State<_Aplastable> {
  var _presionado = false;

  void _cambiar(bool valor) {
    if (widget.habilitado && _presionado != valor) {
      setState(() => _presionado = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _cambiar(true),
      onPointerUp: (_) => _cambiar(false),
      onPointerCancel: (_) => _cambiar(false),
      child: AnimatedScale(
        scale: _presionado ? 0.94 : 1.0,
        duration: Movimiento.duracion(
            context, _presionado ? Movimiento.corta : Movimiento.media),
        curve: _presionado ? Curves.easeOut : Movimiento.resorte,
        child: widget.child,
      ),
    );
  }
}
```

En `BotonPrincipal.build`: envolver el `onPressed` para vibrar
(`final alTocar = onPressed == null ? null : () { Vibracion.toque(); onPressed!(); };`), usar
`alTocar` en los cuatro botones y devolver
`SizedBox(width: double.infinity, child: _Aplastable(habilitado: onPressed != null, child: boton))`.

`teclado_monto.dart`, `teclado_numerico.dart`: en cada `onPressed`, `Vibracion.toque();` antes
de la llamada actual. `mosaico.dart`: en el `onTap` del mosaico, `Vibracion.toque();` antes de
`onTap`. `home_screen.dart`: `onDestinationSelected: (i) { Vibracion.toque(); setState(() =>
_tabActual = i); }`. `ingresar_pin_screen.dart`: donde se asigna `_error = 'PIN incorrecto'`,
llamar `Vibracion.error();`. `avisos.dart`: `Vibracion.exito();` al mostrar el aviso.

- [ ] **Step 4: Run** `flutter test` completo y `flutter analyze` — Expected: verde / sin problemas.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "Squash buttons on press and add haptic feedback to taps, toasts and PIN errors"
```

---

### Task 6: Montos animados y entrada escalonada en el Inicio

**Files:**
- Create: `lib/ui/monto_animado.dart`, `lib/ui/entrada_escalonada.dart`,
  `test/ui/monto_animado_test.dart`, `test/ui/entrada_escalonada_test.dart`
- Modify: `lib/ui/monto.dart` (parámetro `animado`), `lib/ui/tarjeta_monto.dart`,
  `lib/screens/home/resumen_screen.dart`

**Interfaces:**
- Consumes: `Movimiento` (Task 3), `Monto` y `TonoMonto` (`lib/ui/monto.dart`).
- Produces: `MontoAnimado(int valor, {double tamano = 18, TonoMonto tono = TonoMonto.neutro,
  bool tachado = false})`; `Monto(..., bool animado = false)` delega en `MontoAnimado` cuando
  `animado` es `true`; `EntradaEscalonada({required int indice, required Widget child})`.

- [ ] **Step 1: Tests (fallan)**

`test/ui/monto_animado_test.dart`:

```dart
Widget _app(Widget hijo, {bool reducir = false}) => MaterialApp(
      theme: temaClaro(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducir),
        child: Scaffold(body: hijo),
      ),
    );

void main() {
  testWidgets('la primera vez muestra el valor sin animar', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    expect(find.text(r'$5.000'), findsOneWidget);
  });

  testWidgets('al cambiar cuenta y termina en el valor nuevo', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    await tester.pumpWidget(_app(const MontoAnimado(17500)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(r'$17.500'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(r'$17.500'), findsOneWidget);
  });

  testWidgets('dos cambios seguidos terminan en el último', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    await tester.pumpWidget(_app(const MontoAnimado(10000)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(_app(const MontoAnimado(30000)));
    await tester.pumpAndSettle();
    expect(find.text(r'$30.000'), findsOneWidget);
  });

  testWidgets('con reducir movimiento muestra el valor nuevo de inmediato',
      (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000), reducir: true));
    await tester.pumpWidget(_app(const MontoAnimado(17500), reducir: true));
    await tester.pump();
    expect(find.text(r'$17.500'), findsOneWidget);
  });
}
```

`test/ui/entrada_escalonada_test.dart`:

```dart
testWidgets('aparece una sola vez aunque se reconstruya', (tester) async {
  Widget arbol(String texto) => MaterialApp(
      home: EntradaEscalonada(indice: 0, child: Text(texto)));
  await tester.pumpWidget(arbol('a'));
  double opacidad() => tester
      .widget<Opacity>(find.ancestor(of: find.text('a'), matching: find.byType(Opacity)).first)
      .opacity;
  expect(opacidad(), lessThan(1));
  await tester.pumpAndSettle();
  expect(find.text('a'), findsOneWidget);

  await tester.pumpWidget(arbol('a')); // reconstrucción por dato nuevo
  await tester.pump();
  expect(find.byType(Opacity), findsNothing); // ya no se anima de nuevo
});

testWidgets('con reducir movimiento se ve completo desde el inicio', (tester) async {
  await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: EntradaEscalonada(indice: 3, child: Text('b')))));
  expect(find.byType(Opacity), findsNothing);
  expect(find.text('b'), findsOneWidget);
});
```

- [ ] **Step 2: Run** `flutter test test/ui/monto_animado_test.dart test/ui/entrada_escalonada_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`lib/ui/monto_animado.dart`:

```dart
import 'package:flutter/material.dart';

import 'monto.dart';
import 'movimiento.dart';

/// [Monto] que, cuando cambia el valor, cuenta desde el anterior hasta el
/// nuevo. La primera vez (y con "quitar animaciones") muestra el valor directo.
class MontoAnimado extends StatefulWidget {
  const MontoAnimado(this.valor,
      {super.key, this.tamano = 18, this.tono = TonoMonto.neutro, this.tachado = false});

  final int valor;
  final double tamano;
  final TonoMonto tono;
  final bool tachado;

  @override
  State<MontoAnimado> createState() => _MontoAnimadoState();
}

class _MontoAnimadoState extends State<MontoAnimado>
    with SingleTickerProviderStateMixin {
  late final _control = AnimationController(vsync: this);
  late int _desde = widget.valor;
  late int _hasta = widget.valor;

  int get _actual {
    final t = Curves.easeOutCubic.transform(_control.value);
    return (_desde + (_hasta - _desde) * t).round();
  }

  @override
  void didUpdateWidget(MontoAnimado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.valor == _hasta) return;
    _desde = _control.isAnimating ? _actual : _hasta;
    _hasta = widget.valor;
    _control.duration = Movimiento.duracion(context, Movimiento.conteo);
    _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      builder: (context, _) => Monto(
        _control.isAnimating ? _actual : _hasta,
        tamano: widget.tamano,
        tono: widget.tono,
        tachado: widget.tachado,
      ),
    );
  }
}
```

Nota: con duración cero `forward` termina en el mismo cuadro y se muestra `_hasta`.

`lib/ui/monto.dart`: agregar `final bool animado;` (default `false`); al inicio de `build`:
`if (animado) return MontoAnimado(valor, tamano: tamano, tono: tono, tachado: tachado);`
(evitar recursión: `MontoAnimado` construye `Monto` con `animado: false`).

`lib/ui/tarjeta_monto.dart`: `Monto(valor, tamano: tamano, tono: tono, animado: true)`.

`lib/ui/entrada_escalonada.dart`:

```dart
import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Hace que un elemento de una lista suba y aparezca con rebote la primera
/// vez que se construye; [indice] (hasta 8) escalona la entrada 60 ms.
class EntradaEscalonada extends StatefulWidget {
  const EntradaEscalonada({super.key, required this.indice, required this.child});
  final int indice;
  final Widget child;
  @override
  State<EntradaEscalonada> createState() => _EntradaEscalonadaState();
}

class _EntradaEscalonadaState extends State<EntradaEscalonada>
    with SingleTickerProviderStateMixin {
  AnimationController? _control;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control != null || Movimiento.reducido(context)) return;
    final retraso = Duration(milliseconds: 60 * widget.indice.clamp(0, 8));
    _control = AnimationController(
        vsync: this, duration: retraso + Movimiento.larga)
      ..forward();
  }

  @override
  void dispose() {
    _control?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = _control;
    if (control == null) return widget.child;
    final total = control.duration!.inMilliseconds;
    final inicio = (60 * widget.indice.clamp(0, 8)) / total;
    final curva = CurvedAnimation(
        parent: control, curve: Interval(inicio, 1, curve: Movimiento.resorte));
    return AnimatedBuilder(
      animation: curva,
      child: widget.child,
      builder: (context, hijo) {
        if (control.isCompleted) return hijo!;
        final v = curva.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: hijo),
        );
      },
    );
  }
}
```

`resumen_screen.dart` (`_Tarjetas`): envolver la tarjeta de ventas, la fila de
gastos/ganancia y la de por cobrar en `EntradaEscalonada(indice: 0/1/2, child: …)`; el monto de
ventas usa `Monto(..., tamano: 36, tono: TonoMonto.claro, animado: true)`.

- [ ] **Step 4: Run** `flutter test` completo — Expected: verde. Si algún test de pantalla
busca un monto justo después de un `pump()` sin `pumpAndSettle()`, cambiarlo a
`pumpAndSettle()` (el conteo dura 700 ms).

- [ ] **Step 5: `flutter analyze`** — Expected: sin problemas.

- [ ] **Step 6: Commit**

```bash
git add lib/ui lib/screens/home/resumen_screen.dart test/ui
git commit -m "Count amounts up when they change and stagger the home cards in"
```

---

### Task 7: Pantallas en modo oscuro, cierre y APK

**Files:**
- Create: `test/screens/modo_oscuro_test.dart`
- Modify: `docs/hoja-de-ruta.md`, `docs/superpowers/specs/2026-10-09-vecitienda-renovacion-r1-design.md`
  (Estado)

**Interfaces — Consumes:** `appDePrueba(container, tema:, inicio:)` (Task 1),
`containerConSesion`, `temaOscuro()`.

- [ ] **Step 1: Test de humo en oscuro**

`test/screens/modo_oscuro_test.dart` monta, con `tema: temaOscuro()`, vista de 800×1600 dp
(`tester.view.physicalSize = const Size(800, 1600); tester.view.devicePixelRatio = 1;`), una
por una: `HomeScreen` (y toca cada pestaña: Inicio, Fiado, Inventario, Historial, Ajustes),
`RegistrarVentaScreen`, `IngresarPinScreen` (con un usuario creado; usar el constructor real) y
`ReportesScreen`. Para cada una: `await tester.pumpAndSettle(); expect(tester.takeException(),
isNull);` y que `Theme.of(contexto).brightness == Brightness.dark`.

Agregar el caso de letra grande:

```dart
testWidgets('Inicio en oscuro con letra grande no desborda', (tester) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // montar HomeScreen con tema oscuro dentro de
  // MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.6)), ...)
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run** `flutter test test/screens/modo_oscuro_test.dart` — Expected: PASS (si
falla, corregir la pantalla: suele ser un color que quedó fijo o un `const` olvidado).

- [ ] **Step 3: Verificación completa**

Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: todas en verde.
Run: `flutter build apk --release` — Expected: `Built build\app\outputs\flutter-apk\app-release.apk`.

- [ ] **Step 4: Documentación**

`docs/hoja-de-ruta.md`: en "Hecho" agregar
`- Renovación R1 — modo oscuro "Azul noche", estilo Expressive (formas, movimiento, vibración).`;
"En curso": `- Renovación de la interfaz: R2 (pantallas de demo), R3 (dinero), R4 (administración).`;
"Pendiente de verificar": agregar `renovación R1 en claro y oscuro (incluida vibración)`.
En la especificación: `**Estado:** Implementado (falta el recorrido manual en un celular real)`.

- [ ] **Step 5: Commit**

```bash
git add test/screens/modo_oscuro_test.dart docs
git commit -m "Check main screens in dark mode and mark renewal R1 as implemented"
```
