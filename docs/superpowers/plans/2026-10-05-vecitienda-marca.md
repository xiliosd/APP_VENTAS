# VeciTienda — aplicar la marca · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Renombrar la app a VeciTienda y aplicar su identidad (isotipo, íconos Android, paleta, Nunito en títulos, botones de radio 16, header azul en Inicio, bordes de tarjetas) cumpliendo contraste ≥ 4.5:1 en texto.

**Architecture:** Un script Python reproducible genera el isotipo y los íconos Android desde el JPEG del logo. Los tokens de `ColoresApp`, el tema central y un helper de tipografía (`estiloTitulo`) concentran el cambio visual; las pantallas solo usan esos componentes. El paquete Android y el de Dart no cambian.

**Tech Stack:** Flutter 3.47, Python 3 + Pillow 12 (solo herramienta), Nunito variable (OFL).

**Spec:** `docs/superpowers/specs/2026-10-05-vecitienda-marca-design.md`

## Global Constraints

- Nombre visible "VeciTienda"; slogan exacto: "La tranquilidad de tu tienda, en tu bolsillo."
- No cambiar `applicationId` (`com.appventas.app_ventas`) ni el paquete Dart `app_ventas`.
- Colores: `primario #1A539B`, `marcaVerde #16A34A` (solo gráficos/acentos, nunca texto), `entra #15803D`, `fondo #F8FAFC`, `texto #1E293B`, `sale #DC2626`, `entraSuave #BBF7D0`, `saleSuave #FECACA`; el resto de tokens sin cambio.
- Contraste: todo par de texto ≥ 4.5:1; `marcaVerde` sobre blanco ≥ 3:1.
- Títulos en Nunito peso 800 (fuente variable `assets/fonts/Nunito-Variable.ttf`, el peso se fija con `FontVariation('wght', 800)`); cuerpo y números siguen en Inter.
- Botones (`FilledButton`, `OutlinedButton`) radio 16; tarjetas, campos y mosaicos radio 12.
- Header azul solo en la pestaña Inicio.
- Sin dependencias nuevas de la app. Pillow es solo para `tool/generar_iconos.py`.
- Textos al usuario en español. Commits en inglés imperativo, terminando con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Recorte del isotipo**: no debe incluir parte del nombre "VeciTienda" ni cortar la flecha o el toldo. → Task 1 (revisión visual de `isotipo.png` y del ícono).
2. **Barra azul del Inicio**: título, flecha atrás y avatar de la cuenta deben verse en blanco sobre azul. → Task 4 (prueba de `foregroundColor`).
3. **Nombre de usuario largo en la barra azul con la insignia** (360 dp): sin desbordes. → Task 4.
4. **Nunito sin peso aplicado** (se vería delgada): el estilo debe llevar `fontVariations`. → Task 2 (prueba del estilo) y Task 5 (captura).
5. **Texto secundario sobre el fondo nuevo** `#F8FAFC`: sigue ≥ 4.5:1. → Task 2.

---

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `tool/generar_iconos.py` | Crear | Isotipo e íconos Android desde el logo |
| `assets/marca/isotipo.png` | Generar | Isotipo para la app |
| `android/app/src/main/res/mipmap-*/ic_launcher*.png`, `mipmap-anydpi-v26/ic_launcher.xml`, `values/ic_launcher_background.xml` | Generar | Íconos del lanzador |
| `android/app/src/main/AndroidManifest.xml` | Modificar | `android:label="VeciTienda"` |
| `lib/main.dart` | Modificar | `title: 'VeciTienda'` |
| `pubspec.yaml` | Modificar | Asset `assets/marca/` y fuente Nunito |
| `assets/fonts/Nunito-Variable.ttf`, `assets/fonts/OFL-Nunito.txt` | Crear | Fuente de títulos |
| `lib/ui/colores_app.dart` | Modificar | Paleta VeciTienda |
| `lib/ui/tipografia.dart` | Crear | `estiloTitulo(...)` |
| `lib/ui/tema_app.dart` | Modificar | Botones radio 16, títulos de AppBar en Nunito |
| `lib/ui/marca_app.dart` | Reescribir | Isotipo + nombre (+ slogan) |
| `lib/screens/login/*.dart` | Modificar | Títulos con `estiloTitulo`; slogan en Bienvenida |
| `lib/ui/tarjeta_monto.dart` | Modificar | Parámetro `colorBorde` |
| `lib/screens/home/home_screen.dart` | Modificar | Barra azul con insignia en Inicio |
| `lib/screens/home/resumen_screen.dart` | Modificar | Bordes de Gastos/Ganancia |
| `README.md` | Modificar | Nombre del proyecto |

---

### Task 1: Nombre e íconos

**Files:**
- Create: `tool/generar_iconos.py`, `test/marca/recursos_marca_test.dart`
- Generate: `assets/marca/isotipo.png`, íconos en `android/app/src/main/res/`
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`

**Interfaces:**
- Produces: asset `assets/marca/isotipo.png` (512×512 RGBA) declarado en `pubspec.yaml`; `MaterialApp.title == 'VeciTienda'`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/marca/recursos_marca_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ancho, alto y tipo de color (6 = RGBA) de un PNG, leídos de su cabecera.
({int ancho, int alto, int tipoColor}) cabeceraPng(String ruta) {
  final bytes = File(ruta).readAsBytesSync();
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: ruta);
  final datos = ByteData.sublistView(bytes);
  return (
    ancho: datos.getUint32(16),
    alto: datos.getUint32(20),
    tipoColor: bytes[25],
  );
}

void main() {
  test('el isotipo es cuadrado, de 512 px y con transparencia', () {
    final cabecera = cabeceraPng('assets/marca/isotipo.png');
    expect(cabecera.ancho, 512);
    expect(cabecera.alto, 512);
    expect(cabecera.tipoColor, 6);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/marca/'));
  });

  test('hay íconos del lanzador clásicos y adaptativos en cada densidad', () {
    const lados = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    lados.forEach((densidad, lado) {
      final carpeta = 'android/app/src/main/res/mipmap-$densidad';
      expect(cabeceraPng('$carpeta/ic_launcher.png').ancho, lado,
          reason: densidad);
      expect(cabeceraPng('$carpeta/ic_launcher_foreground.png').ancho,
          lado * 108 ~/ 48,
          reason: densidad);
    });
    final adaptativo = File(
            'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(adaptativo, contains('@mipmap/ic_launcher_foreground'));
    expect(adaptativo, contains('@color/ic_launcher_background'));
  });

  test('Android muestra el nombre VeciTienda', () {
    expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:label="VeciTienda"'));
  });

  testWidgets('la app se llama VeciTienda', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const AppVentas(),
    ));

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'VeciTienda');
  });
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/marca/recursos_marca_test.dart`
Expected: FAIL — falta `isotipo.png`, los `ic_launcher_foreground.png`, el label y el título.

- [ ] **Step 3: Crear el script**

Crear `tool/generar_iconos.py`:

```python
"""Genera el isotipo y los íconos Android de VeciTienda a partir del logo.

Uso, desde la raíz del repositorio:
    python tool/generar_iconos.py

Requiere Pillow (pip install pillow). No es dependencia de la app: si llega
una versión mejor del logo, se reemplaza docs/marca/logo-vecitienda.jpeg y se
vuelve a correr.
"""
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
LOGO = RAIZ / "docs" / "marca" / "logo-vecitienda.jpeg"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"
DENSIDADES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# El isotipo ocupa la franja superior del logo; el nombre "VeciTienda"
# empieza más abajo (~62 % de la altura). Se corta antes, al 59 %.
FIN_ISOTIPO = 0.59

XML_ADAPTATIVO = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

XML_COLOR = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""


def recortar_isotipo(logo):
    """Recorta el isotipo, vuelve transparente el blanco y lo deja cuadrado."""
    rgb = logo.convert("RGB")
    franja = rgb.crop((0, 0, rgb.width, int(rgb.height * FIN_ISOTIPO)))
    tinta = franja.convert("L").point(lambda v: 255 if v < 235 else 0)
    isotipo = franja.crop(tinta.getbbox()).convert("RGBA")
    isotipo.putdata([(r, g, b, _alfa(r, g, b)) for (r, g, b, _) in isotipo.getdata()])
    return _cuadrar(isotipo)


def _alfa(r, g, b):
    """Opaco para la tinta, transparente para el blanco, suave en los bordes."""
    luz = (r + g + b) / 3
    if luz >= 245:
        return 0
    if luz <= 200:
        return 255
    return int((245 - luz) / 45 * 255)


def _cuadrar(imagen, margen=0.08):
    lado = int(max(imagen.size) * (1 + 2 * margen))
    lienzo = Image.new("RGBA", (lado, lado), (255, 255, 255, 0))
    lienzo.alpha_composite(
        imagen, ((lado - imagen.width) // 2, (lado - imagen.height) // 2)
    )
    return lienzo


def _centrado(isotipo, lado, proporcion):
    lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    interior = int(lado * proporcion)
    logo = isotipo.resize((interior, interior), Image.LANCZOS)
    lienzo.alpha_composite(logo, ((lado - interior) // 2, (lado - interior) // 2))
    return lienzo


def icono_clasico(isotipo, lado):
    """Isotipo sobre un cuadrado blanco redondeado (Android anterior a 8)."""
    fondo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    ImageDraw.Draw(fondo).rounded_rectangle(
        (0, 0, lado - 1, lado - 1), radius=lado // 5, fill=(255, 255, 255, 255)
    )
    fondo.alpha_composite(_centrado(isotipo, lado, 0.84))
    return fondo


def primer_plano(isotipo, lado):
    """Capa frontal del ícono adaptativo: isotipo dentro de la zona segura
    (66 dp de 108 dp)."""
    return _centrado(isotipo, lado, 66 / 108)


def main():
    isotipo = recortar_isotipo(Image.open(LOGO))

    destino = RAIZ / "assets" / "marca"
    destino.mkdir(parents=True, exist_ok=True)
    isotipo.resize((512, 512), Image.LANCZOS).save(destino / "isotipo.png")

    for nombre, escala in DENSIDADES.items():
        carpeta = RES / f"mipmap-{nombre}"
        carpeta.mkdir(exist_ok=True)
        icono_clasico(isotipo, int(48 * escala)).save(carpeta / "ic_launcher.png")
        primer_plano(isotipo, int(108 * escala)).save(
            carpeta / "ic_launcher_foreground.png"
        )

    adaptativo = RES / "mipmap-anydpi-v26"
    adaptativo.mkdir(exist_ok=True)
    (adaptativo / "ic_launcher.xml").write_text(XML_ADAPTATIVO, encoding="utf-8")
    (RES / "values" / "ic_launcher_background.xml").write_text(
        XML_COLOR, encoding="utf-8"
    )
    print("Isotipo e íconos generados")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Generar y revisar a ojo**

Run: `python tool/generar_iconos.py`
Expected: `Isotipo e íconos generados`.

Abrir `assets/marca/isotipo.png` y `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (con la herramienta de lectura de imágenes) y verificar: toldo verde completo, casita azul completa, flecha verde completa, **sin** letras del nombre. Si el recorte toca el nombre o corta la figura, ajustar `FIN_ISOTIPO` y volver a correr.

- [ ] **Step 5: Nombre y declaración del asset**

En `pubspec.yaml`, bajo `flutter:`, después de `  uses-material-design: true`, agregar:

```yaml

  assets:
    - assets/marca/
```

En `android/app/src/main/AndroidManifest.xml`, cambiar `android:label="app_ventas"` por `android:label="VeciTienda"`.

En `lib/main.dart`, cambiar `title: 'App Ventas',` por `title: 'VeciTienda',`.

- [ ] **Step 6: Correr y verificar que pasan**

Run: `flutter test test/marca && flutter analyze`
Expected: PASS (4 tests) y `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add tool/generar_iconos.py assets/marca android/app/src/main/res android/app/src/main/AndroidManifest.xml pubspec.yaml lib/main.dart test/marca
git commit -m "Rename the app to VeciTienda and generate its icons from the logo"
```

---

### Task 2: Paleta, Nunito y tema

**Files:**
- Create: `lib/ui/tipografia.dart`, `assets/fonts/Nunito-Variable.ttf`, `assets/fonts/OFL-Nunito.txt`
- Modify: `lib/ui/colores_app.dart`, `lib/ui/tema_app.dart`, `pubspec.yaml`
- Test: `test/ui/tema_app_test.dart`

**Interfaces:**
- Produces: `ColoresApp.marcaVerde`, `ColoresApp.entraSuave`, `ColoresApp.saleSuave` (nuevos) y valores nuevos de `primario`, `fondo`, `texto`; `const familiaTitulos = 'Nunito'`; `TextStyle estiloTitulo({double tamano = 24, Color color = ColoresApp.texto})` (Nunito, w800, `FontVariation('wght', 800)`).

- [ ] **Step 1: Descargar Nunito**

```bash
curl -L -o assets/fonts/Nunito-Variable.ttf "https://raw.githubusercontent.com/googlefonts/nunito/main/fonts/variable/Nunito%5Bwght%5D.ttf"
curl -L -o assets/fonts/OFL-Nunito.txt "https://raw.githubusercontent.com/googlefonts/nunito/main/OFL.txt"
ls -la assets/fonts/Nunito-Variable.ttf assets/fonts/OFL-Nunito.txt
```

Expected: el `.ttf` pesa cientos de KB; el `OFL-Nunito.txt` contiene "SIL Open Font License". Si la URL de la licencia da 404, usar `https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/OFL.txt`.

- [ ] **Step 2: Escribir los tests que fallan**

En `test/ui/tema_app_test.dart`:

1. Agregar el import `import 'package:app_ventas/ui/tipografia.dart';`.
2. En el mapa `pares` del test de contraste, agregar:

```dart
      'texto/superficie': (ColoresApp.texto, ColoresApp.superficie),
```

3. Agregar dentro de `main()`:

```dart
  test('la paleta es la de VeciTienda', () {
    expect(ColoresApp.primario, const Color(0xFF1A539B));
    expect(ColoresApp.marcaVerde, const Color(0xFF16A34A));
    expect(ColoresApp.fondo, const Color(0xFFF8FAFC));
    expect(ColoresApp.texto, const Color(0xFF1E293B));
    expect(ColoresApp.entraSuave, const Color(0xFFBBF7D0));
    expect(ColoresApp.saleSuave, const Color(0xFFFECACA));
  });

  test('el verde de marca solo se usa en gráficos: ≥ 3:1 sobre blanco', () {
    expect(contraste(ColoresApp.marcaVerde, ColoresApp.superficie),
        greaterThanOrEqualTo(3));
  });

  test('los títulos usan Nunito ExtraBold con el eje de peso fijado', () {
    final estilo = estiloTitulo(tamano: 20);
    expect(estilo.fontFamily, 'Nunito');
    expect(estilo.fontWeight, FontWeight.w800);
    expect(estilo.fontVariations, const [FontVariation('wght', 800)]);
    expect(temaApp().appBarTheme.titleTextStyle!.fontFamily, 'Nunito');
    expect(File('assets/fonts/Nunito-Variable.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('family: Nunito'));
  });

  test('los botones principales tienen radio 16', () {
    final forma = temaApp().filledButtonTheme.style!.shape!.resolve({})!
        as RoundedRectangleBorder;
    expect(forma.borderRadius, BorderRadius.circular(16));
  });
```

- [ ] **Step 3: Correr y verificar que fallan**

Run: `flutter test test/ui/tema_app_test.dart`
Expected: FAIL — `tipografia.dart` no existe; colores y radio distintos.

- [ ] **Step 4: Implementar**

En `lib/ui/colores_app.dart`:
- `primario` → `Color(0xFF1A539B)`; `fondo` → `Color(0xFFF8FAFC)`; `texto` → `Color(0xFF1E293B)`.
- Agregar, después de `primario`:

```dart
  /// Verde de la marca (logo, íconos, bordes, acentos). **Nunca para texto**:
  /// sobre blanco da 3.1:1; para texto y botones con texto blanco usar
  /// [entra].
  static const marcaVerde = Color(0xFF16A34A);
```

- Agregar, después de `entra`:

```dart
  /// Borde claro de tarjetas de ingresos/ganancia.
  static const entraSuave = Color(0xFFBBF7D0);
```

- Agregar, después de `sale`:

```dart
  /// Borde claro de tarjetas de gastos.
  static const saleSuave = Color(0xFFFECACA);
```

Crear `lib/ui/tipografia.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Familia de los títulos de marca. Es una fuente variable: el peso se fija
/// con el eje `wght` (sin él se vería con el peso por defecto).
const familiaTitulos = 'Nunito';

/// Títulos de marca: Nunito ExtraBold.
TextStyle estiloTitulo({double tamano = 24, Color color = ColoresApp.texto}) {
  return TextStyle(
    fontFamily: familiaTitulos,
    fontSize: tamano,
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 800)],
    color: color,
  );
}
```

En `lib/ui/tema_app.dart`:
1. Agregar `import 'tipografia.dart';`.
2. Después de la declaración de `redondeado`, agregar:

```dart
  final redondeadoBoton =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
```

3. En `filledButtonTheme` y `outlinedButtonTheme`, cambiar `shape: redondeado,` por `shape: redondeadoBoton,`.
4. En `appBarTheme`, quitar el `const` de `AppBarTheme(` y reemplazar el bloque `titleTextStyle: TextStyle(...)` completo por:

```dart
      titleTextStyle: estiloTitulo(tamano: 20),
```

(Las demás propiedades de `AppBarTheme` siguen iguales; deben quedar como `const` donde lo permitan.)

En `pubspec.yaml`, dentro de `fonts:` (después del bloque de Inter), agregar:

```yaml
    - family: Nunito
      fonts:
        - asset: assets/fonts/Nunito-Variable.ttf
```

- [ ] **Step 5: Correr y verificar que pasan**

Run: `flutter pub get && flutter test test/ui && flutter test && flutter analyze`
Expected: PASS en todo y `No issues found!`. Si alguna prueba de pantalla compara colores viejos, ajustarla a los tokens (no a hex sueltos).

- [ ] **Step 6: Commit**

```bash
git add lib/ui assets/fonts pubspec.yaml test/ui
git commit -m "Apply VeciTienda palette, Nunito titles, and 16px button radius"
```

---

### Task 3: Marca en las pantallas de entrada

**Files:**
- Modify (reescribir): `lib/ui/marca_app.dart`
- Modify: `lib/screens/login/bienvenida_screen.dart`, `lib/screens/login/seleccionar_usuario_screen.dart`, `lib/screens/login/crear_admin_inicial_screen.dart`
- Test: `test/screens/login/bienvenida_screen_test.dart`, `test/screens/login/seleccionar_usuario_screen_test.dart`

**Interfaces:**
- Consumes: `estiloTitulo` (Task 2), asset `assets/marca/isotipo.png` (Task 1).
- Produces: `MarcaApp({bool conSlogan = false})` con `static const slogan`; clave `isotipo_marca`.

- [ ] **Step 1: Escribir los tests que fallan**

En `test/screens/login/bienvenida_screen_test.dart`, dentro del test `'sin respaldo configurado solo ofrece crear la tienda'`, agregar al final:

```dart
    expect(find.text('VeciTienda'), findsOneWidget);
    expect(find.text('La tranquilidad de tu tienda, en tu bolsillo.'),
        findsOneWidget);
    expect(find.byKey(const Key('isotipo_marca')), findsOneWidget);
```

En `test/screens/login/seleccionar_usuario_screen_test.dart`, cambiar `expect(find.text('App Ventas'), findsOneWidget);` por:

```dart
    expect(find.text('VeciTienda'), findsOneWidget);
    expect(find.byKey(const Key('isotipo_marca')), findsOneWidget);
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/screens/login`
Expected: FAIL — se muestra "App Ventas", sin isotipo ni slogan.

- [ ] **Step 3: Implementar**

Reemplazar todo `lib/ui/marca_app.dart` por:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'tipografia.dart';

/// Isotipo y nombre de la app (y, si se pide, el slogan), para las pantallas
/// de entrada.
class MarcaApp extends StatelessWidget {
  const MarcaApp({super.key, this.conSlogan = false});

  final bool conSlogan;

  static const slogan = 'La tranquilidad de tu tienda, en tu bolsillo.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/marca/isotipo.png',
              key: const Key('isotipo_marca'),
              width: 56,
              height: 56,
              semanticLabel: 'Logo de VeciTienda',
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'VeciTienda',
                style: estiloTitulo(tamano: 28, color: ColoresApp.primario),
              ),
            ),
          ],
        ),
        if (conSlogan) ...[
          const SizedBox(height: 8),
          const Text(
            slogan,
            style: TextStyle(fontSize: 15, color: ColoresApp.textoSecundario),
          ),
        ],
      ],
    );
  }
}
```

En `lib/screens/login/bienvenida_screen.dart`:
- Cambiar `const MarcaApp(),` por `const MarcaApp(conSlogan: true),`.
- Reemplazar

```dart
            const Text('Bienvenido',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
```

por

```dart
            Text('Bienvenido', style: estiloTitulo()),
```

y agregar el import `import '../../ui/tipografia.dart';`.

En `lib/screens/login/seleccionar_usuario_screen.dart` y `lib/screens/login/crear_admin_inicial_screen.dart`, hacer lo mismo con su título (`'¿Quién eres?'` y `'Configura tu tienda'`): quitar el `const` del `Text`, usar `style: estiloTitulo()` y agregar el import de `tipografia.dart`.

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test test/screens/login test/widget_test.dart && flutter analyze`
Expected: PASS y `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/marca_app.dart lib/screens/login test/screens/login
git commit -m "Show the VeciTienda logo, name, and slogan on sign-in screens"
```

---

### Task 4: Header azul en Inicio y bordes de tarjetas

**Files:**
- Modify: `lib/ui/tarjeta_monto.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/home/resumen_screen.dart`
- Test: `test/screens/home/home_screen_test.dart`, `test/screens/home/resumen_screen_test.dart`

**Interfaces:**
- Consumes: `ColoresApp.entraSuave/saleSuave/primario` (Task 2), `estiloTitulo` (Task 2), isotipo (Task 1).
- Produces: `TarjetaMonto({..., Color? colorBorde})`; clave `insignia_marca`.

- [ ] **Step 1: Escribir los tests que fallan**

En `test/screens/home/home_screen_test.dart`, agregar el import `import 'package:app_ventas/ui/colores_app.dart';` y dentro de `main()`:

```dart
  testWidgets('el Inicio tiene la barra azul con la insignia; las demás '
      'pestañas, blanca', (tester) async {
    await montar(tester);
    AppBar barra() => tester.widget<AppBar>(find.byType(AppBar).first);

    expect(barra().backgroundColor, ColoresApp.primario);
    expect(barra().foregroundColor, Colors.white);
    expect(find.byKey(const Key('insignia_marca')), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(barra().backgroundColor, isNull);
    expect(find.byKey(const Key('insignia_marca')), findsNothing);
  });

  testWidgets('un nombre largo no desborda la barra azul', (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db,
        nombre: 'María Fernanda de los Ángeles Rodríguez');
    addTearDown(container.dispose);

    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
```

En `test/screens/home/resumen_screen_test.dart`, agregar el import `import 'package:app_ventas/ui/colores_app.dart';` y dentro de `main()`:

```dart
  testWidgets('Gastos lleva borde rojo claro y Ganancia borde verde claro',
      (tester) async {
    await montar(tester);

    Color borde(String clave) {
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byKey(Key(clave)), matching: find.byType(Material))
          .first);
      return (material.shape! as RoundedRectangleBorder).side.color;
    }

    expect(borde('tarjeta_gastos'), ColoresApp.saleSuave);
    expect(borde('tarjeta_ganancia'), ColoresApp.entraSuave);
  });
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/screens/home`
Expected: FAIL — barra blanca en Inicio, sin insignia; bordes grises.

- [ ] **Step 3: Implementar**

En `lib/ui/tarjeta_monto.dart`:
1. Agregar el parámetro `this.colorBorde,` al constructor y el campo:

```dart
  /// Color del borde (por defecto el gris de [ColoresApp.borde]).
  final Color? colorBorde;
```

2. Reemplazar

```dart
        side: fondo == null
            ? const BorderSide(color: ColoresApp.borde)
            : BorderSide.none,
```

por

```dart
        side: fondo == null
            ? BorderSide(
                color: colorBorde ?? ColoresApp.borde,
                width: colorBorde == null ? 1 : 1.5,
              )
            : BorderSide.none,
```

En `lib/screens/home/resumen_screen.dart`, en las `TarjetaMonto` de `tarjeta_gastos` y `tarjeta_ganancia`, agregar respectivamente:

```dart
                colorBorde: ColoresApp.saleSuave,
```

y

```dart
                colorBorde:
                    ganancia >= 0 ? ColoresApp.entraSuave : ColoresApp.saleSuave,
```

En `lib/screens/home/home_screen.dart`:
1. Agregar los imports `import '../../ui/colores_app.dart';` y `import '../../ui/tipografia.dart';`.
2. Reemplazar el `appBar: AppBar(` completo (hasta su `),` de cierre, incluyendo `title` y `actions`) por:

```dart
      appBar: AppBar(
        // Header de marca solo en Inicio; las demás pestañas, barra blanca.
        backgroundColor: esInicio ? ColoresApp.primario : null,
        foregroundColor: esInicio ? Colors.white : null,
        titleTextStyle:
            esInicio ? estiloTitulo(tamano: 20, color: Colors.white) : null,
        title: esInicio
            ? Row(
                children: [
                  const _InsigniaMarca(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Hola, ${usuario.nombre}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(tabs[_tabActual].titulo),
        actions: [_MenuCuenta(usuario: usuario), const SizedBox(width: 8)],
      ),
```

3. Justo antes de `return Scaffold(` agregar `final esInicio = _tabActual == 0;`.
4. Agregar al final del archivo:

```dart
/// Isotipo sobre una insignia blanca, para el header azul del Inicio.
class _InsigniaMarca extends StatelessWidget {
  const _InsigniaMarca();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('insignia_marca'),
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset('assets/marca/isotipo.png',
          semanticLabel: 'VeciTienda'),
    );
  }
}
```

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test test/screens/home && flutter test && flutter analyze`
Expected: PASS en todo y `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/tarjeta_monto.dart lib/screens/home test/screens/home
git commit -m "Add the blue branded header to Inicio and tinted card borders"
```

---

### Task 5: Cierre — documentación y verificación visual

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-05-vecitienda-marca-design.md` (`**Estado:**`), `docs/marca/vecitienda-marca.md` (`**Estado:**`)

- [ ] **Step 1: Documentar**

En `README.md`, reemplazar la primera línea `# App de Ventas` por:

```markdown
# VeciTienda

*La tranquilidad de tu tienda, en tu bolsillo.*
```

y agregar al final de la sección `## Fase 2`:

```markdown
- **Marca VeciTienda** (hecho): nombre, isotipo e íconos Android
  (`tool/generar_iconos.py` los regenera desde `docs/marca/`), paleta azul
  cobalto + verde esmeralda con contraste AA, títulos en Nunito.
```

En el spec, `**Estado:** Borrador para revisión` → `**Estado:** Implementado`. En `docs/marca/vecitienda-marca.md`, cambiar la línea `**Estado:** Pendiente de aplicar...` por `**Estado:** Aplicado (ver docs/superpowers/specs/2026-10-05-vecitienda-marca-design.md).`

- [ ] **Step 2: Suite completa**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y `All tests passed!`.

- [ ] **Step 3: Verificación visual**

```bash
flutter build apk --debug
"$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt2" dump badging build/app/outputs/flutter-apk/app-debug.apk | grep -E "application-label|application-icon-480"
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Expected: `application-label:'VeciTienda'` y el ícono `mipmap-anydpi-v26/ic_launcher.xml` (o `mipmap-xxhdpi`). El emulador ATD no tiene lanzador: revisar el ícono abriendo `mipmap-xxxhdpi/ic_launcher.png` e `ic_launcher_foreground.png`.

Capturar (`adb exec-out screencap -p`) Bienvenida (sin datos: `adb shell pm clear` **solo si el usuario lo autoriza**, si no, ¿Quién eres?), Inicio, Nueva venta y Ajustes, y revisar: isotipo nítido, "VeciTienda" en Nunito gruesa, header azul con texto blanco legible, bordes rojo/verde claros, botones con esquinas de 16.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-05-vecitienda-marca-design.md docs/marca/vecitienda-marca.md
git commit -m "Document the VeciTienda rebrand"
```
