# App de ventas Fase 2E — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar la experiencia y el aspecto de toda la app (sistema visual "B · Claro y confiable", flujo de venta tipo ticket con Deshacer, confirmaciones, estados vacíos, jerarquía de montos).

**Architecture:** Un tema central (`lib/ui/tema_app.dart`) y componentes reutilizables en `lib/ui/` que todas las pantallas usan. El ticket de venta vive en un `Notifier` autoDispose (`lib/providers/ticket_provider.dart`) probado aparte. Cambios de datos mínimos (eliminar venta para Deshacer, conteos del resumen, buscar-o-crear cliente); sin cambios de esquema.

**Tech Stack:** Flutter 3.47 (Dart ^3.13), flutter_riverpod ^2.6.1, drift ^2.34, fuente Inter empaquetada (OFL).

**Spec:** `docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md`

## Global Constraints

- Colores (solo modo claro), en `ColoresApp`: `primario #1E3A8A`, `entra #15803D`, `sale #DC2626`, `fiado #B45309`, `fiadoSuave #FEF3C7`, `fondo #F7F9FC`, `superficie #FFFFFF`, `borde #E5E7EB`, `texto #0F172A`, `textoSecundario #64748B`. Ningún componente usa hex sueltos: siempre `ColoresApp`.
- Todo par texto/fondo usado cumple contraste ≥ 4.5:1.
- Tipografía Inter (400/600/700/800) empaquetada en `assets/fonts/`; montos con `FontFeature.tabularFigures()` y peso 800; cuerpo mínimo 16.
- Radio 12 (tarjetas, botones, campos), 16 en la tarjeta principal del Inicio, 20 arriba en paneles inferiores. Áreas de toque ≥ 48 dp. Íconos Material `*_rounded`/`*_outlined`; nada de emojis como íconos.
- Toda acción que guarda algo confirma con `avisar(...)`. Formularios de alta en panel inferior. Toda lista vacía usa `EstadoVacio`.
- Textos: "Ajustes" (no "Config"), "Administrador"/"Vendedor", "Debe desde hace N días" ("Debe desde hoy"/"Debe desde ayer").
- Cada cobro = **una** venta con el total; `productoId` solo si el ticket tiene una única línea y es de producto. "Deshacer" (5 s) elimina esa venta.
- Sin cambios de esquema Drift. Única dependencia nueva: ninguna (Inter va como asset).
- `SnackBar` con acción: pasar `persist: false` (en Flutter 3.47 un SnackBar con acción persiste por defecto).
- Tests con Drift en memoria, sin mocks salvo repositorios "lentos" para probar doble toque. Ejecutar con `flutter test`.
- Commits en inglés imperativo, terminando con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Ajustes al spec decididos al escribir este plan

1. `entra` pasa de `#16A34A` a **`#15803D`**: con `#16A34A` el texto blanco del botón "Cobrar" da 3.1:1 y el verde sobre blanco también, violando la regla de contraste ≥ 4.5:1 del propio spec. `#15803D` da 5.0:1.
2. Totales del Historial: **"Ventas" / "Gastos"** en lugar de "Entró / Salió" (las ventas fiadas no son dinero que entró).

Ambos se reflejan en el spec en la Task 1.

## Review Focus

1. **Deshacer**: tocar "Deshacer" elimina exactamente esa venta y nada más; si el aviso se va, la venta queda. → Task 6.
2. **Cliente existente escrito con otra capitalización** ("don pedro " vs "Don Pedro") al fiar: no debe crear un cliente duplicado. → Tasks 4 y 6.
3. **Salir de "Nueva venta" sin cobrar**: el ticket se descarta; al volver a entrar empieza vacío. → Tasks 5 y 6.
4. **Montos grandes en un celular pequeño** (360×780 dp, $123.456.789): sin desbordes. → Tasks 2 y 8.
5. **Doble toque al confirmar un abono** desde el panel nuevo: un solo abono. → Task 10.

---

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `assets/fonts/Inter-*.ttf`, `assets/fonts/LICENSE.txt` | Crear | Fuente empaquetada |
| `pubspec.yaml` | Modificar | Declarar la fuente |
| `lib/ui/colores_app.dart` | Crear | Tokens de color |
| `lib/ui/tema_app.dart` | Crear | `ThemeData` central |
| `lib/main.dart` | Modificar | Usar `temaApp()` |
| `lib/ui/monto.dart` | Crear | `Monto`, `TonoMonto` |
| `lib/ui/tarjeta_monto.dart` | Crear | `TarjetaMonto` |
| `lib/ui/boton_principal.dart` | Crear | `BotonPrincipal`, `VarianteBoton` |
| `lib/ui/selector_segmentado.dart` | Crear | `SelectorSegmentado<T>` |
| `lib/ui/estado_vacio.dart` | Crear | `EstadoVacio` |
| `lib/ui/avisos.dart` | Crear | `avisar(...)` |
| `lib/ui/hoja_inferior.dart` | Crear | `mostrarHojaInferior<T>(...)` |
| `lib/ui/avatar_inicial.dart` | Crear | `AvatarInicial`, `etiquetaRol` |
| `lib/ui/marca_app.dart` | Crear | `MarcaApp` (ícono + "App Ventas") |
| `lib/ui/teclado_monto.dart` | Crear | `TecladoMonto`, `aplicarTecla` |
| `lib/ui/mosaico.dart` | Crear | `Mosaico` (tile de producto/monto) |
| `lib/util/texto_util.dart` | Crear | `plural(...)` |
| `lib/util/fecha_util.dart` | Modificar | `textoDebeDesde(...)` |
| `lib/repositories/venta_repository.dart` | Modificar | `eliminarVenta` |
| `lib/repositories/cliente_repository.dart` | Modificar | `obtenerOCrearCliente` |
| `lib/repositories/fiado_repository.dart` | Modificar | `clientesConDeudaAl` |
| `lib/repositories/resumen_repository.dart` | Modificar | Conteos en `ResumenDia` |
| `lib/providers/ticket_provider.dart` | Crear | `Ticket`, `LineaTicket`, `ClienteTicket`, `ticketProvider` |
| `lib/widgets/monto_rapido_grid.dart` | Reescribir | Grilla de montos con `Mosaico` |
| `lib/widgets/teclado_numerico.dart` | Reescribir | Teclado de PIN con estilo nuevo |
| `lib/screens/venta/registrar_venta_screen.dart` | Reescribir | Ticket |
| `lib/screens/home/home_screen.dart` | Reescribir | `NavigationBar`, encabezado, menú de cuenta |
| `lib/screens/configuracion/ajustes_screen.dart` | Crear | Ajustes |
| `lib/screens/home/resumen_screen.dart` | Reescribir | Inicio |
| `lib/screens/gasto/registrar_gasto_screen.dart` | Reescribir | Nuevo gasto |
| `lib/screens/fiado/lista_fiado_screen.dart` | Reescribir | Lista de fiado |
| `lib/screens/fiado/detalle_cliente_screen.dart` | Reescribir | Detalle + panel de abono |
| `lib/screens/historial/historial_screen.dart` | Reescribir | Historial |
| `lib/screens/configuracion/productos_screen.dart` | Reescribir | Lista + panel "Agregar" |
| `lib/screens/configuracion/usuarios_screen.dart` | Reescribir | Lista + panel "Agregar" |
| `lib/screens/login/*.dart` | Reescribir | Entrada |
| `test/support/montaje.dart` | Crear | Helpers de prueba (sesión + app con tema) |

---

### Task 1: Fuente, colores y tema central

**Files:**
- Create: `assets/fonts/Inter-Regular.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`, `Inter-ExtraBold.ttf`, `LICENSE.txt`
- Modify: `pubspec.yaml` (sección `flutter:`), `lib/main.dart`
- Create: `lib/ui/colores_app.dart`, `lib/ui/tema_app.dart`
- Modify: `docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md` (ajustes 1 y 2)
- Test: `test/ui/tema_app_test.dart`

**Interfaces:**
- Produces: `abstract final class ColoresApp` con las constantes de Global Constraints; `ThemeData temaApp()`.

- [ ] **Step 1: Descargar Inter**

```bash
mkdir -p assets/fonts
curl -L -o "$TEMP/inter.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
unzip -l "$TEMP/inter.zip" | grep -E "Inter-(Regular|SemiBold|Bold|ExtraBold)\.ttf|LICENSE"
unzip -j -o "$TEMP/inter.zip" "extras/ttf/Inter-Regular.ttf" "extras/ttf/Inter-SemiBold.ttf" "extras/ttf/Inter-Bold.ttf" "extras/ttf/Inter-ExtraBold.ttf" "LICENSE.txt" -d assets/fonts
ls assets/fonts
```

Expected: los 4 `.ttf` y `LICENSE.txt` en `assets/fonts`. Si la ruta dentro del zip difiere, usar la que muestra `unzip -l` (los TTF estáticos están bajo `extras/ttf/`).

- [ ] **Step 2: Escribir el test que falla**

Crear `test/ui/tema_app_test.dart`:

```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('los pares de texto y fondo cumplen contraste 4.5:1', () {
    const pares = <String, (Color, Color)>{
      'texto/fondo': (ColoresApp.texto, ColoresApp.fondo),
      'secundario/fondo': (ColoresApp.textoSecundario, ColoresApp.fondo),
      'secundario/superficie': (ColoresApp.textoSecundario, ColoresApp.superficie),
      'primario/superficie': (ColoresApp.primario, ColoresApp.superficie),
      'blanco/primario': (Colors.white, ColoresApp.primario),
      'entra/superficie': (ColoresApp.entra, ColoresApp.superficie),
      'blanco/entra': (Colors.white, ColoresApp.entra),
      'sale/superficie': (ColoresApp.sale, ColoresApp.superficie),
      'blanco/sale': (Colors.white, ColoresApp.sale),
      'fiado/superficie': (ColoresApp.fiado, ColoresApp.superficie),
      'fiado/fiadoSuave': (ColoresApp.fiado, ColoresApp.fiadoSuave),
    };
    pares.forEach((nombre, par) {
      expect(contraste(par.$1, par.$2), greaterThanOrEqualTo(4.5),
          reason: nombre);
    });
  });

  test('el tema usa el color primario, el fondo y la fuente Inter', () {
    final tema = temaApp();
    expect(tema.colorScheme.primary, ColoresApp.primario);
    expect(tema.scaffoldBackgroundColor, ColoresApp.fondo);
    expect(tema.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('la fuente Inter está empaquetada y declarada', () {
    for (final archivo in [
      'Inter-Regular.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'Inter-ExtraBold.ttf',
    ]) {
      expect(File('assets/fonts/$archivo').existsSync(), isTrue,
          reason: archivo);
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('family: Inter'));
  });
}
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `flutter test test/ui/tema_app_test.dart`
Expected: FAIL — `colores_app.dart` / `tema_app.dart` no existen.

- [ ] **Step 4: Implementar**

Crear `lib/ui/colores_app.dart`:

```dart
import 'package:flutter/material.dart';

/// Tokens de color de la app (estilo "claro y confiable", solo modo claro).
/// Los componentes usan siempre estas constantes, nunca hex sueltos.
abstract final class ColoresApp {
  static const primario = Color(0xFF1E3A8A);

  /// Dinero que entra: ventas, ganancia, botón Cobrar, abonos.
  static const entra = Color(0xFF15803D);

  /// Dinero que sale, errores y acciones destructivas.
  static const sale = Color(0xFFDC2626);

  /// Fiado y por cobrar.
  static const fiado = Color(0xFFB45309);
  static const fiadoSuave = Color(0xFFFEF3C7);

  static const fondo = Color(0xFFF7F9FC);
  static const superficie = Color(0xFFFFFFFF);
  static const borde = Color(0xFFE5E7EB);
  static const texto = Color(0xFF0F172A);
  static const textoSecundario = Color(0xFF64748B);
}
```

Crear `lib/ui/tema_app.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

const _fuente = 'Inter';

/// Tema central de la app; todas las pantallas lo heredan de MaterialApp.
ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresApp.primario,
    primary: ColoresApp.primario,
    onPrimary: Colors.white,
    secondary: ColoresApp.entra,
    onSecondary: Colors.white,
    error: ColoresApp.sale,
    onError: Colors.white,
    surface: ColoresApp.superficie,
    onSurface: ColoresApp.texto,
    onSurfaceVariant: ColoresApp.textoSecundario,
    outline: ColoresApp.borde,
    outlineVariant: ColoresApp.borde,
  );
  final redondeado =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const textoBoton = TextStyle(
      fontFamily: _fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: ColoresApp.borde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: _fuente,
    scaffoldBackgroundColor: ColoresApp.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresApp.superficie,
      foregroundColor: ColoresApp.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _fuente,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ColoresApp.texto,
      ),
      shape: Border(bottom: BorderSide(color: ColoresApp.borde)),
    ),
    cardTheme: CardThemeData(
      color: ColoresApp.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColoresApp.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeado,
        textStyle: textoBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeado,
        textStyle: textoBoton,
        side: const BorderSide(color: ColoresApp.borde),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: redondeado,
        elevation: 0,
        backgroundColor: ColoresApp.superficie,
        foregroundColor: ColoresApp.primario,
        side: const BorderSide(color: ColoresApp.borde),
        textStyle: textoBoton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
            fontFamily: _fuente, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.superficie,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: ColoresApp.primario, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ColoresApp.superficie,
      indicatorColor: Color(0xFFDBE4FF),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
            fontFamily: _fuente, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ColoresApp.texto,
      contentTextStyle: const TextStyle(
          fontFamily: _fuente, fontSize: 15, color: Colors.white),
      actionTextColor: const Color(0xFF93C5FD),
      shape: redondeado,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresApp.superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresApp.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColoresApp.primario,
      foregroundColor: Colors.white,
      shape: redondeado,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ColoresApp.textoSecundario,
      minVerticalPadding: 12,
    ),
    dividerTheme: const DividerThemeData(color: ColoresApp.borde, space: 1),
  );
}
```

En `pubspec.yaml`, bajo `flutter:`, reemplazar la línea `  uses-material-design: true` por:

```yaml
  uses-material-design: true

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-ExtraBold.ttf
          weight: 800
```

En `lib/main.dart`, agregar `import 'ui/tema_app.dart';` y reemplazar
`theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),` por `theme: temaApp(),`.

En el spec `docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md`:
- en la tabla de colores, cambiar `` `#16A34A` `` por `` `#15803D` `` en la fila `entra`;
- en "Historial", cambiar `"Entró $X" (`entra`) · "Salió $Y" (`sale`)` por `"Ventas $X" (`entra`) · "Gastos $Y" (`sale`)`.

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter pub get && flutter test test/ui/tema_app_test.dart && flutter test`
Expected: PASS (3 tests nuevos; la suite completa sigue en verde).

- [ ] **Step 6: Commit**

```bash
git add assets/fonts pubspec.yaml lib/ui lib/main.dart test/ui docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md
git commit -m "Add Inter font, color tokens, and central app theme"
```

---

### Task 2: Componentes base de UI

**Files:**
- Create: `lib/ui/monto.dart`, `lib/ui/tarjeta_monto.dart`, `lib/ui/boton_principal.dart`, `lib/ui/selector_segmentado.dart`, `lib/ui/estado_vacio.dart`, `lib/ui/avisos.dart`, `lib/ui/hoja_inferior.dart`, `lib/ui/avatar_inicial.dart`, `lib/ui/marca_app.dart`
- Create: `test/support/montaje.dart`
- Test: `test/ui/componentes_test.dart`

**Interfaces:**
- Consumes: `ColoresApp`, `temaApp()` (Task 1); `formatoMoneda` (existente).
- Produces:
  - `enum TonoMonto { neutro, entra, sale, fiado, claro }`; `Monto(int valor, {double tamano = 18, TonoMonto tono = TonoMonto.neutro})` — `Text(formatoMoneda(valor))` dentro de `FittedBox(scaleDown)`.
  - `TarjetaMonto({required String etiqueta, required int valor, TonoMonto tono, String? detalle, VoidCallback? onTap, Color? fondo, double tamano = 18})`
  - `enum VarianteBoton { primario, entra, contorno, peligro }`; `BotonPrincipal({required String texto, required VoidCallback? onPressed, VarianteBoton variante = VarianteBoton.primario, IconData? icono})`
  - `SelectorSegmentado<T>({required Map<T, String> opciones, required T valor, required ValueChanged<T> onCambio})`
  - `EstadoVacio({required IconData icono, required String titulo, String? mensaje, Widget? accion})`
  - `void avisar(BuildContext context, String texto, {VoidCallback? onDeshacer})`
  - `Future<T?> mostrarHojaInferior<T>(BuildContext context, {required String titulo, required WidgetBuilder builder})`
  - `AvatarInicial({required int id, required String nombre, double radio = 20})`; `String etiquetaRol(String rol)`
  - `MarcaApp()`
  - Test helpers: `Future<ProviderContainer> containerConSesion(AppDatabase db, {String nombre = 'Ana', String rol = 'admin'})`; `Widget appDePrueba(ProviderContainer container, {GlobalKey<NavigatorState>? navegador, Widget inicio = const Scaffold(body: Text('Inicio'))})`

- [ ] **Step 1: Crear los helpers de prueba**

Crear `test/support/montaje.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crea un usuario en [db] y devuelve un ProviderContainer con esa base y la
/// sesión de ese usuario activa. Quien llama debe hacer `container.dispose`.
Future<ProviderContainer> containerConSesion(
  AppDatabase db, {
  String nombre = 'Ana',
  String rol = 'admin',
}) async {
  final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: nombre, rol: rol, pinHash: 'x'),
      );
  final usuario =
      await (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  container.read(sesionProvider.notifier).state =
      SesionState(usuarioActivo: usuario);
  return container;
}

/// App de prueba con el tema real. [inicio] es la pantalla de fondo, para
/// poder empujar pantallas encima con [navegador] y ver los avisos al volver.
Widget appDePrueba(
  ProviderContainer container, {
  GlobalKey<NavigatorState>? navegador,
  Widget inicio = const Scaffold(body: Text('Inicio')),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: temaApp(), navigatorKey: navegador, home: inicio),
  );
}
```

- [ ] **Step 2: Escribir los tests que fallan**

Crear `test/ui/componentes_test.dart`:

```dart
import 'package:app_ventas/ui/avatar_inicial.dart';
import 'package:app_ventas/ui/avisos.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/estado_vacio.dart';
import 'package:app_ventas/ui/hoja_inferior.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/ui/selector_segmentado.dart';
import 'package:app_ventas/ui/tarjeta_monto.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) =>
    MaterialApp(theme: temaApp(), home: Scaffold(body: hijo));

void main() {
  testWidgets('Monto muestra el formato y el color de su tono', (tester) async {
    await tester.pumpWidget(_app(const Monto(5000, tono: TonoMonto.sale)));

    final texto = tester.widget<Text>(find.text(r'$5.000'));
    expect(texto.style!.color, ColoresApp.sale);
  });

  testWidgets('Monto grande no desborda en un espacio angosto', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 120,
      child: Monto(123456789, tamano: 32),
    )));

    expect(tester.takeException(), isNull);
    expect(find.text(r'$123.456.789'), findsOneWidget);
  });

  testWidgets('TarjetaMonto muestra etiqueta, monto y responde al toque',
      (tester) async {
    var tocada = false;
    await tester.pumpWidget(_app(TarjetaMonto(
      etiqueta: 'Gastos',
      valor: 1000,
      detalle: '2 gastos',
      onTap: () => tocada = true,
    )));

    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'$1.000'), findsOneWidget);
    expect(find.text('2 gastos'), findsOneWidget);
    await tester.tap(find.text('Gastos'));
    expect(tocada, isTrue);
  });

  testWidgets('BotonPrincipal sin onPressed queda deshabilitado',
      (tester) async {
    await tester.pumpWidget(
        _app(const BotonPrincipal(texto: 'Cobrar', onPressed: null)));

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('BotonPrincipal contorno usa OutlinedButton y llama onPressed',
      (tester) async {
    var llamado = false;
    await tester.pumpWidget(_app(BotonPrincipal(
      texto: '− Gasto',
      variante: VarianteBoton.peligro,
      onPressed: () => llamado = true,
    )));

    await tester.tap(find.byType(OutlinedButton));
    expect(llamado, isTrue);
  });

  testWidgets('SelectorSegmentado avisa la opción elegida', (tester) async {
    bool? elegido;
    await tester.pumpWidget(_app(SelectorSegmentado<bool>(
      opciones: const {false: 'Contado', true: 'Fiado'},
      valor: false,
      onCambio: (v) => elegido = v,
    )));

    await tester.tap(find.text('Fiado'));
    expect(elegido, isTrue);
  });

  testWidgets('EstadoVacio muestra título y mensaje', (tester) async {
    await tester.pumpWidget(_app(const EstadoVacio(
      icono: Icons.inbox_rounded,
      titulo: 'Nadie te debe',
      mensaje: 'Las ventas fiadas aparecerán aquí',
    )));

    expect(find.text('Nadie te debe'), findsOneWidget);
    expect(find.text('Las ventas fiadas aparecerán aquí'), findsOneWidget);
  });

  testWidgets('avisar muestra el texto y Deshacer llama su acción',
      (tester) async {
    var deshecho = false;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => avisar(context, 'Venta registrada',
            onDeshacer: () => deshecho = true),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Venta registrada'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    expect(deshecho, isTrue);
  });

  testWidgets('el aviso con Deshacer se cierra solo a los 5 segundos',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            avisar(context, 'Venta registrada', onDeshacer: () {}),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Venta registrada'), findsNothing);
  });

  testWidgets('mostrarHojaInferior muestra el título y el contenido',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => mostrarHojaInferior<void>(context,
            titulo: 'Nuevo producto', builder: (_) => const Text('form')),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('AvatarInicial muestra la inicial en mayúscula', (tester) async {
    await tester
        .pumpWidget(_app(const AvatarInicial(id: 3, nombre: ' ana ')));
    expect(find.text('A'), findsOneWidget);
  });

  test('etiquetaRol traduce los roles', () {
    expect(etiquetaRol('admin'), 'Administrador');
    expect(etiquetaRol('vendedor'), 'Vendedor');
  });
}
```

- [ ] **Step 3: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/componentes_test.dart`
Expected: FAIL — los archivos de `lib/ui/` no existen.

- [ ] **Step 4: Implementar los componentes**

Crear `lib/ui/monto.dart`:

```dart
import 'package:flutter/material.dart';

import '../util/formato_moneda.dart';
import 'colores_app.dart';

/// Qué representa una cifra, para darle su color.
enum TonoMonto { neutro, entra, sale, fiado, claro }

/// Una cifra de dinero: dígitos alineados, negrita, color según su tono.
/// Se encoge (nunca desborda) si no cabe.
class Monto extends StatelessWidget {
  const Monto(
    this.valor, {
    super.key,
    this.tamano = 18,
    this.tono = TonoMonto.neutro,
  });

  final int valor;
  final double tamano;
  final TonoMonto tono;

  static Color colorDe(TonoMonto tono) => switch (tono) {
        TonoMonto.neutro => ColoresApp.texto,
        TonoMonto.entra => ColoresApp.entra,
        TonoMonto.sale => ColoresApp.sale,
        TonoMonto.fiado => ColoresApp.fiado,
        TonoMonto.claro => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        formatoMoneda(valor),
        maxLines: 1,
        style: TextStyle(
          fontSize: tamano,
          fontWeight: FontWeight.w800,
          color: colorDe(tono),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
```

Crear `lib/ui/tarjeta_monto.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'monto.dart';

/// Tarjeta con una etiqueta, una cifra y un detalle opcional.
class TarjetaMonto extends StatelessWidget {
  const TarjetaMonto({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.tono = TonoMonto.neutro,
    this.detalle,
    this.onTap,
    this.fondo,
    this.tamano = 18,
  });

  final String etiqueta;
  final int valor;
  final TonoMonto tono;
  final String? detalle;
  final VoidCallback? onTap;
  final Color? fondo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colorEtiqueta = tono == TonoMonto.claro
        ? Colors.white70
        : ColoresApp.textoSecundario;
    return Material(
      color: fondo ?? ColoresApp.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: fondo == null
            ? const BorderSide(color: ColoresApp.borde)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(etiqueta,
                        style: TextStyle(fontSize: 13, color: colorEtiqueta)),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: colorEtiqueta),
                ],
              ),
              const SizedBox(height: 4),
              Monto(valor, tamano: tamano, tono: tono),
              if (detalle != null) ...[
                const SizedBox(height: 2),
                Text(detalle!,
                    style: TextStyle(fontSize: 12, color: colorEtiqueta)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

Crear `lib/ui/boton_principal.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

enum VarianteBoton { primario, entra, contorno, peligro }

/// Botón grande de ancho completo. Con [onPressed] null queda deshabilitado.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.variante = VarianteBoton.primario,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final VarianteBoton variante;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final contenido = icono == null
        ? Text(texto, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
            ],
          );
    final boton = switch (variante) {
      VarianteBoton.primario =>
        FilledButton(onPressed: onPressed, child: contenido),
      VarianteBoton.entra => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.entra,
            foregroundColor: Colors.white,
          ),
          child: contenido,
        ),
      VarianteBoton.contorno => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.primario,
            side: const BorderSide(color: ColoresApp.primario, width: 1.5),
          ),
          child: contenido,
        ),
      VarianteBoton.peligro => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.sale,
            side: const BorderSide(color: ColoresApp.sale, width: 1.5),
          ),
          child: contenido,
        ),
    };
    return SizedBox(width: double.infinity, child: boton);
  }
}
```

Crear `lib/ui/selector_segmentado.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Selector de 2 a 4 opciones excluyentes, de ancho completo.
class SelectorSegmentado<T> extends StatelessWidget {
  const SelectorSegmentado({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onCambio,
  });

  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: [
          for (final opcion in opciones.entries)
            ButtonSegment<T>(value: opcion.key, label: Text(opcion.value)),
        ],
        selected: {valor},
        showSelectedIcon: false,
        onSelectionChanged: (seleccion) => onCambio(seleccion.first),
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 48),
          selectedBackgroundColor: ColoresApp.primario,
          selectedForegroundColor: Colors.white,
          foregroundColor: ColoresApp.texto,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
```

Crear `lib/ui/estado_vacio.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Mensaje para una lista vacía: ícono, título, explicación y acción opcional.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8EDF8),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 32, color: ColoresApp.primario),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 4),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresApp.textoSecundario),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}
```

Crear `lib/ui/avisos.dart`:

```dart
import 'package:flutter/material.dart';

/// Aviso de confirmación abajo de la pantalla. Con [onDeshacer] agrega la
/// acción "Deshacer" y dura 5 s; sin ella dura 3 s.
void avisar(BuildContext context, String texto, {VoidCallback? onDeshacer}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(texto),
      duration: Duration(seconds: onDeshacer == null ? 3 : 5),
      // En Flutter 3.47 un SnackBar con acción persiste por defecto; el
      // Deshacer debe desaparecer solo a los 5 s.
      persist: false,
      action: onDeshacer == null
          ? null
          : SnackBarAction(label: 'Deshacer', onPressed: onDeshacer),
    ),
  );
}
```

Crear `lib/ui/hoja_inferior.dart`:

```dart
import 'package:flutter/material.dart';

/// Abre un panel desde abajo con [titulo] y el contenido de [builder]. Se
/// desplaza con el teclado. Devuelve lo que el contenido pase a `pop`.
Future<T?> mostrarHojaInferior<T>(
  BuildContext context, {
  required String titulo,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.viewInsetsOf(contexto).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            builder(contexto),
          ],
        ),
      ),
    ),
  );
}
```

Crear `lib/ui/avatar_inicial.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

const _paleta = [
  ColoresApp.primario,
  Color(0xFF0F766E),
  Color(0xFF7C3AED),
  ColoresApp.fiado,
  Color(0xFFBE185D),
  ColoresApp.entra,
];

/// Círculo de color con la inicial del nombre; el color sale del id.
class AvatarInicial extends StatelessWidget {
  const AvatarInicial({
    super.key,
    required this.id,
    required this.nombre,
    this.radio = 20,
  });

  final int id;
  final String nombre;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final limpio = nombre.trim();
    return CircleAvatar(
      radius: radio,
      backgroundColor: _paleta[id % _paleta.length],
      child: Text(
        limpio.isEmpty ? '?' : limpio[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radio * 0.9,
        ),
      ),
    );
  }
}

String etiquetaRol(String rol) => rol == 'admin' ? 'Administrador' : 'Vendedor';
```

Crear `lib/ui/marca_app.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Ícono y nombre de la app, para las pantallas de entrada.
class MarcaApp extends StatelessWidget {
  const MarcaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ColoresApp.primario,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'App Ventas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ColoresApp.primario,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/ui`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui test/ui test/support/montaje.dart
git commit -m "Add reusable UI components and test helpers"
```

---

### Task 3: Teclado de montos

**Files:**
- Create: `lib/ui/teclado_monto.dart`
- Test: `test/ui/teclado_monto_test.dart`

**Interfaces:**
- Produces: `const montoMaximo = 999999999;` `int aplicarTecla(int actual, String tecla)` (teclas `'0'..'9'`, `'000'`, `'borrar'`); `TecladoMonto({required ValueChanged<String> onTecla})` con claves `tecla_monto_<tecla>`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/ui/teclado_monto_test.dart`:

```dart
import 'package:app_ventas/ui/teclado_monto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aplicarTecla agrega dígitos y ceros', () {
    expect(aplicarTecla(5, '3'), 53);
    expect(aplicarTecla(12, '000'), 12000);
    expect(aplicarTecla(0, '7'), 7);
  });

  test('aplicarTecla no deja ceros a la izquierda', () {
    expect(aplicarTecla(0, '0'), 0);
    expect(aplicarTecla(0, '000'), 0);
  });

  test('aplicarTecla borra el último dígito', () {
    expect(aplicarTecla(53, 'borrar'), 5);
    expect(aplicarTecla(5, 'borrar'), 0);
    expect(aplicarTecla(0, 'borrar'), 0);
  });

  test('aplicarTecla no pasa de 9 dígitos', () {
    expect(aplicarTecla(montoMaximo, '1'), montoMaximo);
    expect(aplicarTecla(1000000, '000'), 1000000);
  });

  testWidgets('TecladoMonto avisa cada tecla tocada', (tester) async {
    final teclas = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TecladoMonto(onTecla: teclas.add)),
    ));

    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));

    expect(teclas, ['2', '000', 'borrar']);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/teclado_monto_test.dart`
Expected: FAIL — `teclado_monto.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/ui/teclado_monto.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Tope de 9 dígitos ($999.999.999).
const montoMaximo = 999999999;

/// Aplica una tecla del [TecladoMonto] a un monto entero.
int aplicarTecla(int actual, String tecla) {
  if (tecla == 'borrar') return actual ~/ 10;
  final siguiente =
      tecla == '000' ? actual * 1000 : actual * 10 + int.parse(tecla);
  return siguiente > montoMaximo ? actual : siguiente;
}

/// Teclado numérico grande para montos: 1–9, 000, 0 y borrar.
class TecladoMonto extends StatelessWidget {
  const TecladoMonto({super.key, required this.onTecla});

  final ValueChanged<String> onTecla;

  static const _filas = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'borrar'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fila in _filas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final tecla in fila)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          key: Key('tecla_monto_$tecla'),
                          onPressed: () => onTecla(tecla),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: ColoresApp.texto,
                          ),
                          child: tecla == 'borrar'
                              ? const Icon(Icons.backspace_outlined,
                                  semanticLabel: 'Borrar')
                              : Text(tecla,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/teclado_monto_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/teclado_monto.dart test/ui/teclado_monto_test.dart
git commit -m "Add amount keypad widget"
```

---

### Task 4: Cambios de datos (Deshacer, cliente sin duplicar, conteos del resumen)

**Files:**
- Modify: `lib/repositories/venta_repository.dart`, `lib/repositories/cliente_repository.dart`, `lib/repositories/fiado_repository.dart`, `lib/repositories/resumen_repository.dart`
- Create: `lib/util/texto_util.dart`
- Modify: `lib/util/fecha_util.dart`
- Test: `test/repositories/venta_repository_test.dart`, `test/repositories/cliente_repository_test.dart`, `test/repositories/fiado_repository_test.dart`, `test/repositories/resumen_repository_test.dart`, `test/util/texto_util_test.dart`, `test/util/fecha_util_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> VentaRepository.eliminarVenta(int id)`
  - `Future<int> ClienteRepository.obtenerOCrearCliente(String nombre)` — reutiliza un cliente cuyo nombre coincida sin importar mayúsculas ni espacios de los extremos.
  - `Future<int> FiadoRepository.clientesConDeudaAl(DateTime dia)`
  - `ResumenDia` agrega `int cantidadVentas`, `int cantidadFiadas`, `int clientesConDeuda` (requeridos).
  - `String plural(int n, String uno, String varios)` → `"1 venta"`, `"3 ventas"`.
  - `String textoDebeDesde(DateTime desde, DateTime hoy)` → `"Debe desde hoy"`, `"Debe desde ayer"`, `"Debe desde hace N días"`.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar dentro de `main()` en `test/repositories/venta_repository_test.dart` (usa el `repo`, `db` y `usuarioId` del `setUp` existente; si el archivo nombra distinto esas variables, usar sus nombres):

```dart
  test('eliminarVenta borra solo esa venta', () async {
    final id1 = await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: usuarioId);
    final id2 = await repo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: usuarioId);

    await repo.eliminarVenta(id1);

    final ventas = await db.select(db.ventas).get();
    expect(ventas.map((v) => v.id), [id2]);
  });
```

Agregar dentro de `main()` en `test/repositories/cliente_repository_test.dart` (usa `repo` del `setUp` existente):

```dart
  test('obtenerOCrearCliente reutiliza un cliente con el mismo nombre',
      () async {
    final id = await repo.crearCliente(nombre: 'Don Pedro');

    expect(await repo.obtenerOCrearCliente('  don pedro '), id);
    expect(await repo.listarClientes(), hasLength(1));
  });

  test('obtenerOCrearCliente crea el cliente si no existe, sin espacios',
      () async {
    final id = await repo.obtenerOCrearCliente('  Doña Rosa ');

    final cliente = await repo.obtenerCliente(id);
    expect(cliente!.nombre, 'Doña Rosa');
  });
```

Agregar dentro de `main()` en `test/repositories/fiado_repository_test.dart`:

```dart
  test('clientesConDeudaAl cuenta solo clientes con saldo positivo', () async {
    final rosa = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(5000, DateTime(2026, 9, 1));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 9, 1),
            esFiado: const Value(true),
            clienteId: Value(rosa),
            usuarioId: usuarioId,
          ),
        );
    await repo.registrarPago(
        clienteId: rosa,
        monto: 1000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 1));

    expect(await repo.clientesConDeudaAl(DateTime(2026, 9, 1)), 1);
  });
```

Agregar dentro de `main()` en `test/repositories/resumen_repository_test.dart`:

```dart
  test('resumenDelDia cuenta ventas, fiadas y clientes con deuda', () async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 2000,
        esFiado: true,
        clienteId: pedro,
        usuarioId: vendedor1,
        fecha: dia);

    final resumen = await repo.resumenDelDia(dia);
    expect(resumen.cantidadVentas, 2);
    expect(resumen.cantidadFiadas, 1);
    expect(resumen.clientesConDeuda, 1);
  });
```

Crear `test/util/texto_util_test.dart`:

```dart
import 'package:app_ventas/util/texto_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plural usa singular solo para 1', () {
    expect(plural(1, 'venta', 'ventas'), '1 venta');
    expect(plural(0, 'venta', 'ventas'), '0 ventas');
    expect(plural(3, 'cliente', 'clientes'), '3 clientes');
  });
}
```

Agregar dentro de `main()` en `test/util/fecha_util_test.dart`:

```dart
  test('textoDebeDesde usa hoy, ayer o hace N días', () {
    final hoy = DateTime(2026, 10, 5, 9);
    expect(textoDebeDesde(DateTime(2026, 10, 5, 7), hoy), 'Debe desde hoy');
    expect(textoDebeDesde(DateTime(2026, 10, 4, 23), hoy), 'Debe desde ayer');
    expect(textoDebeDesde(DateTime(2026, 9, 23), hoy),
        'Debe desde hace 12 días');
  });
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/repositories test/util`
Expected: FAIL — métodos, campos y funciones no definidos.

- [ ] **Step 3: Implementar**

En `lib/repositories/venta_repository.dart`, dentro de la clase:

```dart
  /// Solo para "Deshacer" justo después de cobrar; no es una función de
  /// anular ventas pasadas.
  Future<void> eliminarVenta(int id) {
    return (_db.delete(_db.ventas)..where((v) => v.id.equals(id))).go();
  }
```

En `lib/repositories/cliente_repository.dart`, dentro de la clase:

```dart
  /// Id del cliente cuyo nombre coincide con [nombre] (sin importar
  /// mayúsculas ni espacios de los extremos); si no existe, lo crea.
  Future<int> obtenerOCrearCliente(String nombre) async {
    final limpio = nombre.trim();
    final buscado = limpio.toLowerCase();
    for (final cliente in await listarClientes()) {
      if (cliente.nombre.trim().toLowerCase() == buscado) return cliente.id;
    }
    return crearCliente(nombre: limpio);
  }
```

En `lib/repositories/fiado_repository.dart`, reemplazar el método `deudaTotalAl` completo por:

```dart
  /// Saldo de cada cliente al cierre de [dia]: ventas fiadas menos abonos
  /// hechos hasta ese momento.
  Future<Map<int, int>> _saldosAl(DateTime dia) async {
    final corte = finDelDia(dia);
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.esFiado.equals(true) &
              v.clienteId.isNotNull() &
              v.fecha.isSmallerOrEqualValue(corte)))
        .get();
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) => p.fecha.isSmallerOrEqualValue(corte)))
        .get();

    final saldos = <int, int>{};
    for (final v in ventas) {
      saldos.update(v.clienteId!, (s) => s + v.monto, ifAbsent: () => v.monto);
    }
    for (final p in pagos) {
      saldos.update(p.clienteId, (s) => s - p.monto, ifAbsent: () => -p.monto);
    }
    return saldos;
  }

  /// Lo que deben todos los clientes al cierre de [dia]. Un cliente con saldo
  /// a favor cuenta como 0, para que no reste a la deuda de los demás.
  Future<int> deudaTotalAl(DateTime dia) async {
    final saldos = await _saldosAl(dia);
    return saldos.values
        .where((s) => s > 0)
        .fold<int>(0, (suma, s) => suma + s);
  }

  /// Cuántos clientes deben algo al cierre de [dia].
  Future<int> clientesConDeudaAl(DateTime dia) async {
    final saldos = await _saldosAl(dia);
    return saldos.values.where((s) => s > 0).length;
  }
```

En `lib/repositories/resumen_repository.dart`, en `ResumenDia` agregar los campos y parámetros:

```dart
class ResumenDia {
  const ResumenDia({
    required this.totalVendido,
    required this.totalGastado,
    required this.totalPorCobrar,
    required this.cantidadVentas,
    required this.cantidadFiadas,
    required this.clientesConDeuda,
  });

  final int totalVendido;
  final int totalGastado;
  final int totalPorCobrar;
  final int cantidadVentas;
  final int cantidadFiadas;
  final int clientesConDeuda;
}
```

y en `resumenDelDia`, reemplazar el `return ResumenDia(...)` por:

```dart
    return ResumenDia(
      totalVendido: totalVendido,
      totalGastado: totalGastado,
      totalPorCobrar: totalPorCobrar,
      cantidadVentas: ventas.length,
      cantidadFiadas: ventas.where((v) => v.esFiado).length,
      clientesConDeuda: await _fiadoRepository.clientesConDeudaAl(dia),
    );
```

Crear `lib/util/texto_util.dart`:

```dart
/// "1 venta", "3 ventas".
String plural(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';
```

Agregar al final de `lib/util/fecha_util.dart`:

```dart
/// "Debe desde hoy", "Debe desde ayer" o "Debe desde hace N días".
String textoDebeDesde(DateTime desde, DateTime hoy) {
  final dias = inicioDelDia(hoy).difference(inicioDelDia(desde)).inDays;
  if (dias <= 0) return 'Debe desde hoy';
  if (dias == 1) return 'Debe desde ayer';
  return 'Debe desde hace $dias días';
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/repositories test/util`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories lib/util test/repositories test/util
git commit -m "Add sale undo, client lookup, and daily counts for the summary"
```

---

### Task 5: Estado del ticket de venta

**Files:**
- Create: `lib/providers/ticket_provider.dart`
- Test: `test/providers/ticket_provider_test.dart`

**Interfaces:**
- Consumes: `Producto` (Drift), `formatoMoneda`.
- Produces:
  - `LineaTicket({required String clave, required String etiqueta, required int precio, int cantidad = 1, int? productoId})` con `subtotal`. Claves: `'p<idProducto>'` o `'m<monto>'`.
  - `ClienteTicket({int? id, required String nombre})` — `id` null = cliente nuevo.
  - `Ticket` con `lineas`, `esFiado`, `cliente`, `total`, `cantidadArticulos`, `estaVacio`, `productoIdUnico`, `puedeCobrar`, `int cantidadDe(String clave)`.
  - `TicketNotifier` con `agregarProducto(Producto)`, `agregarMonto(int)`, `sumar(String clave)`, `restar(String clave)`, `quitar(String clave)`, `vaciar()`, `cambiarFiado(bool)`, `elegirCliente(ClienteTicket?)`.
  - `final ticketProvider = NotifierProvider.autoDispose<TicketNotifier, Ticket>(...)`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/providers/ticket_provider_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late ProviderSubscription<Ticket> suscripcion;

  const arepa = Producto(id: 1, nombre: 'Arepa', precio: 3500, activo: true);
  const pan = Producto(id: 2, nombre: 'Pan', precio: 500, activo: true);

  TicketNotifier notifier() => container.read(ticketProvider.notifier);
  Ticket ticket() => container.read(ticketProvider);

  setUp(() {
    container = ProviderContainer();
    suscripcion = container.listen(ticketProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('empieza vacío y no se puede cobrar', () {
    expect(ticket().estaVacio, isTrue);
    expect(ticket().total, 0);
    expect(ticket().puedeCobrar, isFalse);
  });

  test('agregar el mismo producto suma su cantidad', () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(arepa);
    notifier().agregarMonto(1000);

    expect(ticket().lineas, hasLength(2));
    expect(ticket().cantidadDe('p1'), 2);
    expect(ticket().cantidadArticulos, 3);
    expect(ticket().total, 8000);
  });

  test('restar a cero y quitar sacan la línea; vaciar deja el ticket vacío',
      () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(pan);
    notifier().agregarMonto(2000);

    notifier().restar('p1');
    expect(ticket().cantidadDe('p1'), 0);
    notifier().quitar('m2000');
    expect(ticket().total, 500);
    notifier().sumar('p2');
    expect(ticket().total, 1000);
    notifier().vaciar();
    expect(ticket().estaVacio, isTrue);
  });

  test('agregarMonto ignora montos no positivos', () {
    notifier().agregarMonto(0);
    expect(ticket().estaVacio, isTrue);
  });

  test('productoIdUnico solo con una única línea de producto', () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(arepa);
    expect(ticket().productoIdUnico, 1);

    notifier().agregarProducto(pan);
    expect(ticket().productoIdUnico, isNull);

    notifier().vaciar();
    notifier().agregarMonto(5000);
    expect(ticket().productoIdUnico, isNull);
  });

  test('fiado sin cliente no se puede cobrar; con cliente sí', () {
    notifier().agregarMonto(2000);
    notifier().cambiarFiado(true);
    expect(ticket().puedeCobrar, isFalse);

    notifier().elegirCliente(const ClienteTicket(nombre: 'Don Pedro'));
    expect(ticket().puedeCobrar, isTrue);

    notifier().cambiarFiado(false);
    expect(ticket().cliente, isNull);
    expect(ticket().puedeCobrar, isTrue);
  });

  test('al dejar de usarse, el ticket se descarta', () async {
    notifier().agregarMonto(5000);

    suscripcion.close();
    await container.pump();

    expect(container.read(ticketProvider).estaVacio, isTrue);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/providers/ticket_provider_test.dart`
Expected: FAIL — `ticket_provider.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/providers/ticket_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../util/formato_moneda.dart';

class LineaTicket {
  const LineaTicket({
    required this.clave,
    required this.etiqueta,
    required this.precio,
    this.cantidad = 1,
    this.productoId,
  });

  /// `p<idProducto>` para productos, `m<monto>` para montos sueltos.
  final String clave;
  final String etiqueta;
  final int precio;
  final int cantidad;
  final int? productoId;

  int get subtotal => precio * cantidad;

  LineaTicket conCantidad(int nueva) => LineaTicket(
        clave: clave,
        etiqueta: etiqueta,
        precio: precio,
        cantidad: nueva,
        productoId: productoId,
      );
}

/// Cliente de una venta fiada. [id] null = cliente nuevo por crear al cobrar.
class ClienteTicket {
  const ClienteTicket({this.id, required this.nombre});

  final int? id;
  final String nombre;
}

class Ticket {
  const Ticket({this.lineas = const [], this.esFiado = false, this.cliente});

  final List<LineaTicket> lineas;
  final bool esFiado;
  final ClienteTicket? cliente;

  int get total => lineas.fold(0, (suma, l) => suma + l.subtotal);
  int get cantidadArticulos => lineas.fold(0, (suma, l) => suma + l.cantidad);
  bool get estaVacio => lineas.isEmpty;

  /// Producto de la venta: solo si el ticket tiene una única línea y es de
  /// producto; si no, la venta queda sin producto.
  int? get productoIdUnico =>
      lineas.length == 1 ? lineas.single.productoId : null;

  bool get puedeCobrar => !estaVacio && (!esFiado || cliente != null);

  int cantidadDe(String clave) {
    for (final linea in lineas) {
      if (linea.clave == clave) return linea.cantidad;
    }
    return 0;
  }
}

class TicketNotifier extends AutoDisposeNotifier<Ticket> {
  @override
  Ticket build() => const Ticket();

  void agregarProducto(Producto producto) => _agregar(LineaTicket(
        clave: 'p${producto.id}',
        etiqueta: producto.nombre,
        precio: producto.precio,
        productoId: producto.id,
      ));

  void agregarMonto(int monto) {
    if (monto <= 0) return;
    _agregar(LineaTicket(
      clave: 'm$monto',
      etiqueta: formatoMoneda(monto),
      precio: monto,
    ));
  }

  void sumar(String clave) => _cambiarCantidad(clave, 1);

  void restar(String clave) => _cambiarCantidad(clave, -1);

  void quitar(String clave) => _conLineas(
      [for (final l in state.lineas) if (l.clave != clave) l]);

  void vaciar() => _conLineas(const []);

  void cambiarFiado(bool esFiado) => state = Ticket(
        lineas: state.lineas,
        esFiado: esFiado,
        cliente: esFiado ? state.cliente : null,
      );

  void elegirCliente(ClienteTicket? cliente) => state =
      Ticket(lineas: state.lineas, esFiado: state.esFiado, cliente: cliente);

  void _agregar(LineaTicket nueva) {
    if (state.cantidadDe(nueva.clave) > 0) {
      _cambiarCantidad(nueva.clave, 1);
    } else {
      _conLineas([...state.lineas, nueva]);
    }
  }

  void _cambiarCantidad(String clave, int delta) => _conLineas([
        for (final l in state.lineas)
          if (l.clave != clave)
            l
          else if (l.cantidad + delta > 0)
            l.conCantidad(l.cantidad + delta),
      ]);

  void _conLineas(List<LineaTicket> lineas) => state =
      Ticket(lineas: lineas, esFiado: state.esFiado, cliente: state.cliente);
}

/// Ticket de la pantalla "Nueva venta". Se descarta al salir de la pantalla.
final ticketProvider =
    NotifierProvider.autoDispose<TicketNotifier, Ticket>(TicketNotifier.new);
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/providers/ticket_provider_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/ticket_provider.dart test/providers/ticket_provider_test.dart
git commit -m "Add sale ticket state notifier"
```

---

### Task 6: Pantalla "Nueva venta" con ticket y Deshacer

**Files:**
- Create: `lib/ui/mosaico.dart`
- Modify (reescribir): `lib/widgets/monto_rapido_grid.dart`, `lib/screens/venta/registrar_venta_screen.dart`
- Test (reescribir): `test/screens/venta/registrar_venta_screen_test.dart`; `test/widgets/monto_rapido_grid_test.dart` (sigue igual; debe pasar)

**Interfaces:**
- Consumes: Tasks 2, 3, 4 (`eliminarVenta`, `obtenerOCrearCliente`), 5 (`ticketProvider`); `productosActivosProvider`, `listaClientesProvider`, `sesionProvider`, `ventaRepositoryProvider`, `clienteRepositoryProvider`.
- Produces:
  - `Mosaico({required String titulo, String? subtitulo, int cantidad = 0, required VoidCallback onTap, bool destacado = false})`
  - `MontoRapidoGrid({required void Function(int) onSeleccionar, int Function(int monto)? cantidadDe})` (claves `monto_rapido_<monto>` como hoy).
  - Claves de la pantalla: `selector_tipo_venta`, `campo_cliente`, `cliente_sugerido_<id>`, `boton_cliente_nuevo`, `cliente_elegido`, `producto_<id>`, `boton_otro_monto`, `boton_agregar_monto`, `texto_articulos`, `boton_ver_ticket`, `boton_vaciar`, `boton_cobrar`, `restar_<clave>`, `sumar_<clave>`, `quitar_<clave>`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/venta/registrar_venta_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrirVenta(WidgetTester tester) async {
    await tester
        .pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()));
    await tester.pumpAndSettle();
  }

  BotonPrincipal botonCobrar(WidgetTester tester) =>
      tester.widget<BotonPrincipal>(find.byKey(const Key('boton_cobrar')));

  testWidgets('tocar montos suma al ticket y solo Cobrar registra la venta',
      (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $11.000'), findsOneWidget);
    expect(find.text('3 artículos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.monto, 11000);
    expect(ventas.single.esFiado, isFalse);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(r'Venta registrada · $11.000'), findsOneWidget);
  });

  testWidgets('con el ticket vacío no se puede cobrar', (tester) async {
    await abrirVenta(tester);

    expect(botonCobrar(tester).onPressed, isNull);
    expect(find.text('Agrega algo para cobrar'), findsOneWidget);
  });

  testWidgets('Deshacer elimina la venta recién registrada', (tester) async {
    await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 999, fecha: DateTime.now(), usuarioId: 1));
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(await db.select(db.ventas).get(), hasLength(2));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.monto, 999);
  });

  testWidgets('fiado sin cliente no deja cobrar; con cliente nuevo sí',
      (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.text('Fiado'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    expect(botonCobrar(tester).onPressed, isNull);
    expect(find.text('Falta elegir el cliente'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pump();
    expect(find.text(r'Fiar $2.000 a Don Pedro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    final clientes = await db.select(db.clientes).get();
    expect(ventas.single.esFiado, isTrue);
    expect(clientes.single.nombre, 'Don Pedro');
    expect(ventas.single.clienteId, clientes.single.id);
  });

  testWidgets('elegir un cliente existente no crea un duplicado',
      (tester) async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await abrirVenta(tester);

    await tester.tap(find.text('Fiado'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'don pedro');
    await tester.pump();
    expect(find.byKey(const Key('boton_cliente_nuevo')), findsNothing);
    await tester.tap(find.byKey(Key('cliente_sugerido_$pedro')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.clientes).get(), hasLength(1));
    expect((await db.select(db.ventas).get()).single.clienteId, pedro);
  });

  testWidgets('un ticket con un solo producto guarda el producto',
      (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 7000);
    expect(venta.productoId, arepa);
  });

  testWidgets('Ver ticket permite restar y quitar líneas', (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_ver_ticket')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('restar_p$arepa')));
    await tester.pump();
    expect(find.text(r'Cobrar $4.500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quitar_m1000')));
    await tester.pump();
    expect(find.text(r'Cobrar $3.500'), findsOneWidget);
  });

  testWidgets('Otro monto agrega lo tecleado al ticket', (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('boton_otro_monto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_1')));
    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_agregar_monto')));
    await tester.pumpAndSettle();

    expect(find.text(r'Cobrar $12.000'), findsOneWidget);
  });

  testWidgets('salir sin cobrar descarta el ticket', (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();

    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Agrega algo para cobrar'), findsOneWidget);
    expect(await db.select(db.ventas).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/venta/registrar_venta_screen_test.dart`
Expected: FAIL — un toque registra la venta al instante; no existen `boton_cobrar` ni el resto.

- [ ] **Step 3: Implementar el mosaico y la grilla de montos**

Crear `lib/ui/mosaico.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Baldosa tocable para productos y montos rápidos, con insignia de cantidad.
class Mosaico extends StatelessWidget {
  const Mosaico({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.cantidad = 0,
    required this.onTap,
    this.destacado = false,
  });

  final String titulo;
  final String? subtitulo;
  final int cantidad;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final elegido = cantidad > 0;
    return Material(
      color: ColoresApp.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegido ? ColoresApp.primario : ColoresApp.borde,
          width: elegido ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            destacado ? ColoresApp.primario : ColoresApp.texto,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.textoSecundario,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (elegido)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColoresApp.primario,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$cantidad',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Reemplazar todo `lib/widgets/monto_rapido_grid.dart` por:

```dart
import 'package:flutter/material.dart';

import '../ui/mosaico.dart';
import '../util/formato_moneda.dart';

class MontoRapidoGrid extends StatelessWidget {
  const MontoRapidoGrid({super.key, required this.onSeleccionar, this.cantidadDe});

  final void Function(int monto) onSeleccionar;

  /// Cuántas veces está ese monto en el ticket (para la insignia).
  final int Function(int monto)? cantidadDe;

  static const montos = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        for (final monto in montos)
          Mosaico(
            key: Key('monto_rapido_$monto'),
            titulo: formatoMoneda(monto),
            cantidad: cantidadDe?.call(monto) ?? 0,
            onTap: () => onSeleccionar(monto),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Reescribir la pantalla**

Reemplazar todo `lib/screens/venta/registrar_venta_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/clientes_providers.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/mosaico.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/teclado_monto.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/monto_rapido_grid.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen({super.key});

  @override
  ConsumerState<RegistrarVentaScreen> createState() =>
      _RegistrarVentaScreenState();
}

class _RegistrarVentaScreenState extends ConsumerState<RegistrarVentaScreen> {
  /// Evita registrar dos veces el mismo ticket con un doble toque.
  bool _cobrando = false;

  Future<void> _otroMonto() async {
    final monto = await mostrarHojaInferior<int>(
      context,
      titulo: 'Otro monto',
      builder: (_) => const _HojaOtroMonto(),
    );
    if (monto != null) ref.read(ticketProvider.notifier).agregarMonto(monto);
  }

  Future<void> _verTicket() => mostrarHojaInferior<void>(
        context,
        titulo: 'Ticket',
        builder: (_) => const _HojaTicket(),
      );

  Future<void> _cobrar() async {
    if (_cobrando) return;
    setState(() => _cobrando = true);
    try {
      final ticket = ref.read(ticketProvider);
      final sesion = ref.read(sesionProvider).usuarioActivo!;
      int? clienteId;
      if (ticket.esFiado) {
        final cliente = ticket.cliente!;
        clienteId = cliente.id ??
            await ref
                .read(clienteRepositoryProvider)
                .obtenerOCrearCliente(cliente.nombre);
      }
      final ventaRepo = ref.read(ventaRepositoryProvider);
      final ventaId = await ventaRepo.registrarVenta(
        monto: ticket.total,
        productoId: ticket.productoIdUnico,
        esFiado: ticket.esFiado,
        clienteId: clienteId,
        usuarioId: sesion.id,
      );
      if (!mounted) return;
      avisar(
        context,
        'Venta registrada · ${formatoMoneda(ticket.total)}',
        onDeshacer: () => ventaRepo.eliminarVenta(ventaId),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final productosAsync = ref.watch(productosActivosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectorSegmentado<bool>(
            key: const Key('selector_tipo_venta'),
            opciones: const {false: 'Contado', true: 'Fiado'},
            valor: ticket.esFiado,
            onCambio: notifier.cambiarFiado,
          ),
          if (ticket.esFiado) ...[
            const SizedBox(height: 12),
            const _SelectorCliente(),
          ],
          const _Seccion('PRODUCTOS'),
          productosAsync.when(
            data: (productos) => GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
              children: [
                for (final p in productos)
                  Mosaico(
                    key: Key('producto_${p.id}'),
                    titulo: p.nombre,
                    subtitulo: formatoMoneda(p.precio),
                    cantidad: ticket.cantidadDe('p${p.id}'),
                    onTap: () => notifier.agregarProducto(p),
                  ),
                Mosaico(
                  key: const Key('boton_otro_monto'),
                  titulo: '+ Otro',
                  subtitulo: 'monto',
                  destacado: true,
                  onTap: _otroMonto,
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
          const _Seccion('MONTOS RÁPIDOS'),
          MontoRapidoGrid(
            onSeleccionar: notifier.agregarMonto,
            cantidadDe: (monto) => ticket.cantidadDe('m$monto'),
          ),
        ],
      ),
      bottomNavigationBar: _BarraCobro(
        ticket: ticket,
        cobrando: _cobrando,
        onCobrar: _cobrar,
        onVerTicket: _verTicket,
        onVaciar: notifier.vaciar,
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}

class _SelectorCliente extends ConsumerStatefulWidget {
  const _SelectorCliente();

  @override
  ConsumerState<_SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends ConsumerState<_SelectorCliente> {
  final _controller = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final elegido = ticket.cliente;
    if (elegido != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('cliente_elegido'),
          avatar: const Icon(Icons.person_rounded, size: 18),
          label: Text(elegido.nombre),
          onDeleted: () => notifier.elegirCliente(null),
        ),
      );
    }

    final clientes =
        ref.watch(listaClientesProvider).valueOrNull ?? const <Cliente>[];
    final texto = _busqueda.trim();
    final buscado = texto.toLowerCase();
    final sugeridos = clientes
        .where((c) => c.nombre.toLowerCase().contains(buscado))
        .take(6)
        .toList();
    final existeExacto =
        clientes.any((c) => c.nombre.trim().toLowerCase() == buscado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('campo_cliente'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: '¿A quién le fías?',
            prefixIcon: const Icon(Icons.search_rounded),
            errorText: ticket.estaVacio ? null : 'Elige o escribe el cliente',
          ),
          onChanged: (valor) => setState(() => _busqueda = valor),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in sugeridos)
              ActionChip(
                key: Key('cliente_sugerido_${c.id}'),
                label: Text(c.nombre),
                onPressed: () => notifier
                    .elegirCliente(ClienteTicket(id: c.id, nombre: c.nombre)),
              ),
            if (texto.isNotEmpty && !existeExacto)
              ActionChip(
                key: const Key('boton_cliente_nuevo'),
                avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text('Nuevo: $texto'),
                onPressed: () =>
                    notifier.elegirCliente(ClienteTicket(nombre: texto)),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarraCobro extends StatelessWidget {
  const _BarraCobro({
    required this.ticket,
    required this.cobrando,
    required this.onCobrar,
    required this.onVerTicket,
    required this.onVaciar,
  });

  final Ticket ticket;
  final bool cobrando;
  final VoidCallback onCobrar;
  final VoidCallback onVerTicket;
  final VoidCallback onVaciar;

  @override
  Widget build(BuildContext context) {
    final total = formatoMoneda(ticket.total);
    final texto = !ticket.esFiado
        ? 'Cobrar $total'
        : ticket.cliente == null
            ? 'Fiar $total'
            : 'Fiar $total a ${ticket.cliente!.nombre}';
    final String? aviso = ticket.estaVacio
        ? 'Agrega algo para cobrar'
        : (ticket.esFiado && ticket.cliente == null)
            ? 'Falta elegir el cliente'
            : null;
    final n = ticket.cantidadArticulos;

    return Material(
      color: ColoresApp.superficie,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ColoresApp.borde)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    n == 1 ? '1 artículo' : '$n artículos',
                    key: const Key('texto_articulos'),
                    style: const TextStyle(color: ColoresApp.textoSecundario),
                  ),
                  TextButton(
                    key: const Key('boton_ver_ticket'),
                    onPressed: ticket.estaVacio ? null : onVerTicket,
                    child: const Text('Ver ticket'),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('boton_vaciar'),
                    style:
                        TextButton.styleFrom(foregroundColor: ColoresApp.sale),
                    onPressed: ticket.estaVacio ? null : onVaciar,
                    child: const Text('Vaciar'),
                  ),
                ],
              ),
              if (aviso != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    aviso,
                    style: const TextStyle(
                        fontSize: 13, color: ColoresApp.textoSecundario),
                  ),
                ),
              BotonPrincipal(
                key: const Key('boton_cobrar'),
                texto: texto,
                variante: VarianteBoton.entra,
                onPressed: ticket.puedeCobrar && !cobrando ? onCobrar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaTicket extends ConsumerWidget {
  const _HojaTicket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    if (ticket.estaVacio) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('El ticket está vacío', textAlign: TextAlign.center),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final linea in ticket.lineas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(linea.etiqueta,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle:
                Text('${linea.cantidad} × ${formatoMoneda(linea.precio)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('restar_${linea.clave}'),
                  tooltip: 'Quitar uno',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () => notifier.restar(linea.clave),
                ),
                IconButton(
                  key: Key('sumar_${linea.clave}'),
                  tooltip: 'Agregar uno',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () => notifier.sumar(linea.clave),
                ),
                IconButton(
                  key: Key('quitar_${linea.clave}'),
                  tooltip: 'Quitar del ticket',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: ColoresApp.sale),
                  onPressed: () => notifier.quitar(linea.clave),
                ),
              ],
            ),
          ),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Monto(ticket.total, tamano: 22),
          ],
        ),
      ],
    );
  }
}

class _HojaOtroMonto extends StatefulWidget {
  const _HojaOtroMonto();

  @override
  State<_HojaOtroMonto> createState() => _HojaOtroMontoState();
}

class _HojaOtroMontoState extends State<_HojaOtroMonto> {
  int _monto = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Monto(_monto, tamano: 36)),
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) =>
              setState(() => _monto = aplicarTecla(_monto, tecla)),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_agregar_monto'),
          texto: 'Agregar al ticket',
          onPressed:
              _monto > 0 ? () => Navigator.of(context).pop(_monto) : null,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/venta test/widgets/monto_rapido_grid_test.dart`
Expected: PASS (9 + 1 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/mosaico.dart lib/widgets/monto_rapido_grid.dart lib/screens/venta test/screens/venta
git commit -m "Replace one-tap sales with a ticket, Cobrar button, and undo"
```

---

### Task 7: Estructura de navegación, encabezado y Ajustes

**Files:**
- Modify (reescribir): `lib/screens/home/home_screen.dart`
- Create: `lib/screens/configuracion/ajustes_screen.dart`
- Test (reescribir): `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `AvatarInicial` (Task 2); `sesionProvider`; `ResumenScreen`, `ListaFiadoScreen`, `HistorialScreen`, `ProductosScreen`, `UsuariosScreen`, `RegistrarVentaScreen`, `RegistrarGastoScreen`.
- Produces: `AjustesScreen()`; claves `menu_cuenta`, `boton_cerrar_sesion` (ítem del menú), `ajustes_cerrar_sesion`, `menu_productos`, `menu_usuarios`. Los botones flotantes `boton_nueva_venta`/`boton_nuevo_gasto` se mantienen en esta task y pasan al Inicio en la Task 8.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/home/home_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> montar(WidgetTester tester,
      {String rol = 'admin'}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('el admin ve la pestaña Ajustes', (tester) async {
    await montar(tester);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Config'), findsNothing);
  });

  testWidgets('el vendedor no ve la pestaña Ajustes', (tester) async {
    await montar(tester, rol: 'vendedor');
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('en Inicio saluda y en otra pestaña muestra su título',
      (tester) async {
    await montar(tester);
    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Hola, Ana')),
        findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Historial')),
        findsOneWidget);
  });

  testWidgets('cerrar sesión desde el menú de la cuenta', (tester) async {
    final container = await montar(tester);

    await tester.tap(find.byKey(const Key('menu_cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cerrar_sesion')));
    await tester.pumpAndSettle();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('Ajustes tiene Productos, Usuarios y Cerrar sesión',
      (tester) async {
    final container = await montar(tester);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_productos')), findsOneWidget);
    expect(find.byKey(const Key('menu_usuarios')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ajustes_cerrar_sesion')));
    await tester.pumpAndSettle();
    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('los íconos de las pestañas se ven oscuros sobre la barra clara',
      (tester) async {
    await montar(tester);

    for (final icono in [
      Icons.people_outline_rounded,
      Icons.receipt_long_outlined,
      Icons.settings_outlined,
    ]) {
      final elemento = tester.element(find.byIcon(icono));
      expect(IconTheme.of(elemento).color!.computeLuminance(), lessThan(0.5),
          reason: 'el ícono $icono debe verse sobre el fondo de la barra');
    }
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/home/home_screen_test.dart`
Expected: FAIL — no hay pestaña "Ajustes", ni `menu_cuenta`.

- [ ] **Step 3: Implementar Ajustes**

Crear `lib/screens/configuracion/ajustes_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../../ui/colores_app.dart';
import 'productos_screen.dart';
import 'usuarios_screen.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Titulo('TIENDA'),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('menu_productos'),
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Productos'),
                subtitle: const Text('Catálogo y precios'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductosScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_usuarios'),
                leading: const Icon(Icons.group_outlined),
                title: const Text('Usuarios'),
                subtitle: const Text('Administradores, vendedores y PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Titulo('CUENTA'),
        Card(
          child: ListTile(
            key: const Key('ajustes_cerrar_sesion'),
            leading: const Icon(Icons.logout_rounded, color: ColoresApp.sale),
            title: const Text('Cerrar sesión',
                style: TextStyle(color: ColoresApp.sale)),
            onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Reescribir la estructura principal**

Reemplazar todo `lib/screens/home/home_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../configuracion/ajustes_screen.dart';
import '../fiado/lista_fiado_screen.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../historial/historial_screen.dart';
import '../venta/registrar_venta_screen.dart';
import 'resumen_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabActual = 0;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    if (!sesion.haySesion) return const SizedBox.shrink();
    final usuario = sesion.usuarioActivo!;

    final tabs = <_Pestana>[
      const _Pestana('Inicio', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded, ResumenScreen()),
      const _Pestana('Fiado', Icons.people_outline_rounded,
          Icons.people_rounded, ListaFiadoScreen()),
      const _Pestana('Historial', Icons.receipt_long_outlined,
          Icons.receipt_long_rounded, HistorialScreen()),
      if (sesion.esAdmin)
        const _Pestana('Ajustes', Icons.settings_outlined,
            Icons.settings_rounded, AjustesScreen()),
    ];
    if (_tabActual >= tabs.length) _tabActual = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabActual == 0
            ? 'Hola, ${usuario.nombre}'
            : tabs[_tabActual].titulo),
        actions: [_MenuCuenta(usuario: usuario), const SizedBox(width: 8)],
      ),
      body: tabs[_tabActual].pantalla,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (i) => setState(() => _tabActual = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icono),
              selectedIcon: Icon(t.iconoActivo),
              label: t.titulo,
            ),
        ],
      ),
      floatingActionButton: _tabActual == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  key: const Key('boton_nueva_venta'),
                  heroTag: 'venta',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RegistrarVentaScreen()),
                  ),
                  label: const Text('+ Venta'),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  key: const Key('boton_nuevo_gasto'),
                  heroTag: 'gasto',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RegistrarGastoScreen()),
                  ),
                  label: const Text('− Gasto'),
                ),
              ],
            )
          : null,
    );
  }
}

class _Pestana {
  const _Pestana(this.titulo, this.icono, this.iconoActivo, this.pantalla);

  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
}

class _MenuCuenta extends ConsumerWidget {
  const _MenuCuenta({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('menu_cuenta'),
      tooltip: 'Cuenta',
      icon: AvatarInicial(id: usuario.id, nombre: usuario.nombre, radio: 16),
      onSelected: (_) => ref.read(sesionProvider.notifier).cerrarSesion(),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          key: const Key('boton_cerrar_sesion'),
          value: 'salir',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded),
              const SizedBox(width: 12),
              Text('Cerrar sesión (${usuario.nombre})'),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/home test/widget_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart lib/screens/configuracion/ajustes_screen.dart test/screens/home/home_screen_test.dart
git commit -m "Use NavigationBar, a single header, account menu, and Ajustes tab"
```

---

### Task 8: Inicio (antes Resumen)

**Files:**
- Modify (reescribir): `lib/screens/home/resumen_screen.dart`
- Modify: `lib/screens/home/home_screen.dart` (pasar `onVerFiado`, quitar botones flotantes)
- Test (reescribir): `test/screens/home/resumen_screen_test.dart`; agregar un test a `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `ResumenDia` con conteos (Task 4); `plural` (Task 4); `Monto`, `TarjetaMonto`, `BotonPrincipal`, `AvatarInicial` (Task 2); `SelectorFecha`.
- Produces: `ResumenScreen({VoidCallback? onVerFiado})`; claves `tarjeta_ventas`, `tarjeta_gastos`, `tarjeta_ganancia`, `tarjeta_por_cobrar`, `boton_nueva_venta`, `boton_nuevo_gasto`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/home/resumen_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/home/resumen_screen.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  });

  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester, {VoidCallback? onVerFiado}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: temaApp(),
          home: Scaffold(body: ResumenScreen(onVerFiado: onVerFiado)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder enTarjeta(String clave, String texto) => find.descendant(
      of: find.byKey(Key(clave)), matching: find.text(texto));

  Future<void> vender(int monto, {bool fiado = false, DateTime? fecha}) async {
    int? clienteId;
    if (fiado) {
      clienteId = await db
          .into(db.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Cliente $monto'));
    }
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: monto,
          fecha: fecha ?? DateTime.now(),
          esFiado: Value(fiado),
          clienteId: Value(clienteId),
          usuarioId: ana,
        ));
  }

  testWidgets('muestra ventas, gastos, ganancia y por cobrar del día',
      (tester) async {
    await vender(5000);
    await vender(2000, fiado: true);
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 1000, fecha: DateTime.now(), usuarioId: ana));

    await montar(tester);

    expect(enTarjeta('tarjeta_ventas', r'$7.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', '2 ventas · 1 fiada'), findsOneWidget);
    expect(enTarjeta('tarjeta_gastos', r'$1.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_ganancia', r'$6.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_por_cobrar', r'$2.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_por_cobrar', '1 cliente'), findsOneWidget);
  });

  testWidgets('una ganancia negativa se muestra en rojo', (tester) async {
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 3000, fecha: DateTime.now(), usuarioId: ana));

    await montar(tester);

    final monto = tester.widget<Monto>(find.descendant(
        of: find.byKey(const Key('tarjeta_ganancia')),
        matching: find.byType(Monto)));
    expect(monto.valor, -3000);
    expect(monto.tono, TonoMonto.sale);
  });

  testWidgets('tocar Por cobrar llama onVerFiado', (tester) async {
    var llamado = false;
    await montar(tester, onVerFiado: () => llamado = true);

    await tester.tap(find.byKey(const Key('tarjeta_por_cobrar')));
    expect(llamado, isTrue);
  });

  testWidgets('navegar al día anterior muestra las ventas de ese día',
      (tester) async {
    final ahora = DateTime.now();
    await vender(5000);
    await vender(7000,
        fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12));

    await montar(tester);
    expect(find.text('Hoy'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', r'$5.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();
    expect(enTarjeta('tarjeta_ventas', r'$7.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', r'$5.000'), findsOneWidget);
  });

  testWidgets('cifras grandes no desbordan en un celular pequeño',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await vender(123456789);
    await vender(98765432, fiado: true);

    await montar(tester);

    expect(tester.takeException(), isNull);
  });
}
```

Agregar dentro de `main()` en `test/screens/home/home_screen_test.dart`:

```dart
  testWidgets('tocar Por cobrar en Inicio abre la pestaña Fiado',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('tarjeta_por_cobrar')));
    await tester.pumpAndSettle();

    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Fiado')),
        findsOneWidget);
  });
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/home`
Expected: FAIL — no existen las tarjetas ni `onVerFiado`.

- [ ] **Step 3: Reescribir el Inicio**

Reemplazar todo `lib/screens/home/resumen_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../repositories/resumen_repository.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_fecha.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../venta/registrar_venta_screen.dart';

class ResumenScreen extends ConsumerStatefulWidget {
  const ResumenScreen({super.key, this.onVerFiado});

  /// Se llama al tocar "Por cobrar" (la estructura principal abre Fiado).
  final VoidCallback? onVerFiado;

  @override
  ConsumerState<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends ConsumerState<ResumenScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenDelDiaProvider(_dia));
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider(_dia));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SelectorFecha(
          dia: _dia,
          onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
        ),
        const SizedBox(height: 8),
        resumenAsync.when(
          data: (resumen) =>
              _Tarjetas(resumen: resumen, onVerFiado: widget.onVerFiado),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Text('Error: $e'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BotonPrincipal(
                key: const Key('boton_nueva_venta'),
                texto: '+ Venta',
                variante: VarianteBoton.entra,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RegistrarVentaScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BotonPrincipal(
                key: const Key('boton_nuevo_gasto'),
                texto: '− Gasto',
                variante: VarianteBoton.peligro,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RegistrarGastoScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Por vendedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        porVendedorAsync.when(
          data: (mapa) => Card(
            child: Column(
              children: [
                for (final entrada in mapa.entries)
                  ListTile(
                    leading: AvatarInicial(
                        id: entrada.key.id,
                        nombre: entrada.key.nombre,
                        radio: 16),
                    title: Text(entrada.key.nombre),
                    trailing:
                        Monto(entrada.value.totalVendido, tamano: 16),
                  ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, st) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas({required this.resumen, this.onVerFiado});

  final ResumenDia resumen;
  final VoidCallback? onVerFiado;

  @override
  Widget build(BuildContext context) {
    final ganancia = resumen.totalVendido - resumen.totalGastado;
    return Column(
      children: [
        Container(
          key: const Key('tarjeta_ventas'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColoresApp.primario,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ventas del día',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Monto(resumen.totalVendido, tamano: 32, tono: TonoMonto.claro),
              const SizedBox(height: 4),
              Text(
                '${plural(resumen.cantidadVentas, 'venta', 'ventas')} · '
                '${plural(resumen.cantidadFiadas, 'fiada', 'fiadas')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('tarjeta_gastos'),
                etiqueta: 'Gastos',
                valor: resumen.totalGastado,
                tono: TonoMonto.sale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TarjetaMonto(
                key: const Key('tarjeta_ganancia'),
                etiqueta: 'Ganancia',
                valor: ganancia,
                tono: ganancia >= 0 ? TonoMonto.entra : TonoMonto.sale,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TarjetaMonto(
          key: const Key('tarjeta_por_cobrar'),
          etiqueta: 'Por cobrar',
          valor: resumen.totalPorCobrar,
          tono: TonoMonto.fiado,
          fondo: ColoresApp.fiadoSuave,
          detalle: plural(resumen.clientesConDeuda, 'cliente', 'clientes'),
          onTap: onVerFiado,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Conectar el Inicio en la estructura principal**

En `lib/screens/home/home_screen.dart`:

1. Reemplazar
```dart
      const _Pestana('Inicio', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded, ResumenScreen()),
```
por
```dart
      _Pestana('Inicio', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          ResumenScreen(onVerFiado: () => setState(() => _tabActual = 1))),
```
2. Borrar el bloque completo `floatingActionButton: _tabActual == 0 ? Column(...) : null,` (desde `floatingActionButton:` hasta `: null,` inclusive).
3. Borrar los imports que quedan sin uso: `'../gasto/registrar_gasto_screen.dart'` y `'../venta/registrar_venta_screen.dart'`.

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/home test/widget_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home test/screens/home
git commit -m "Redesign the summary as the Inicio dashboard"
```

---

### Task 9: Nuevo gasto

**Files:**
- Modify (reescribir): `lib/screens/gasto/registrar_gasto_screen.dart`
- Test (reescribir): `test/screens/gasto/registrar_gasto_screen_test.dart`

**Interfaces:**
- Consumes: `TecladoMonto`, `aplicarTecla` (Task 3); `Monto`, `BotonPrincipal`, `avisar` (Task 2); `containerConSesion`, `appDePrueba`.
- Produces: claves `texto_monto_gasto`, `campo_descripcion_gasto`, `boton_registrar_gasto`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/gasto/registrar_gasto_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/gasto/registrar_gasto_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrirGasto(WidgetTester tester) async {
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarGastoScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('registrar un gasto lo guarda, vuelve y lo confirma',
      (tester) async {
    await abrirGasto(tester);

    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_0')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.enterText(
        find.byKey(const Key('campo_descripcion_gasto')), 'Bolsas');
    await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
    await tester.pumpAndSettle();

    final gasto = (await db.select(db.gastos).get()).single;
    expect(gasto.monto, 20000);
    expect(gasto.descripcion, 'Bolsas');
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(r'Gasto registrado · $20.000'), findsOneWidget);
  });

  testWidgets('con monto 0 no se puede registrar', (tester) async {
    await abrirGasto(tester);

    final boton = tester
        .widget<BotonPrincipal>(find.byKey(const Key('boton_registrar_gasto')));
    expect(boton.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/gasto`
Expected: FAIL — no hay teclado de monto ni aviso.

- [ ] **Step 3: Reescribir la pantalla**

Reemplazar todo `lib/screens/gasto/registrar_gasto_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/monto.dart';
import '../../ui/teclado_monto.dart';
import '../../util/formato_moneda.dart';

class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key});

  @override
  ConsumerState<RegistrarGastoScreen> createState() =>
      _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends ConsumerState<RegistrarGastoScreen> {
  final _descripcionController = TextEditingController();
  int _monto = 0;
  bool _guardando = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final sesion = ref.read(sesionProvider).usuarioActivo!;
      final descripcion = _descripcionController.text.trim();
      await ref.read(gastoRepositoryProvider).registrarGasto(
            monto: _monto,
            descripcion: descripcion.isEmpty ? null : descripcion,
            usuarioId: sesion.id,
          );
      if (!mounted) return;
      avisar(context, 'Gasto registrado · ${formatoMoneda(_monto)}');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Monto(
              _monto,
              key: const Key('texto_monto_gasto'),
              tamano: 36,
              tono: TonoMonto.sale,
            ),
          ),
          const SizedBox(height: 16),
          TecladoMonto(
            onTecla: (tecla) =>
                setState(() => _monto = aplicarTecla(_monto, tecla)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('campo_descripcion_gasto'),
            controller: _descripcionController,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Ej: hielo, bolsas, transporte',
            ),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_registrar_gasto'),
            texto: 'Registrar gasto',
            variante: VarianteBoton.peligro,
            onPressed: _monto > 0 && !_guardando ? _registrar : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/gasto`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gasto test/screens/gasto
git commit -m "Redesign expense entry with the amount keypad and confirmation"
```

---

### Task 10: Fiado (lista y detalle con panel de abono)

**Files:**
- Modify (reescribir): `lib/screens/fiado/lista_fiado_screen.dart`, `lib/screens/fiado/detalle_cliente_screen.dart`
- Test (reescribir): `test/screens/fiado/lista_fiado_screen_test.dart`, `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `textoDebeDesde`, `plural` (Task 4); componentes (Tasks 2, 3); `clientesConDeudaProvider`, `saldoClienteProvider`, `movimientosClienteProvider`, `fiadoRepositoryProvider`, `sesionProvider`.
- Produces: claves `tarjeta_te_deben`, `cliente_deuda_<id>`, `tarjeta_saldo_cliente`, `boton_registrar_abono`, `boton_confirmar_abono`. Mismo constructor `DetalleClienteScreen({required ClienteConSaldo clienteConSaldo})`.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar todo `test/screens/fiado/lista_fiado_screen_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:drift/drift.dart' show Value;
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
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin deudas muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Nadie te debe'), findsOneWidget);
    expect(find.text('Las ventas fiadas aparecerán aquí'), findsOneWidget);
  });

  testWidgets('muestra el total y cada cliente con desde cuándo debe',
      (tester) async {
    final ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final ahora = DateTime.now();
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 10),
          esFiado: const Value(true),
          clienteId: Value(pedro),
          usuarioId: ana,
        ));

    await montar(tester);

    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_te_deben')),
            matching: find.text(r'$5.000')),
        findsOneWidget);
    expect(find.text('Don Pedro'), findsOneWidget);
    expect(find.text('Debe desde ayer'), findsOneWidget);
  });
}
```

Reemplazar todo `test/screens/fiado/detalle_cliente_screen_test.dart` por:

```dart
import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Cliente que debe $5.000 (venta fiada el 01/09/2026 10:00), con su detalle
  /// abierto y una sesión activa. Devuelve el id del cliente.
  Future<int> montarDetalle(WidgetTester tester,
      {List<Override> overrides = const []}) async {
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();
    final clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(2026, 9, 1, 10, 0),
          esFiado: const Value(true),
          clienteId: Value(clienteId),
          usuarioId: usuarioId,
        ));
    final cliente =
        await (db.select(db.clientes)..where((c) => c.id.equals(clienteId)))
            .getSingle();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
    );
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaApp(),
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

  Finder saldo(String texto) => find.descendant(
      of: find.byKey(const Key('tarjeta_saldo_cliente')),
      matching: find.text(texto));

  Future<void> teclear(WidgetTester tester, List<String> teclas) async {
    for (final tecla in teclas) {
      await tester.tap(find.byKey(Key('tecla_monto_$tecla')));
    }
    await tester.pump();
  }

  testWidgets('muestra el saldo y los movimientos del cliente', (tester) async {
    await montarDetalle(tester);

    expect(saldo(r'$5.000'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Venta fiada'), findsOneWidget);
    expect(find.text('01/09/2026 10:00'), findsOneWidget);
  });

  testWidgets(
      'registrar un abono desde el panel actualiza saldo y movimientos y '
      'la pantalla sigue abierta', (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['2', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 3000);
    expect(find.byType(DetalleClienteScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(saldo(r'$3.000'), findsOneWidget);
    expect(find.text('Abono registrado'), findsOneWidget);
    expect(find.text('Abono'), findsOneWidget);
  });

  testWidgets('un abono mayor que la deuda muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['9', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('con monto 0 no se puede confirmar el abono', (tester) async {
    await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    final boton = tester.widget<BotonPrincipal>(
        find.byKey(const Key('boton_confirmar_abono')));
    expect(boton.onPressed, isNull);
  });

  testWidgets('un doble toque al confirmar registra un solo abono',
      (tester) async {
    // En producción la base corre en otro isolate, así que la lectura del
    // saldo tarda; el Completer reproduce esa espera.
    final lectura = Completer<void>();
    final clienteId = await montarDetalle(tester, overrides: [
      fiadoRepositoryProvider
          .overrideWithValue(_FiadoRepositoryLento(db, lectura.future)),
    ]);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['2', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')),
        warnIfMissed: false);
    await tester.pump();
    lectura.complete();
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).pagosCliente(clienteId), hasLength(1));
  });
}

/// Espera a [_espera] antes de leer el saldo, para simular la latencia de la
/// base de datos en segundo plano.
class _FiadoRepositoryLento extends FiadoRepository {
  _FiadoRepositoryLento(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<int> saldoCliente(int clienteId) async {
    await _espera;
    return super.saldoCliente(clienteId);
  }
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/fiado`
Expected: FAIL — no existen el estado vacío nuevo, `tarjeta_te_deben`, `tarjeta_saldo_cliente` ni el panel de abono.

- [ ] **Step 3: Reescribir la lista**

Reemplazar todo `lib/screens/fiado/lista_fiado_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/texto_util.dart';
import 'detalle_cliente_screen.dart';

class ListaFiadoScreen extends ConsumerWidget {
  const ListaFiadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesConDeudaProvider);
    return Scaffold(
      body: clientesAsync.when(
        data: (clientes) {
          if (clientes.isEmpty) {
            return const EstadoVacio(
              icono: Icons.volunteer_activism_rounded,
              titulo: 'Nadie te debe',
              mensaje: 'Las ventas fiadas aparecerán aquí',
            );
          }
          final total = clientes.fold<int>(0, (suma, c) => suma + c.saldo);
          final hoy = DateTime.now();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TarjetaMonto(
                key: const Key('tarjeta_te_deben'),
                etiqueta: 'Te deben',
                valor: total,
                tono: TonoMonto.fiado,
                fondo: ColoresApp.fiadoSuave,
                tamano: 28,
                detalle: plural(clientes.length, 'cliente', 'clientes'),
              ),
              const SizedBox(height: 12),
              for (final item in clientes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      key: Key('cliente_deuda_${item.cliente.id}'),
                      leading: AvatarInicial(
                          id: item.cliente.id, nombre: item.cliente.nombre),
                      title: Text(item.cliente.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          Text(textoDebeDesde(item.fechaDeudaMasAntigua, hoy)),
                      trailing:
                          Monto(item.saldo, tamano: 16, tono: TonoMonto.fiado),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DetalleClienteScreen(clienteConSaldo: item),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 4: Reescribir el detalle**

Reemplazar todo `lib/screens/fiado/detalle_cliente_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/teclado_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  /// Cliente y saldo al abrir; el saldo mostrado se lee después de
  /// [saldoClienteProvider] para reflejar abonos hechos en esta pantalla.
  final ClienteConSaldo clienteConSaldo;

  Future<void> _abrirAbono(BuildContext context) async {
    final cliente = clienteConSaldo.cliente;
    final registrado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Abono de ${cliente.nombre}',
      builder: (_) => _HojaAbono(clienteId: cliente.id),
    );
    if (registrado == true && context.mounted) {
      avisar(context, 'Abono registrado');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = clienteConSaldo.cliente;
    final saldo = ref.watch(saldoClienteProvider(cliente.id)).valueOrNull ??
        clienteConSaldo.saldo;
    final movimientosAsync = ref.watch(movimientosClienteProvider(cliente.id));

    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('tarjeta_saldo_cliente'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColoresApp.fiadoSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Debe',
                    style: TextStyle(fontSize: 13, color: ColoresApp.fiado)),
                const SizedBox(height: 4),
                Monto(saldo, tamano: 32, tono: TonoMonto.fiado),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_registrar_abono'),
            texto: 'Registrar abono',
            variante: VarianteBoton.entra,
            onPressed: saldo > 0 ? () => _abrirAbono(context) : null,
          ),
          const SizedBox(height: 24),
          const Text('Movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          movimientosAsync.when(
            data: (movimientos) => Card(
              child: Column(
                children: [
                  for (final m in movimientos) _FilaMovimiento(movimiento: m),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento});

  final MovimientoFiado movimiento;

  @override
  Widget build(BuildContext context) {
    final esAbono = movimiento.tipo == TipoMovimientoFiado.abono;
    final color = esAbono ? ColoresApp.entra : ColoresApp.fiado;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esAbono ? Icons.payments_rounded : Icons.shopping_bag_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Monto(movimiento.monto,
          tamano: 16, tono: esAbono ? TonoMonto.entra : TonoMonto.fiado),
      subtitle: Text(formatoFechaHora(movimiento.fecha)),
      trailing: Text(esAbono ? 'Abono' : 'Venta fiada'),
    );
  }
}

class _HojaAbono extends ConsumerStatefulWidget {
  const _HojaAbono({required this.clienteId});

  final int clienteId;

  @override
  ConsumerState<_HojaAbono> createState() => _HojaAbonoState();
}

class _HojaAbonoState extends ConsumerState<_HojaAbono> {
  int _monto = 0;
  String? _error;

  /// True mientras se valida y guarda; evita registrar dos veces el abono.
  bool _guardando = false;

  Future<void> _registrar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await _guardar();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardar() async {
    final fiadoRepo = ref.read(fiadoRepositoryProvider);
    final saldo = await fiadoRepo.saldoCliente(widget.clienteId);
    if (!mounted) return;
    if (_monto > saldo) {
      setState(() => _error =
          'El abono no puede ser mayor que la deuda (${formatoMoneda(saldo)})');
      return;
    }
    final sesion = ref.read(sesionProvider).usuarioActivo!;
    await fiadoRepo.registrarPago(
      clienteId: widget.clienteId,
      monto: _monto,
      usuarioId: sesion.id,
    );
    ref.invalidate(clientesConDeudaProvider);
    ref.invalidate(saldoClienteProvider(widget.clienteId));
    ref.invalidate(movimientosClienteProvider(widget.clienteId));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Monto(_monto, tamano: 36, tono: TonoMonto.entra)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.sale),
            ),
          ),
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) => setState(() {
            _monto = aplicarTecla(_monto, tecla);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_confirmar_abono'),
          texto: 'Registrar abono',
          variante: VarianteBoton.entra,
          onPressed: _monto > 0 && !_guardando ? _registrar : null,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/fiado`
Expected: PASS (2 + 5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/fiado test/screens/fiado
git commit -m "Redesign fiado list and client detail with an abono keypad panel"
```

---

### Task 11: Historial

**Files:**
- Modify (reescribir): `lib/screens/historial/historial_screen.dart`
- Test (reescribir): `test/screens/historial/historial_screen_test.dart`

**Interfaces:**
- Consumes: `historialProvider`, `listaUsuariosProvider`, `MovimientoHistorial`, `SelectorFecha`; `TarjetaMonto`, `Monto`, `EstadoVacio`.
- Produces: claves `filtro_usuario_todos`, `filtro_usuario_<id>`, `total_ventas`, `total_gastos`, `lista_movimientos`. Sin AppBar propia (el título lo pone la estructura principal).

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

  Finder enLista(String texto) => find.descendant(
      of: find.byKey(const Key('lista_movimientos')), matching: find.text(texto));

  Finder enTotal(String clave, String texto) => find.descendant(
      of: find.byKey(Key(clave)), matching: find.text(texto));

  Future<void> cargarHoy() async {
    await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await gastos.registrarGasto(
        monto: 1000, descripcion: 'Hielo', usuarioId: beto);
    await gastos.registrarGasto(monto: 500, usuarioId: ana);
  }

  testWidgets('muestra ventas y gastos del día con usuario y totales',
      (tester) async {
    await cargarHoy();
    await montar(tester);

    expect(enLista(r'$5.000'), findsOneWidget);
    expect(enLista('Contado · Ana'), findsOneWidget);
    expect(enLista('Hielo · Beto'), findsOneWidget);
    expect(enLista('Gasto · Ana'), findsOneWidget);
    expect(enTotal('total_ventas', r'$5.000'), findsOneWidget);
    expect(enTotal('total_gastos', r'$1.500'), findsOneWidget);
  });

  testWidgets('el filtro por usuario oculta los movimientos de otros',
      (tester) async {
    await cargarHoy();
    await montar(tester);

    await tester.tap(find.byKey(Key('filtro_usuario_$beto')));
    await tester.pumpAndSettle();

    expect(enLista('Hielo · Beto'), findsOneWidget);
    expect(enLista(r'$5.000'), findsNothing);
    expect(enLista('Gasto · Ana'), findsNothing);
    expect(enTotal('total_ventas', r'$0'), findsOneWidget);
  });

  testWidgets('una venta registrada con la pantalla abierta aparece sola',
      (tester) async {
    await montar(tester);
    expect(find.text('Sin movimientos este día'), findsOneWidget);

    await ventas.registrarVenta(monto: 8000, esFiado: true, usuarioId: ana);
    await tester.pumpAndSettle();

    expect(enLista(r'$8.000'), findsOneWidget);
    expect(enLista('Fiado · Ana'), findsOneWidget);
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

    expect(enLista(r'$7.000'), findsOneWidget);
    expect(enLista(r'$5.000'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/historial`
Expected: FAIL — no existen los chips, los totales ni `lista_movimientos`.

- [ ] **Step 3: Reescribir la pantalla**

Reemplazar todo `lib/screens/historial/historial_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/historial_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/historial_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SelectorFecha(
              dia: _dia,
              onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: const Key('filtro_usuario_todos'),
                    label: const Text('Todos'),
                    selected: _usuarioId == null,
                    onSelected: (_) => setState(() => _usuarioId = null),
                  ),
                ),
                for (final u in usuarios)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filtro_usuario_${u.id}'),
                      label: Text(u.nombre),
                      selected: _usuarioId == u.id,
                      onSelected: (_) => setState(() => _usuarioId = u.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: movimientosAsync.when(
              data: (movimientos) {
                final totalVentas = movimientos
                    .where((m) => m.tipo == TipoMovimientoHistorial.venta)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                final totalGastos = movimientos
                    .where((m) => m.tipo == TipoMovimientoHistorial.gasto)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TarjetaMonto(
                            key: const Key('total_ventas'),
                            etiqueta: 'Ventas',
                            valor: totalVentas,
                            tono: TonoMonto.entra,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TarjetaMonto(
                            key: const Key('total_gastos'),
                            etiqueta: 'Gastos',
                            valor: totalGastos,
                            tono: TonoMonto.sale,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (movimientos.isEmpty)
                      const EstadoVacio(
                        icono: Icons.receipt_long_rounded,
                        titulo: 'Sin movimientos este día',
                      )
                    else
                      Card(
                        key: const Key('lista_movimientos'),
                        child: Column(
                          children: [
                            for (final m in movimientos)
                              _MovimientoTile(
                                movimiento: m,
                                nombreUsuario: nombres[m.usuarioId] ?? '',
                              ),
                          ],
                        ),
                      ),
                  ],
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
    final color = esGasto ? ColoresApp.sale : ColoresApp.entra;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esGasto ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Monto(movimiento.monto,
          tamano: 16, tono: esGasto ? TonoMonto.sale : TonoMonto.neutro),
      subtitle: Text('$detalle · $nombreUsuario'),
      trailing: Text(formatoHora(movimiento.fecha),
          style: const TextStyle(color: ColoresApp.textoSecundario)),
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/historial test/screens/home`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/historial test/screens/historial
git commit -m "Redesign Historial with user chips and daily totals"
```

---

### Task 12: Productos y Usuarios con panel "Agregar"

**Files:**
- Modify (reescribir): `lib/screens/configuracion/productos_screen.dart`, `lib/screens/configuracion/usuarios_screen.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`, `test/screens/configuracion/usuarios_screen_test.dart` (ajustes indicados abajo)

**Interfaces:**
- Consumes: `mostrarHojaInferior`, `avisar`, `BotonPrincipal`, `SelectorSegmentado`, `EstadoVacio`, `AvatarInicial`, `etiquetaRol`, `Monto` (Task 2); `parsearMonto`, `esPinValido`; `EditarProductoDialog`, `ResetearPinDialog` (sin cambios).
- Produces: claves nuevas `boton_agregar_producto`, `boton_agregar_usuario`; se conservan `campo_nombre_producto`, `campo_precio_producto`, `boton_crear_producto`, `producto_item_<id>`, `boton_desactivar_<id>`, `producto_inactivo_<id>`, `boton_reactivar_<id>`, `campo_nombre_usuario`, `campo_pin_usuario`, `selector_rol`, `boton_crear_usuario`, `usuario_item_<id>`.

- [ ] **Step 1: Ajustar los tests (fallan)**

En `test/screens/configuracion/productos_screen_test.dart`, reemplazar el test `'crear un producto lo agrega a la lista visible'` por:

```dart
  testWidgets('sin productos muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes productos'), findsOneWidget);
  });

  testWidgets('crear un producto desde el panel lo agrega y lo confirma',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
    expect(find.text('Producto guardado'), findsOneWidget);
  });

  testWidgets('un precio inválido al crear muestra error y no guarda',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.5');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });
```

En `test/screens/configuracion/usuarios_screen_test.dart`, agregar al final de la función `montar` (después de `await tester.pumpAndSettle();`) un helper nuevo justo debajo de ella:

```dart
  Future<void> abrirFormulario(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_agregar_usuario')));
    await tester.pumpAndSettle();
  }
```

y en los tres tests `'crear un usuario sin tocar el rol crea un vendedor'`, `'elegir Administrador en el selector crea un admin'` y `'PIN inválido al crear muestra error y no crea el usuario'`, insertar `await abrirFormulario(tester);` inmediatamente después de `await montar(tester);`. Además, en el primero agregar al final:

```dart
    expect(find.text('Usuario creado'), findsOneWidget);
    expect(find.text('Vendedor'), findsOneWidget);
```

(`'Vendedor'` es la etiqueta del rol en la lista; el panel ya se cerró.)

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/screens/configuracion`
Expected: FAIL — no existen `boton_agregar_producto` ni `boton_agregar_usuario`.

- [ ] **Step 3: Reescribir Productos**

Reemplazar todo `lib/screens/configuracion/productos_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../util/formato_moneda.dart';
import 'editar_producto_dialog.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  Future<void> _agregar() async {
    final guardado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Nuevo producto',
      builder: (_) => const _FormularioProducto(),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  Future<void> _editar(Producto producto) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => EditarProductoDialog(producto: producto),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_producto'),
        onPressed: _agregar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: productosAsync.when(
        data: (productos) {
          if (productos.isEmpty && inactivos.isEmpty) {
            return const EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Aún no tienes productos',
              mensaje: 'Agrega los que más vendes para cobrarlos con un toque',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (productos.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final p in productos)
                        ListTile(
                          key: Key('producto_item_${p.id}'),
                          title: Text(p.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Monto(p.precio, tamano: 15),
                          onTap: () => _editar(p),
                          trailing: IconButton(
                            key: Key('boton_desactivar_${p.id}'),
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .desactivarProducto(p.id),
                          ),
                        ),
                    ],
                  ),
                ),
              if (inactivos.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    'Inactivos',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final p in inactivos)
                        ListTile(
                          key: Key('producto_inactivo_${p.id}'),
                          title: Text(p.nombre,
                              style: const TextStyle(
                                  color: ColoresApp.textoSecundario)),
                          subtitle: Text(formatoMoneda(p.precio)),
                          trailing: TextButton(
                            key: Key('boton_reactivar_${p.id}'),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .reactivarProducto(p.id),
                            child: const Text('Reactivar'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FormularioProducto extends ConsumerStatefulWidget {
  const _FormularioProducto();

  @override
  ConsumerState<_FormularioProducto> createState() =>
      _FormularioProductoState();
}

class _FormularioProductoState extends ConsumerState<_FormularioProducto> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  String? _errorNombre;
  String? _errorPrecio;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          (precio == null || precio <= 0) ? 'Escribe un precio válido' : null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(productoRepositoryProvider)
          .crearProducto(nombre: nombre, precio: precio!);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('campo_nombre_producto'),
          controller: _nombreController,
          autofocus: true,
          decoration: InputDecoration(
              labelText: 'Nombre del producto', errorText: _errorNombre),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_producto'),
          controller: _precioController,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: 'Precio', errorText: _errorPrecio),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_crear_producto'),
          texto: 'Guardar producto',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Reescribir Usuarios**

Reemplazar todo `lib/screens/configuracion/usuarios_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/selector_segmentado.dart';
import '../../util/pin_hash.dart';
import 'resetear_pin_dialog.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  Future<void> _agregar() async {
    final creado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Nuevo usuario',
      builder: (_) => const _FormularioUsuario(),
    );
    if (creado == true && mounted) {
      ref.invalidate(listaUsuariosProvider);
      avisar(context, 'Usuario creado');
    }
  }

  Future<void> _resetearPin(Usuario usuario) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => ResetearPinDialog(usuario: usuario),
    );
    if (actualizado == true && mounted) avisar(context, 'PIN actualizado');
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_usuario'),
        onPressed: _agregar,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Agregar'),
      ),
      body: usuariosAsync.when(
        data: (usuarios) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (usuarios.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (final u in usuarios)
                      ListTile(
                        key: Key('usuario_item_${u.id}'),
                        leading: AvatarInicial(id: u.id, nombre: u.nombre),
                        title: Text(u.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(etiquetaRol(u.rol)),
                        trailing: const Icon(Icons.lock_reset_rounded),
                        onTap: () => _resetearPin(u),
                      ),
                  ],
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FormularioUsuario extends ConsumerStatefulWidget {
  const _FormularioUsuario();

  @override
  ConsumerState<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends ConsumerState<_FormularioUsuario> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String _rol = 'vendedor';
  String? _errorNombre;
  String? _errorPin;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPin = esPinValido(pin) ? null : 'El PIN debe tener 4 dígitos';
    });
    if (_errorNombre != null || _errorPin != null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(usuarioRepositoryProvider)
          .crearUsuario(nombre: nombre, rol: _rol, pin: pin);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('campo_nombre_usuario'),
          controller: _nombreController,
          autofocus: true,
          decoration:
              InputDecoration(labelText: 'Nombre', errorText: _errorNombre),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_pin_usuario'),
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: InputDecoration(
              labelText: 'PIN de 4 dígitos', errorText: _errorPin),
        ),
        const SizedBox(height: 4),
        SelectorSegmentado<String>(
          key: const Key('selector_rol'),
          opciones: const {'vendedor': 'Vendedor', 'admin': 'Administrador'},
          valor: _rol,
          onCambio: (rol) => setState(() => _rol = rol),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_crear_usuario'),
          texto: 'Agregar usuario',
          onPressed: _guardando ? null : _crear,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/configuracion`
Expected: PASS (incluye los tests de doble toque de los diálogos, que no cambian).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/configuracion test/screens/configuracion
git commit -m "Move product and user creation to bottom-sheet forms"
```

---

### Task 13: Pantallas de entrada

**Files:**
- Modify (reescribir): `lib/screens/login/seleccionar_usuario_screen.dart`, `lib/screens/login/ingresar_pin_screen.dart`, `lib/screens/login/crear_admin_inicial_screen.dart`, `lib/widgets/teclado_numerico.dart`
- Test: `test/screens/login/seleccionar_usuario_screen_test.dart` (crear); los existentes de PIN, crear admin y `test/widget_test.dart` deben seguir pasando.

**Interfaces:**
- Consumes: `AvatarInicial`, `etiquetaRol`, `MarcaApp`, `BotonPrincipal` (Task 2); `esPinValido`.
- Produces: mismas claves de hoy (`usuario_<id>`, `tecla_<d>`, `campo_nombre_admin`, `campo_pin_admin`, `boton_crear_admin`).

- [ ] **Step 1: Escribir el test que falla**

Crear `test/screens/login/seleccionar_usuario_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la marca, cada usuario con su inicial y su rol',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SeleccionarUsuarioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Ventas'), findsOneWidget);
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Vendedor'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/screens/login/seleccionar_usuario_screen_test.dart`
Expected: FAIL — no hay marca, ni rol, ni inicial.

- [ ] **Step 3: Reescribir las pantallas de entrada**

Reemplazar todo `lib/screens/login/seleccionar_usuario_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usuarios_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import 'ingresar_pin_screen.dart';

class SeleccionarUsuarioScreen extends ConsumerWidget {
  const SeleccionarUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      body: SafeArea(
        child: usuariosAsync.when(
          data: (usuarios) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const MarcaApp(),
              const SizedBox(height: 32),
              const Text('¿Quién eres?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Toca tu nombre para entrar',
                  style: TextStyle(color: ColoresApp.textoSecundario)),
              const SizedBox(height: 16),
              for (final usuario in usuarios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      key: Key('usuario_${usuario.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: AvatarInicial(
                          id: usuario.id, nombre: usuario.nombre, radio: 22),
                      title: Text(usuario.nombre,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      subtitle: Text(etiquetaRol(usuario.rol)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IngresarPinScreen(usuario: usuario),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
```

Reemplazar todo `lib/screens/login/ingresar_pin_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../widgets/teclado_numerico.dart';

class IngresarPinScreen extends ConsumerStatefulWidget {
  const IngresarPinScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<IngresarPinScreen> createState() => _IngresarPinScreenState();
}

class _IngresarPinScreenState extends ConsumerState<IngresarPinScreen> {
  String _pin = '';
  String? _error;

  Future<void> _validar() async {
    final ok = await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(widget.usuario.id, _pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'PIN incorrecto';
        _pin = '';
      });
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _presionarDigito(String digito) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
    if (_pin.length == 4) _validar();
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AvatarInicial(id: usuario.id, nombre: usuario.nombre, radio: 32),
              const SizedBox(height: 12),
              Text('Hola, ${usuario.nombre}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Ingresa tu PIN',
                  style: TextStyle(color: ColoresApp.textoSecundario)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? ColoresApp.primario
                            : Colors.transparent,
                        border:
                            Border.all(color: ColoresApp.primario, width: 2),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 32,
                child: _error == null
                    ? null
                    : Center(
                        child: Text(_error!,
                            style: const TextStyle(color: ColoresApp.sale)),
                      ),
              ),
              const Spacer(),
              TecladoNumerico(onDigito: _presionarDigito, onBorrar: _borrar),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
```

Reemplazar todo `lib/widgets/teclado_numerico.dart` por:

```dart
import 'package:flutter/material.dart';

import '../ui/colores_app.dart';

/// Teclado del PIN: botones circulares grandes.
class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({
    super.key,
    required this.onDigito,
    required this.onBorrar,
  });

  final void Function(String digito) onDigito;
  final VoidCallback onBorrar;

  static const _filas = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _filas.map((fila) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: fila.map((texto) {
            if (texto.isEmpty) {
              return const SizedBox(width: 88, height: 80);
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ElevatedButton(
                  key: Key('tecla_$texto'),
                  onPressed: () => texto == '⌫' ? onBorrar() : onDigito(texto),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    foregroundColor: ColoresApp.texto,
                  ),
                  child: texto == '⌫'
                      ? const Icon(Icons.backspace_outlined,
                          semanticLabel: 'Borrar')
                      : Text(texto,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
```

Reemplazar todo `lib/screens/login/crear_admin_inicial_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../util/pin_hash.dart';

class CrearAdminInicialScreen extends ConsumerStatefulWidget {
  const CrearAdminInicialScreen({super.key});

  @override
  ConsumerState<CrearAdminInicialScreen> createState() =>
      _CrearAdminInicialScreenState();
}

class _CrearAdminInicialScreenState
    extends ConsumerState<CrearAdminInicialScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    if (!esPinValido(pin)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }

    final repo = ref.read(usuarioRepositoryProvider);
    final id = await repo.crearUsuario(nombre: nombre, rol: 'admin', pin: pin);
    ref.invalidate(listaUsuariosProvider);
    ref.invalidate(haySesionUsuariosProvider);
    await ref.read(sesionProvider.notifier).iniciarSesion(id, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MarcaApp(),
            const SizedBox(height: 32),
            const Text('Configura tu tienda',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Crea el usuario administrador. Con él podrás agregar productos '
              'y vendedores.',
              style: TextStyle(color: ColoresApp.textoSecundario),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_nombre_admin'),
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_pin_admin'),
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: const TextStyle(color: ColoresApp.sale)),
              ),
            const SizedBox(height: 8),
            BotonPrincipal(
              key: const Key('boton_crear_admin'),
              texto: 'Crear tienda',
              onPressed: _crear,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/screens/login test/widget_test.dart test/widgets`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login lib/widgets/teclado_numerico.dart test/screens/login
git commit -m "Redesign sign-in screens with brand, avatars, and role labels"
```

---

### Task 14: Cierre — README, suite completa y verificación visual

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md` (`**Estado:**`)

- [ ] **Step 1: Actualizar la documentación**

En `README.md`, dentro de la sección `## Fase 2`, agregar después del ítem de 2A:

```markdown
- **2E — Experiencia de usuario y diseño visual** (hecho): sistema visual
  "claro y confiable" (`lib/ui/`), venta tipo ticket con "Cobrar" y Deshacer,
  Inicio con tarjetas de ventas/gastos/ganancia/por cobrar, avisos de
  confirmación y estados vacíos en todas las pantallas.
```

En el spec, cambiar `**Estado:** Borrador para revisión` por `**Estado:** Implementado`.

- [ ] **Step 2: Análisis estático y suite completa**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y `All tests passed!`.

- [ ] **Step 3: Verificación visual en el emulador**

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Recorrer y capturar (`adb exec-out screencap -p > <archivo>.png`) cada pantalla: ¿Quién eres?, PIN, Inicio, Nueva venta (contado, fiado con cliente, ticket abierto, otro monto), aviso "Venta registrada · Deshacer", Nuevo gasto, Fiado (lista y detalle con panel de abono), Historial, Ajustes, Productos (panel Agregar), Usuarios. Revisar en cada captura: sin desbordes, textos legibles, montos con el color correcto, un solo encabezado.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-05-app-ventas-fase2e-ux-design.md
git commit -m "Document Fase 2E completion"
```
