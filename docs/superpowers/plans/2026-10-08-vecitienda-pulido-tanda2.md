# Pulido Tanda 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Textos que no se parten con letra grande y los detalles visuales pendientes de la marca VeciTienda.

**Architecture:** Ajustes de layout en tres widgets (anchos escalados, altura de barra,
`OverflowBar`), un color nuevo en `ColoresApp`, una prueba guardia de fuentes y mejoras al
script `tool/generar_iconos.py` que regenera isotipo e íconos (incluido el monocromo).

**Tech Stack:** Flutter, Riverpod 2, flutter_test; Python 3 + Pillow 12 para el script.

**Spec:** `docs/superpowers/specs/2026-10-08-vecitienda-pulido-tanda2-design.md`

## Global Constraints

- Sin cambios de base de datos ni dependencias nuevas en la app.
- Colores siempre desde `ColoresApp`; títulos de marca siempre con `estiloTitulo`.
- Pruebas de letra grande con `tester.platformDispatcher.textScaleFactorTestValue = 2` y
  `addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue)`.
- Tests primero; `flutter test` verde, `flutter analyze` sin problemas, APK compila.
- Rama: `pulido-tanda2` desde `master`.

## Review Focus

- Letra al 130 % (no solo 200 %): las barras y el encabezado se ven bien, sin huecos raros — Task 1/2.
- Encabezado de Inicio con nombre de tienda vacío (aún sin configurar): sin altura de más que rompa — Task 2.
- Pantalla angosta (360 dp) con letra normal: el grupo "Por pedir" sigue en una fila — Task 3.
- Logo nuevo sin franja vacía clara: el script se detiene con mensaje, no genera íconos cortados — Task 6.
- El isotipo regenerado conserva el mismo encuadre que el anterior (corte cerca del 59 %) — Task 6.

---

### Task 1: Barras de Reportes con letra grande

**Files:**
- Modify: `lib/screens/reportes/barras_por_dia.dart` (`Barra.build`)
- Test: `test/screens/reportes/barras_por_dia_test.dart`

- [ ] **Step 1: Write the failing test** (al final de `main()`):

```dart
  testWidgets('con letra grande la etiqueta y el monto van en una línea',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Barra(
          etiqueta: '10 a. m.',
          valor: 1250000,
          fraccion: 0.5,
          resaltada: false,
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final alto = tester.getSize(find.text('10 a. m.')).height;
    expect(tester.getSize(find.text(r'$1.250.000')).height, alto);
    expect(alto, lessThan(50)); // una línea de 14 px al 200 %
  });
```

- [ ] **Step 2: Run** `flutter test test/screens/reportes/barras_por_dia_test.dart` — Expected: FAIL (alto de dos o más líneas).

- [ ] **Step 3: Implement.** En `Barra.build`:

```dart
  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: escala.scale(64),
            child: Text(etiqueta, maxLines: 1, softWrap: false),
          ),
          Expanded(
            ... // sin cambios
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: escala.scale(84),
            child: Text(
              formatoMoneda(valor),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run** `flutter test test/screens/reportes/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Keep report bar labels and amounts on one line with large text"`.

---

### Task 2: Encabezado azul de Inicio — altura con letra grande y sin línea gris

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (`AppBar` del `build`)
- Test: `test/screens/home/home_screen_test.dart`

- [ ] **Step 1: Write the failing tests**:

```dart
  testWidgets('con letra grande la barra azul crece y no desborda',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await montar(tester);

    expect(tester.takeException(), isNull);
    final barra = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(barra.toolbarHeight, greaterThan(kToolbarHeight));
  });

  testWidgets('la barra azul no tiene la línea gris de abajo', (tester) async {
    await montar(tester);
    AppBar barra() => tester.widget<AppBar>(find.byType(AppBar).first);

    expect(barra().shape, const Border());
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(barra().shape, isNull); // las demás usan el borde del tema
  });
```

- [ ] **Step 2: Run** `flutter test test/screens/home/home_screen_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement.** Importar `dart:math` como `math`. Antes del `return Scaffold(`:

```dart
    final escala = MediaQuery.textScalerOf(context);
```

En el `AppBar`:

```dart
        toolbarHeight: esInicio
            ? math.max(
                kToolbarHeight,
                escala.scale(20) * 1.3 + escala.scale(12) * 1.3 + 16,
              )
            : null,
        // Sin la línea gris del tema bajo el azul.
        shape: esInicio ? const Border() : null,
```

y el texto del saludo con `maxLines: 1,` junto al `overflow: TextOverflow.ellipsis` existente
(`NombreTienda` ya usa `maxLines: 1`).

- [ ] **Step 4: Run** `flutter test test/screens/home/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Grow the blue header with large text and drop its grey hairline"`.

---

### Task 3: Grupo de "Por pedir" con letra grande

**Files:**
- Modify: `lib/screens/inventario/inventario_screen.dart` (encabezado de cada grupo)
- Test: `test/screens/inventario/inventario_screen_test.dart`

- [ ] **Step 1: Write the failing test**. Revisar al inicio del archivo cómo los tests existentes
crean un producto con control bajo el mínimo (helpers `montar`, `pintar`, `producto`); usar el
mismo patrón:

```dart
  testWidgets('con letra grande el botón del pedido baja y el grupo no se parte',
      (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final coca = await producto('Coca', proveedor: postobon);
    await InventarioRepository(db)
        .activarControl(coca, cantidad: 1, minimo: 5, por: ana);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pintar(tester, container);

    expect(tester.takeException(), isNull);
    final grupo = find.byKey(Key('grupo_por_pedir_$postobon'));
    expect(tester.getSize(grupo).height, lessThan(50)); // una línea
    expect(tester.getTopLeft(find.byKey(Key('ver_pedido_$postobon'))).dy,
        greaterThan(tester.getTopLeft(grupo).dy));
  });

  testWidgets('con letra normal el grupo y el botón van en una fila',
      (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final coca = await producto('Coca', proveedor: postobon);
    await InventarioRepository(db)
        .activarControl(coca, cantidad: 1, minimo: 5, por: ana);
    await pintar(tester, container);

    final grupo = tester.getCenter(find.byKey(Key('grupo_por_pedir_$postobon')));
    final boton = tester.getCenter(find.byKey(Key('ver_pedido_$postobon')));
    expect((grupo.dy - boton.dy).abs(), lessThan(8));
  });
```

(Agregar los imports de `inventario_repository.dart` / `proveedor_repository.dart` si faltan.)

- [ ] **Step 2: Run** `flutter test test/screens/inventario/inventario_screen_test.dart` — Expected: el de letra grande FAIL.

- [ ] **Step 3: Implement.** Reemplazar el `Row` del encabezado del grupo:

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
                // Si no caben, el botón baja a su propia línea a la derecha.
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    Text(
                      '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                      '${plural(g.productos.length, 'producto', 'productos')}',
                      key: Key('grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      key: Key('ver_pedido_${g.proveedor?.id ?? 'sin'}'),
                      onPressed: () => _verPedido(g.proveedor),
                      child: const Text('Ver pedido sugerido'),
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 4: Run** `flutter test test/screens/inventario/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Let the suggested-order button wrap below its group with large text"`.

---

### Task 4: Título del PIN en Nunito y guardia de la fuente

**Files:**
- Modify: `lib/screens/login/ingresar_pin_screen.dart:81-87`
- Test: `test/screens/login/ingresar_pin_screen_test.dart`, `test/ui/tema_app_test.dart`

- [ ] **Step 1: Write the failing tests.** En `tema_app_test.dart`:

```dart
  test('Nunito solo se usa a través de estiloTitulo', () {
    final fuera = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (ruta.endsWith('lib/ui/tipografia.dart')) continue;
      final texto = archivo.readAsStringSync();
      if (texto.contains("'Nunito'") || texto.contains('familiaTitulos')) {
        fuera.add(ruta);
      }
    }
    expect(fuera, isEmpty,
        reason: 'Sin el eje wght la fuente variable sale con peso 200');
  });
```

En `ingresar_pin_screen_test.dart`, dentro del primer test, después de `pumpWidget`:

```dart
    expect(tester.widget<Text>(find.text('Hola, Ana')).style?.fontFamily,
        'Nunito');
```

- [ ] **Step 2: Run** `flutter test test/ui/tema_app_test.dart test/screens/login/ingresar_pin_screen_test.dart` — Expected: el de PIN FAIL; la guardia PASA ya hoy (es una protección: verificar que falla agregando temporalmente `const x = 'Nunito';` a un archivo de `lib/`, correrla, ver FAIL y quitarlo).

- [ ] **Step 3: Implement.** Importar `'../../ui/tipografia.dart'` y:

```dart
                    Text(
                      'Hola, ${usuario.nombre}',
                      style: estiloTitulo(tamano: 22),
                    ),
```

- [ ] **Step 4: Run** `flutter test test/ui/ test/screens/login/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Use the brand title font on the PIN screen and guard Nunito usage"`.

---

### Task 5: Azul claro de marca

**Files:**
- Modify: `lib/ui/colores_app.dart`, `lib/ui/tema_app.dart:102`, `lib/ui/estado_vacio.dart:32`
- Test: `test/ui/tema_app_test.dart`, `test/ui/componentes_test.dart`

**Interfaces:** Produces `ColoresApp.primarioSuave` (`Color(0xFFDDE5F0)`).

- [ ] **Step 1: Write the failing tests.** En `tema_app_test.dart`:

```dart
  test('los tonos claros salen del azul de marca', () {
    expect(ColoresApp.primarioSuave, const Color(0xFFDDE5F0));
    expect(temaApp().navigationBarTheme.indicatorColor,
        ColoresApp.primarioSuave);
    expect(contraste(ColoresApp.primario, ColoresApp.primarioSuave),
        greaterThanOrEqualTo(4.5));
  });
```

En `componentes_test.dart` (importar `estado_vacio.dart` y `colores_app.dart` si faltan):

```dart
  testWidgets('el círculo del estado vacío usa el azul claro de marca',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: EstadoVacio(icono: Icons.inbox_outlined, titulo: 'Nada')),
    ));
    final circulo = tester.widget<Container>(find.ancestor(
        of: find.byIcon(Icons.inbox_outlined),
        matching: find.byType(Container)).first);
    expect((circulo.decoration! as BoxDecoration).color,
        ColoresApp.primarioSuave);
  });
```

- [ ] **Step 2: Run** `flutter test test/ui/` — Expected: FAIL (`primarioSuave` no existe).

- [ ] **Step 3: Implement.** En `ColoresApp`, después de `primario`:

```dart
  /// Azul de marca al 15 % sobre blanco: fondos de selección y de íconos.
  static const primarioSuave = Color(0xFFDDE5F0);
```

`tema_app.dart`: `indicatorColor: ColoresApp.primarioSuave,` (quitar `const`/`Color(0xFFDBE4FF)`).
`estado_vacio.dart`: `color: ColoresApp.primarioSuave,`.

- [ ] **Step 4: Run** `flutter test test/ui/ test/screens/` — Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Replace old navy tints with a light brand blue"`.

---

### Task 6: Script de íconos — corte automático, sin halo y monocromo

**Files:**
- Modify: `tool/generar_iconos.py`
- Regenerate: `assets/marca/isotipo.png`, `android/app/src/main/res/mipmap-*/ic_launcher*.png`, `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Test: `test/marca/recursos_marca_test.dart`

- [ ] **Step 1: Write the failing test.** En `recursos_marca_test.dart`, dentro de
`'hay íconos del lanzador clásicos y adaptativos en cada densidad'`, en el `forEach`:

```dart
      expect(cabeceraPng('$carpeta/ic_launcher_monochrome.png').ancho,
          lado * 108 ~/ 48,
          reason: densidad);
```

y al final del test: `expect(adaptativo, contains('@mipmap/ic_launcher_monochrome'));`.

- [ ] **Step 2: Run** `flutter test test/marca/recursos_marca_test.dart` — Expected: FAIL (no existe el monocromo).

- [ ] **Step 3: Implement** en `tool/generar_iconos.py`:

Quitar `FIN_ISOTIPO` y su comentario; agregar:

```python
# Banda vacía mínima (fracción de la altura) que separa el isotipo del nombre.
BANDA_MINIMA = 0.01


def fin_isotipo(rgb):
    """Fila donde termina el isotipo: el inicio de la primera banda sin tinta
    (≥ BANDA_MINIMA de la altura) que sigue a la primera fila con tinta y
    antes de que vuelva la tinta (el nombre "VeciTienda")."""
    tinta = rgb.convert("L").point(lambda v: 255 if v < 235 else 0)
    banda = max(1, int(tinta.height * BANDA_MINIMA))
    vista = False
    vacias = 0
    for y in range(tinta.height):
        con_tinta = tinta.crop((0, y, tinta.width, y + 1)).getbbox() is not None
        if con_tinta:
            if vista and vacias >= banda:
                return y - vacias
            vista = True
            vacias = 0
        elif vista:
            vacias += 1
    raise SystemExit(
        "No encontré el espacio entre el isotipo y el nombre en el logo; "
        "revisa docs/marca/logo-vecitienda.jpeg"
    )
```

En `recortar_isotipo`: `franja = rgb.crop((0, 0, rgb.width, fin_isotipo(rgb)))` y cambiar la
línea de `putdata` por:

```python
    isotipo.putdata([_sin_fondo(r, g, b) for (r, g, b, _) in pixeles])
```

con

```python
def _sin_fondo(r, g, b):
    """Color y alfa de un píxel sobre blanco. En los bordes semitransparentes
    se quita el blanco mezclado, para que no quede un halo claro."""
    a = _alfa(r, g, b)
    if a in (0, 255):
        return (r, g, b, a)
    f = a / 255
    canal = lambda c: max(0, min(255, round((c - 255 * (1 - f)) / f)))
    return (canal(r), canal(g), canal(b), a)


def monocromo(capa):
    """Silueta blanca con el alfa de [capa] (ícono temático de Android 13+)."""
    silueta = Image.new("RGBA", capa.size, (255, 255, 255, 0))
    silueta.putalpha(capa.getchannel("A"))
    return silueta
```

`XML_ADAPTATIVO` agrega, después de la línea `foreground`:

```xml
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
```

En `main`, dentro del `for`:

```python
        frente = primer_plano(isotipo, int(108 * escala))
        frente.save(carpeta / "ic_launcher_foreground.png")
        monocromo(frente).save(carpeta / "ic_launcher_monochrome.png")
```

(reemplazando el `primer_plano(...).save(...)` anterior) y antes del `print` final:

```python
    print(f"Isotipo cortado en la fila {fin_isotipo(Image.open(LOGO).convert('RGB'))}")
```

- [ ] **Step 4: Run el script y revisar.**

Run: `python tool/generar_iconos.py`
Expected: `Isotipo cortado en la fila N` con N entre 0,55 y 0,62 de 1536 (≈ 845–952) e
`Isotipo e íconos generados`. Abrir `assets/marca/isotipo.png` y
`mipmap-xxxhdpi/ic_launcher_monochrome.png` y revisar: isotipo completo sin texto debajo, sin
borde claro; silueta blanca. Si N sale fuera de rango, revisar el logo antes de seguir.

- [ ] **Step 5: Run** `flutter test test/marca/` — Expected: PASS.
- [ ] **Step 6: Commit**

```bash
git add tool/generar_iconos.py assets/marca/isotipo.png android/app/src/main/res test/marca/recursos_marca_test.dart
git commit -m "Cut the logo automatically, remove the edge halo and add a monochrome icon"
```

---

### Task 7: Verificación final y documentos

- [ ] **Step 1:** `flutter analyze` → `No issues found!`; `flutter test` → todas pasan;
  `flutter build apk --debug` → `Built ...app-debug.apk`.
- [ ] **Step 2:** Spec: `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
  `docs/hoja-de-ruta.md`: en "Hecho" agregar `- Pulido, tanda 2 — letra grande y detalles de la marca.`;
  "En curso": `- Pulido, tanda 3 (mejoras internas).`; quitar de "Siguiente" la línea de la
  tanda 2; en "Pendiente de verificar" agregar ", pulido tanda 2 (incluido el ícono temático en
  Android 13+)". En `docs/marca/vecitienda-marca.md`, si lista los 7 detalles pendientes, marcarlos
  hechos.
- [ ] **Step 3: Commit** `git commit -m "Mark polish batch 2 as implemented"`.
