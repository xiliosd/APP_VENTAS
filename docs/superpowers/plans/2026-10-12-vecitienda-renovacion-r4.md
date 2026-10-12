# Renovación R4 (administración) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el lenguaje visual de R1–R3 a inventario, recibir mercancía, pedido sugerido, Ajustes, productos, proveedores, usuarios, respaldo y configurar QR, con pequeñas mejoras de pantalla.

**Architecture:** Cada pantalla se renueva en su sitio. Seis piezas compartidas nuevas en `lib/ui/` (`Pildora`, nivel de existencias, `BarraAccionFija`, `TituloSeccion`, `IconoCuadrado`, `BotonCantidad`). Sin cambios de esquema, repositorios ni proveedores de datos.

**Tech Stack:** Flutter 3.47, Riverpod 2, Drift (memoria en pruebas), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-12-vecitienda-renovacion-r4-design.md`

## Global Constraints

- Sin dependencias nuevas, sin cambios de esquema ni de repositorios.
- Colores solo con `ColoresApp.of(context)` (o `ColoresApp.blancoMarca`/`paletaAvatar`); prohibido `Color(0x…)`, `Colors.white`/`Colors.black` fuera de `colores_app.dart` (lo vigila `test/ui/colores_sueltos_test.dart`).
- Se conservan todas las claves existentes salvo donde la spec dice otra cosa.
- Textos en español; cantidades con `plural`; montos con `formatoMoneda`/`Monto`.
- Modo oscuro y letra 2,0× a 360 dp sin excepciones.
- Archivos con CRLF: editar con `$TEMP/ed.py` o la herramienta Edit (conserva finales de línea).
- Comando de pruebas completo: `flutter test` (684 al empezar).

## Review Focus

1. Letra 2,0× en 360 dp en filas con varias piezas (inventario Todos, productos, proveedores): nada debe desbordar — lo cubre la Tarea 10.
2. Buscador de productos con espacios extra o tildes ("  cafe ") debe hallar "Café" — prueba en Tarea 6.
3. Producto controlado con mínimo 0 y sin "pedir hasta": la barra va llena si hay existencias y vacía si hay 0 — prueba en Tarea 1.
4. Ajustes sin nombre de tienda guardado: la cabecera dice "Sin nombre" y no falla — prueba en Tarea 2.
5. Respaldo: cancelar "Desconectar" no desconecta — prueba en Tarea 9.

---

### Task 1: Piezas compartidas

**Files:**
- Create: `lib/ui/pildora.dart`, `lib/ui/nivel_existencias.dart`, `lib/ui/barra_accion_fija.dart`, `lib/ui/titulo_seccion.dart`, `lib/ui/icono_cuadrado.dart`, `lib/ui/boton_cantidad.dart`
- Test: `test/ui/piezas_administracion_test.dart`

**Interfaces:**
- Produces:
  - `Pildora({Key? key, required String texto, required Color color})`
  - `enum NivelExistencias { agotado, bajo, ok }`
  - `NivelExistencias nivelExistencias(int existencias, int minimo)`
  - `double fraccionNivel(int existencias, int minimo, int? pedirHasta)`
  - `Color colorNivel(ColoresApp c, NivelExistencias nivel)`
  - `EtiquetaNivel({Key? key, required NivelExistencias nivel})`
  - `BarraNivel({Key? key, required double fraccion, required NivelExistencias nivel})`
  - `BarraAccionFija({Key? key, required Widget total, required Widget boton})`
  - `TituloSeccion(String texto, {Key? key})`
  - `IconoCuadrado({Key? key, required IconData icono, required Color color})`
  - `BotonCantidad({Key? key, required IconData icono, required String tooltip, required VoidCallback? onPressed})`

- [ ] **Step 1: Write the failing tests**

`test/ui/piezas_administracion_test.dart`:

```dart
import 'package:app_ventas/ui/barra_accion_fija.dart';
import 'package:app_ventas/ui/boton_cantidad.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/icono_cuadrado.dart';
import 'package:app_ventas/ui/nivel_existencias.dart';
import 'package:app_ventas/ui/pildora.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/ui/titulo_seccion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo, {ThemeData? tema}) =>
    MaterialApp(theme: tema ?? temaClaro(), home: Scaffold(body: hijo));

void main() {
  group('nivelExistencias', () {
    test('0 o menos es agotado', () {
      expect(nivelExistencias(-1, 5), NivelExistencias.agotado);
      expect(nivelExistencias(0, 5), NivelExistencias.agotado);
      expect(nivelExistencias(0, 0), NivelExistencias.agotado);
    });
    test('hasta el mínimo es bajo', () {
      expect(nivelExistencias(5, 5), NivelExistencias.bajo);
      expect(nivelExistencias(1, 5), NivelExistencias.bajo);
    });
    test('por encima del mínimo es ok', () {
      expect(nivelExistencias(6, 5), NivelExistencias.ok);
      expect(nivelExistencias(1, 0), NivelExistencias.ok);
    });
  });

  group('fraccionNivel', () {
    test('usa pedir hasta como tope', () {
      expect(fraccionNivel(6, 4, 24), closeTo(0.25, 1e-9));
    });
    test('sin pedir hasta usa el doble del mínimo', () {
      expect(fraccionNivel(5, 5, null), closeTo(0.5, 1e-9));
      expect(fraccionNivel(5, 5, 0), closeTo(0.5, 1e-9));
    });
    test('sin mínimo ni pedir hasta la barra va llena', () {
      expect(fraccionNivel(3, 0, null), 1);
    });
    test('sin existencias la barra va vacía', () {
      expect(fraccionNivel(0, 0, null), 0);
      expect(fraccionNivel(-2, 5, 10), 0);
    });
    test('nunca pasa de 1', () {
      expect(fraccionNivel(40, 5, 24), 1);
    });
  });

  testWidgets('Pildora escribe en el color de texto sobre el color al 15 %',
      (tester) async {
    await tester.pumpWidget(
        _app(Pildora(texto: 'Bajo', color: ColoresApp.claro.fiado)));
    final texto = tester.widget<Text>(find.text('Bajo'));
    expect(texto.style!.color, ColoresApp.claro.texto);
  });

  testWidgets('EtiquetaNivel dice Agotado, Bajo u OK', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [
      EtiquetaNivel(nivel: NivelExistencias.agotado),
      EtiquetaNivel(nivel: NivelExistencias.bajo),
      EtiquetaNivel(nivel: NivelExistencias.ok),
    ])));
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('BarraNivel pinta la fracción en el color del nivel',
      (tester) async {
    await tester.pumpWidget(_app(const BarraNivel(
        fraccion: 0.25, nivel: NivelExistencias.bajo)));
    final barra = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(barra.value, 0.25);
    expect(barra.color, ColoresApp.claro.fiado);
  });

  testWidgets('BarraAccionFija muestra el total sobre el botón',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: temaClaro(),
      home: Scaffold(
        body: const SizedBox(),
        bottomNavigationBar: BarraAccionFija(
          total: const Text('Total \$5.000'),
          boton: FilledButton(onPressed: () {}, child: const Text('Guardar')),
        ),
      ),
    ));
    final total = tester.getRect(find.text('Total \$5.000'));
    final boton = tester.getRect(find.text('Guardar'));
    expect(total.bottom, lessThan(boton.top));
  });

  testWidgets('TituloSeccion, IconoCuadrado y BotonCantidad se dibujan',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(_app(Column(children: [
      const TituloSeccion('TIENDA'),
      IconoCuadrado(icono: Icons.store, color: ColoresApp.claro.entra),
      BotonCantidad(
        key: const Key('mas'),
        icono: Icons.add_rounded,
        tooltip: 'Sumar',
        onPressed: () => toques++,
      ),
    ])));
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.byIcon(Icons.store), findsOneWidget);
    await tester.tap(find.byKey(const Key('mas')));
    await tester.pumpAndSettle();
    expect(toques, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/piezas_administracion_test.dart`
Expected: FAIL (no compila: no existen los archivos importados).

- [ ] **Step 3: Write the implementation**

`lib/ui/pildora.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Etiqueta corta: un punto del [color] y el texto sobre ese color al 15 %.
/// El texto va en el color de texto para leerse bien en ambos temas.
class Pildora extends StatelessWidget {
  const Pildora({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: color.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColoresApp.of(context).texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

`lib/ui/nivel_existencias.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'pildora.dart';

/// Qué tan surtido está un producto.
enum NivelExistencias { agotado, bajo, ok }

NivelExistencias nivelExistencias(int existencias, int minimo) =>
    existencias <= 0
        ? NivelExistencias.agotado
        : existencias <= minimo
            ? NivelExistencias.bajo
            : NivelExistencias.ok;

/// Cuánto de la barra de nivel se llena: existencias ÷ "pedir hasta"; sin él,
/// ÷ el doble del mínimo; sin ninguno, llena. Entre 0 y 1.
double fraccionNivel(int existencias, int minimo, int? pedirHasta) {
  if (existencias <= 0) return 0;
  final tope = (pedirHasta ?? 0) > 0
      ? pedirHasta!
      : minimo > 0
          ? 2 * minimo
          : existencias;
  return (existencias / tope).clamp(0.0, 1.0);
}

Color colorNivel(ColoresApp c, NivelExistencias nivel) => switch (nivel) {
      NivelExistencias.agotado => c.sale,
      NivelExistencias.bajo => c.fiado,
      NivelExistencias.ok => c.entra,
    };

/// "Agotado", "Bajo" u "OK".
class EtiquetaNivel extends StatelessWidget {
  const EtiquetaNivel({super.key, required this.nivel});

  final NivelExistencias nivel;

  @override
  Widget build(BuildContext context) {
    return Pildora(
      texto: switch (nivel) {
        NivelExistencias.agotado => 'Agotado',
        NivelExistencias.bajo => 'Bajo',
        NivelExistencias.ok => 'OK',
      },
      color: colorNivel(ColoresApp.of(context), nivel),
    );
  }
}

/// Barra delgada con lo que queda frente al tope.
class BarraNivel extends StatelessWidget {
  const BarraNivel({super.key, required this.fraccion, required this.nivel});

  final double fraccion;
  final NivelExistencias nivel;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return LinearProgressIndicator(
      value: fraccion,
      minHeight: 6,
      borderRadius: BorderRadius.circular(99),
      backgroundColor: c.textoSecundario.withValues(alpha: 0.15),
      color: colorNivel(c, nivel),
    );
  }
}
```

`lib/ui/barra_accion_fija.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Franja fija abajo (para `Scaffold.bottomNavigationBar`): el total arriba y
/// el botón debajo, siempre a la vista aunque la lista sea larga.
class BarraAccionFija extends StatelessWidget {
  const BarraAccionFija({super.key, required this.total, required this.boton});

  final Widget total;
  final Widget boton;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        boxShadow: [
          BoxShadow(
            color: c.texto.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [total, const SizedBox(height: 8), boton],
          ),
        ),
      ),
    );
  }
}
```

`lib/ui/titulo_seccion.dart`:

```dart
import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Encabezado pequeño en mayúsculas sobre un grupo de tarjetas.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.of(context).textoSecundario,
        ),
      ),
    );
  }
}
```

`lib/ui/icono_cuadrado.dart`:

```dart
import 'package:flutter/material.dart';

/// Ícono de 20 px en un cuadrado redondeado de 36 px con su color al 15 %.
class IconoCuadrado extends StatelessWidget {
  const IconoCuadrado({super.key, required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icono, size: 20, color: color),
    );
  }
}
```

`lib/ui/boton_cantidad.dart`:

```dart
import 'package:flutter/material.dart';

import 'aplastable.dart';

/// Botón redondo de −/+ para cantidades. Con [onPressed] null queda apagado.
class BotonCantidad extends StatelessWidget {
  const BotonCantidad({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Aplastable(
      habilitado: onPressed != null,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        icon: Icon(icono),
        onPressed: onPressed,
        style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/piezas_administracion_test.dart test/ui/colores_sueltos_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pildora.dart lib/ui/nivel_existencias.dart lib/ui/barra_accion_fija.dart lib/ui/titulo_seccion.dart lib/ui/icono_cuadrado.dart lib/ui/boton_cantidad.dart test/ui/piezas_administracion_test.dart
git commit -m "Add pill, stock level, fixed action bar and section pieces for R4"
```

---

### Task 2: Ajustes con cabecera de tienda

**Files:**
- Modify: `lib/screens/configuracion/ajustes_screen.dart` (reescritura del `build` y borrar `_Titulo`)
- Test: `test/screens/configuracion/ajustes_screen_test.dart` (nuevo)

**Interfaces:**
- Consumes: `TituloSeccion`, `IconoCuadrado` (Tarea 1); `nombreTiendaProvider`, `sesionProvider`, `respaldoProvider`/`FaseRespaldo` (existentes); `AvatarInicial`, `etiquetaRol`.

- [ ] **Step 1: Write the failing tests**

`test/screens/configuracion/ajustes_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';
import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: AjustesScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('la cabecera muestra la tienda y quién usa la app',
      (tester) async {
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
    await montar(tester);
    final cabecera = find.byKey(const Key('cabecera_ajustes'));
    expect(cabecera, findsOneWidget);
    expect(find.descendant(of: cabecera, matching: find.text('La Esquina')),
        findsOneWidget);
    expect(
        find.descendant(
            of: cabecera, matching: find.text('Ana · Administrador')),
        findsOneWidget);
  });

  testWidgets('sin nombre guardado dice "Sin nombre"', (tester) async {
    await montar(tester);
    expect(
        find.descendant(
            of: find.byKey(const Key('cabecera_ajustes')),
            matching: find.text('Sin nombre')),
        findsOneWidget);
  });

  testWidgets('el menú va en grupos con su ícono', (tester) async {
    await montar(tester);
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.text('COBROS Y DATOS'), findsOneWidget);
    expect(find.text('AYUDA'), findsOneWidget);
    expect(find.text('CUENTA'), findsOneWidget);
    for (final clave in [
      'menu_productos',
      'menu_proveedores',
      'menu_usuarios',
      'menu_cobro_qr',
      'menu_respaldo',
    ]) {
      await tester.scrollUntilVisible(find.byKey(Key(clave)), 100);
      expect(find.byKey(Key(clave)), findsOneWidget);
    }
    expect(find.byKey(const Key('estado_respaldo_menu')), findsNothing);
  });

  testWidgets('con el respaldo activo la fila dice "Activo"', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerRespaldo(
        db, NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567'));
    addTearDown(container.dispose);
    final ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    container.read(sesionProvider.notifier).state = SesionState(
        usuarioActivo: await (db.select(db.usuarios)
              ..where((u) => u.id.equals(ana)))
            .getSingle());
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: AjustesScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('menu_respaldo')), 100);
    expect(find.byKey(const Key('estado_respaldo_menu')), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/configuracion/ajustes_screen_test.dart`
Expected: FAIL (no existe `cabecera_ajustes` ni los grupos nuevos).

- [ ] **Step 3: Rewrite `AjustesScreen`**

Reemplazar todo el archivo `lib/screens/configuracion/ajustes_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../providers/recorrido_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/tema_app.dart';
import '../../ui/titulo_seccion.dart';
import '../qr/configurar_qr_screen.dart';
import '../respaldo/respaldo_screen.dart';
import 'hoja_nombre_tienda.dart';
import 'productos_screen.dart';
import 'proveedores_screen.dart';
import 'usuarios_screen.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresApp.of(context);
    final nombre = ref.watch(nombreTiendaProvider).valueOrNull;
    final usuario = ref.watch(sesionProvider).usuarioActivo;
    final respaldoActivo =
        ref.watch(respaldoProvider).fase == FaseRespaldo.activo;
    final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);

    void abrir(Widget pantalla) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pantalla));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EntradaEscalonada(
          indice: 0,
          child: Material(
            key: const Key('cabecera_ajustes'),
            color: c.tarjetaPrincipal,
            borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
            child: InkWell(
              key: const Key('menu_nombre_tienda'),
              borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
              onTap: () => mostrarHojaNombreTienda(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarInicial(
                      id: 0,
                      nombre: nombre ?? '?',
                      radio: 28,
                      colorAnillo: c.sobreTarjetaPrincipal,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre ?? 'Sin nombre',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: c.sobreTarjetaPrincipal,
                            ),
                          ),
                          if (usuario != null)
                            Text(
                              '${usuario.nombre} · ${etiquetaRol(usuario.rol)}',
                              style: TextStyle(fontSize: 13, color: suave),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: c.sobreTarjetaPrincipal),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 1,
          child: _Grupo(titulo: 'TIENDA', opciones: [
            _Opcion(
              key: const Key('menu_productos'),
              icono: Icons.inventory_2_outlined,
              color: c.primario,
              titulo: 'Productos',
              subtitulo: 'Catálogo y precios',
              onTap: () => abrir(const ProductosScreen()),
            ),
            _Opcion(
              key: const Key('menu_proveedores'),
              icono: Icons.local_shipping_outlined,
              color: c.fiado,
              titulo: 'Proveedores',
              subtitulo: 'A quién le compras',
              onTap: () => abrir(const ProveedoresScreen()),
            ),
            _Opcion(
              key: const Key('menu_usuarios'),
              icono: Icons.group_outlined,
              color: c.marcaVerde,
              titulo: 'Usuarios',
              subtitulo: 'Administradores, vendedores y PIN',
              onTap: () => abrir(const UsuariosScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 2,
          child: _Grupo(titulo: 'COBROS Y DATOS', opciones: [
            _Opcion(
              key: const Key('menu_cobro_qr'),
              icono: Icons.qr_code_2_rounded,
              color: c.entra,
              titulo: 'Cobro por QR',
              subtitulo: 'Tu QR de Nequi, Daviplata o banco',
              onTap: () => abrir(const ConfigurarQrScreen()),
            ),
            _Opcion(
              key: const Key('menu_respaldo'),
              icono: Icons.cloud_upload_outlined,
              color: c.primario,
              titulo: 'Respaldo',
              subtitulo: 'Copia de seguridad en la nube',
              estado: respaldoActivo
                  ? Row(
                      key: const Key('estado_respaldo_menu'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: c.entra, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text('Activo',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : null,
              onTap: () => abrir(const RespaldoScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 3,
          child: _Grupo(titulo: 'AYUDA', opciones: [
            _Opcion(
              key: const Key('boton_repetir_recorrido'),
              icono: Icons.tour_outlined,
              color: c.primario,
              titulo: 'Ver el recorrido otra vez',
              subtitulo: 'Venta de práctica y guía del Inicio',
              // El Inicio, que está a la vista, abre el paso 3.
              onTap: () => ref
                  .read(recorridoProvider.notifier)
                  .irA(PasoRecorrido.venta),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        EntradaEscalonada(
          indice: 4,
          child: _Grupo(titulo: 'CUENTA', opciones: [
            ListTile(
              key: const Key('ajustes_cerrar_sesion'),
              leading: IconoCuadrado(icono: Icons.logout_rounded, color: c.sale),
              title: Text('Cerrar sesión', style: TextStyle(color: c.sale)),
              onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.opciones});

  final String titulo;
  final List<Widget> opciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(titulo),
        Card(
          child: Column(
            children: [
              for (final (i, o) in opciones.indexed) ...[
                if (i > 0) const Divider(height: 1),
                o,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.estado,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final Widget? estado;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconoCuadrado(icono: icono, color: color),
      title: Text(titulo),
      subtitle: Text(subtitulo),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?estado,
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}
```

Nota: `?estado` es la sintaxis de elemento nulo de Dart 3.8+. Si el analizador no la acepta, usar `if (estado != null) estado!,`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/configuracion/ajustes_screen_test.dart test/screens/configuracion/nombre_tienda_test.dart test/screens/home`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/ajustes_screen.dart test/screens/configuracion/ajustes_screen_test.dart
git commit -m "Give Settings a store header and grouped menu with colored icons"
```

---

### Task 3: Pestaña de inventario

**Files:**
- Modify: `lib/screens/inventario/inventario_screen.dart` (`build` y widgets privados nuevos)
- Test: `test/screens/inventario/inventario_screen_test.dart`

**Interfaces:**
- Consumes: `nivelExistencias`, `fraccionNivel`, `EtiquetaNivel`, `BarraNivel`, `TituloSeccion` (Tarea 1); `AvatarInicial`, `Monto`, `EntradaEscalonada`.
- Produces: `numeroConSigno` y `textoExistencias` siguen públicos en este archivo (los usa el detalle y el pedido).

- [ ] **Step 1: Update and add tests**

En `test/screens/inventario/inventario_screen_test.dart`:
- Reemplazar `expect(find.text('Nada por pedir'), findsOneWidget);` por:

```dart
    expect(find.text('Todo en orden'), findsOneWidget);
    expect(find.byKey(const Key('texto_nada_por_pedir')), findsOneWidget);
```

- Agregar al final de `main`:

```dart
  testWidgets('el resumen cuenta controlados, por pedir y agotados',
      (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final coca = await producto('Coca', proveedor: postobon);
    final pan = await producto('Pan');
    final agua = await producto('Agua');
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await inv.activarControl(agua, cantidad: 0, minimo: 0, por: ana);
    await pintar(tester, container);

    String cifra(String clave) =>
        tester.widget<Text>(find.byKey(Key(clave))).data!;
    expect(find.byKey(const Key('resumen_inventario')), findsOneWidget);
    expect(cifra('resumen_controlados'), '3');
    expect(cifra('resumen_por_pedir'), '2');
    expect(cifra('resumen_agotados'), '1');
    expect(tester.widget<Text>(find.byKey(const Key('resumen_agotados')))
        .style!.color, ColoresApp.claro.sale);
  });

  testWidgets('en Todos cada producto lleva su etiqueta y su barra',
      (tester) async {
    final (container, ana) = await montar(tester);
    final coca = await producto('Coca');
    final pan = await producto('Pan');
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(Key('etiqueta_nivel_$coca')),
            matching: find.text('Bajo')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(Key('etiqueta_nivel_$pan')),
            matching: find.text('OK')),
        findsOneWidget);
    final barra = tester.widget<LinearProgressIndicator>(find.descendant(
        of: find.byKey(Key('nivel_$coca')),
        matching: find.byType(LinearProgressIndicator)));
    expect(barra.value, closeTo(2 / 12, 1e-9));
  });

  testWidgets('una entrada anulada muestra su monto tachado', (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final pan = await producto('Pan', proveedor: postobon);
    final inv = InventarioRepository(db);
    await inv.activarControl(pan, cantidad: 0, minimo: 0, por: ana);
    final entrada = await inv.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: pan, cantidad: 2, precioCompra: 500)],
      por: ana,
    );
    await inv.anularEntrada(entrada, por: ana);
    await pintar(tester, container);
    await tester.scrollUntilVisible(find.byKey(Key('entrada_$entrada')), 200);
    final monto = tester.widget<Text>(find.descendant(
        of: find.byKey(Key('entrada_$entrada')),
        matching: find.text(r'$1.000')));
    expect(monto.style!.decoration, TextDecoration.lineThrough);
  });
```

(Si `LineaRecibida` no se importa ya en esta prueba, sale de `package:app_ventas/repositories/inventario_repository.dart`, que ya está importado.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/inventario_screen_test.dart`
Expected: FAIL en "Todo en orden", el resumen, las etiquetas y la entrada tachada.

- [ ] **Step 3: Rewrite the build**

En `inventario_screen.dart`, agregar los imports:

```dart
import '../../ui/avatar_inicial.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/monto.dart';
import '../../ui/nivel_existencias.dart';
import '../../ui/titulo_seccion.dart';
```

Reemplazar el método `build` de `_InventarioScreenState` por:

```dart
  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final controlados =
        ref.watch(productosConControlProvider).valueOrNull ?? const [];
    final grupos = ref.watch(porPedirProvider).valueOrNull ?? const [];
    final entradas =
        ref.watch(entradasRecientesProvider).valueOrNull ?? const [];
    final nPorPedir = grupos.fold<int>(0, (s, g) => s + g.productos.length);
    final agotados = controlados
        .where((x) =>
            nivelExistencias(x.existencias, x.producto.minimo) ==
            NivelExistencias.agotado)
        .length;
    final vista = _vista ?? (nPorPedir > 0 ? _Vista.porPedir : _Vista.todos);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controlados.isNotEmpty) ...[
          EntradaEscalonada(
            indice: 0,
            child: Card(
              key: const Key('resumen_inventario'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _Cifra(
                        clave: 'resumen_controlados',
                        valor: controlados.length,
                        rotulo: 'Controlados'),
                    _Cifra(
                        clave: 'resumen_por_pedir',
                        valor: nPorPedir,
                        rotulo: 'Por pedir'),
                    _Cifra(
                        clave: 'resumen_agotados',
                        valor: agotados,
                        rotulo: 'Agotados',
                        color: agotados > 0 ? c.sale : null),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        BotonPrincipal(
          key: const Key('boton_recibir_mercancia'),
          texto: 'Recibir mercancía',
          icono: Icons.local_shipping_outlined,
          onPressed: _recibir,
        ),
        const SizedBox(height: 12),
        if (controlados.isEmpty)
          EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Aún no controlas existencias',
            mensaje: ref.watch(sesionProvider).esAdmin
                ? 'Actívalo en Ajustes → Productos'
                : 'Pídele al administrador que lo active',
          )
        else ...[
          SelectorSegmentado<_Vista>(
            key: const Key('selector_inventario'),
            opciones: {
              _Vista.porPedir: 'Por pedir ($nPorPedir)',
              _Vista.todos: 'Todos',
            },
            valor: vista,
            onCambio: (v) => setState(() => _vista = v),
          ),
          const SizedBox(height: 12),
          if (vista == _Vista.todos)
            EntradaEscalonada(
              indice: 1,
              child: Card(
                child: Column(
                  children: [
                    for (final (i, x) in controlados.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _FilaInventario(
                        producto: x.producto,
                        existencias: x.existencias,
                        onTap: () => _abrir(
                          DetalleInventarioScreen(productoId: x.producto.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (grupos.isEmpty)
            const EstadoVacio(
              key: Key('texto_nada_por_pedir'),
              icono: Icons.check_circle_rounded,
              titulo: 'Todo en orden',
              mensaje: 'Ningún producto está en su mínimo',
            )
          else
            for (final (i, g) in grupos.indexed)
              EntradaEscalonada(
                indice: i + 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
                      // Si no caben, el botón baja a su propia línea.
                      child: OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        overflowAlignment: OverflowBarAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping_rounded,
                                  size: 18, color: c.textoSecundario),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                                  '${plural(g.productos.length, 'producto', 'productos')}',
                                  key: Key(
                                      'grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          FilledButton.tonal(
                            key: Key('ver_pedido_${g.proveedor?.id ?? 'sin'}'),
                            onPressed: () => _verPedido(g.proveedor),
                            child: const Text('Ver pedido sugerido'),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          for (final p in g.productos)
                            ListTile(
                              key: Key('por_pedir_${p.producto.id}'),
                              title: Text(p.producto.nombre),
                              subtitle: Text(
                                'quedan ${numeroConSigno(p.existencias)} · '
                                'mín. ${p.producto.minimo}',
                              ),
                              trailing: EtiquetaNivel(
                                nivel: nivelExistencias(
                                    p.existencias, p.producto.minimo),
                              ),
                              onTap: () => _abrir(
                                DetalleInventarioScreen(
                                    productoId: p.producto.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
        if (entradas.isNotEmpty) ...[
          const SizedBox(height: 24),
          const TituloSeccion('ENTRADAS RECIBIDAS'),
          Card(
            child: Column(
              children: [
                for (final e in entradas)
                  ListTile(
                    key: Key('entrada_${e.entrada.id}'),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (e.entrada.anulada ? c.textoSecundario : c.entra)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_shipping_rounded,
                          size: 20,
                          color: e.entrada.anulada
                              ? c.textoSecundario
                              : c.entra),
                    ),
                    title: Text(
                      e.proveedor,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: e.entrada.anulada ? c.textoSecundario : null,
                      ),
                    ),
                    subtitle: Text(
                      '${formatoFechaHora(e.entrada.fecha)} · ${e.usuario}',
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Monto(e.entrada.total,
                          tamano: 16, tachado: e.entrada.anulada),
                    ),
                    onTap: () =>
                        _abrir(DetalleEntradaScreen(entradaId: e.entrada.id)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
```

Y agregar al final del archivo:

```dart
/// Una cifra del resumen con su rótulo.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.clave,
    required this.valor,
    required this.rotulo,
    this.color,
  });

  final String clave;
  final int valor;
  final String rotulo;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valor',
            key: Key(clave),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color ?? c.texto,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              style: TextStyle(fontSize: 12, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

/// Producto en la vista "Todos": nombre, mínimo, barra y existencias.
class _FilaInventario extends StatelessWidget {
  const _FilaInventario({
    required this.producto,
    required this.existencias,
    required this.onTap,
  });

  final Producto producto;
  final int existencias;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final nivel = nivelExistencias(existencias, producto.minimo);
    return InkWell(
      key: Key('inventario_item_${producto.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AvatarInicial(id: producto.id, nombre: producto.nombre),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('mín. ${producto.minimo}',
                      style: TextStyle(
                          fontSize: 12, color: c.textoSecundario)),
                  const SizedBox(height: 6),
                  BarraNivel(
                    key: Key('nivel_${producto.id}'),
                    fraccion: fraccionNivel(
                        existencias, producto.minimo, producto.pedirHasta),
                    nivel: nivel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  textoExistencias(existencias),
                  key: Key('existencias_${producto.id}'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: existencias <= producto.minimo ? c.sale : c.texto,
                  ),
                ),
                const SizedBox(height: 4),
                EtiquetaNivel(
                    key: Key('etiqueta_nivel_${producto.id}'), nivel: nivel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/inventario/inventario_screen_test.dart`
Expected: PASS (incluida la prueba existente "Todos marca en rojo", que lee el `Text` con clave `existencias_$id`).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/inventario_screen.dart test/screens/inventario/inventario_screen_test.dart
git commit -m "Add a stock summary, level tags and bars to the inventory tab"
```

---

### Task 4: Detalle de inventario, hoja de ajuste y detalle de entrada

**Files:**
- Modify: `lib/screens/inventario/detalle_inventario_screen.dart`, `lib/screens/inventario/hoja_ajuste_conteo.dart`, `lib/screens/inventario/detalle_entrada_screen.dart`
- Test: `test/screens/inventario/detalle_inventario_screen_test.dart`, `test/screens/inventario/inventario_screen_test.dart`

**Interfaces:**
- Consumes: `nivelExistencias`, `fraccionNivel`, `EtiquetaNivel`, `BarraNivel`, `TituloSeccion`, `IconoCuadrado` (Tarea 1).

- [ ] **Step 1: Write the failing tests**

Leer primero el montaje existente de `test/screens/inventario/detalle_inventario_screen_test.dart` y agregar, con ese mismo montaje (producto controlado con `activarControl(cantidad: 2, minimo: 6)` y un ajuste posterior a 9 con `ajustarConteo`):

```dart
  testWidgets('la tarjeta de existencias lleva su etiqueta y los movimientos '
      'su ícono', (tester) async {
    // montaje: producto "Coca" controlado con 2 y mínimo 6; luego un
    // ajuste a 9 y una entrada de 3 de Postobón (recibirMercancia).
    // ... (usar los ayudantes del archivo)
    expect(find.byKey(const Key('tarjeta_existencias')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_existencias')),
            matching: find.byType(EtiquetaNivel)),
        findsOneWidget);
    expect(find.byIcon(Icons.call_received_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNWidgets(2));
  });
```

El cuerpo del montaje se escribe con los ayudantes que ya tenga el archivo; si no tiene, copiar `montar`/`pintar`/`producto` de `inventario_screen_test.dart` y montar `DetalleInventarioScreen(productoId: coca)` como `inicio`.

En `inventario_screen_test.dart`, en la prueba que abre una entrada (la de la línea que espera `'24 × Pan · $400'`), agregar justo después de abrirla:

```dart
    expect(find.byKey(const Key('cabecera_entrada')), findsOneWidget);
```

y, tras confirmar la anulación, comprobar que el botón de anular desapareció:

```dart
    expect(find.byKey(const Key('boton_anular_entrada')), findsNothing);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/detalle_inventario_screen_test.dart test/screens/inventario/inventario_screen_test.dart`
Expected: FAIL (`tarjeta_existencias`, íconos y `cabecera_entrada` no existen).

- [ ] **Step 3: Implement**

`detalle_inventario_screen.dart` — imports nuevos:

```dart
import '../../ui/entrada_escalonada.dart';
import '../../ui/icono_cuadrado.dart';
import '../../ui/nivel_existencias.dart';
import '../../ui/titulo_seccion.dart';
```

Reemplazar el `return Scaffold(...)` final (el que tiene `appBar: AppBar(title: Text(item.producto.nombre))`) por:

```dart
    final c = ColoresApp.of(context);
    final nivel = nivelExistencias(item.existencias, item.producto.minimo);
    final pedirHasta = item.producto.pedirHasta;
    return Scaffold(
      appBar: AppBar(title: Text(item.producto.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntradaEscalonada(
            indice: 0,
            child: Card(
              key: const Key('tarjeta_existencias'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          textoExistencias(item.existencias),
                          key: const Key('existencias_detalle'),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: item.existencias <= item.producto.minimo
                                ? c.sale
                                : c.texto,
                          ),
                        ),
                        EtiquetaNivel(nivel: nivel),
                      ],
                    ),
                    Text(
                      'mín. ${item.producto.minimo}'
                      '${pedirHasta == null ? '' : ' · pedir hasta $pedirHasta'}',
                      style: TextStyle(color: c.textoSecundario),
                    ),
                    const SizedBox(height: 12),
                    BarraNivel(
                      fraccion: fraccionNivel(
                          item.existencias, item.producto.minimo, pedirHasta),
                      nivel: nivel,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_ajustar_conteo'),
            texto: 'Ajustar conteo',
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: item.producto),
          ),
          if (historial.isNotEmpty) ...[
            const SizedBox(height: 24),
            const TituloSeccion('HISTORIAL'),
            EntradaEscalonada(
              indice: 1,
              child: Card(
                child: Column(
                  children: [
                    for (final (i, m) in historial.indexed)
                      ListTile(
                        key: Key('movimiento_inventario_$i'),
                        leading: m.tipo == TipoMovimientoInventario.entrada
                            ? IconoCuadrado(
                                icono: Icons.call_received_rounded,
                                color: c.entra)
                            : IconoCuadrado(
                                icono: Icons.edit_rounded,
                                color: c.textoSecundario),
                        title: Text(_textoMovimiento(m)),
                        subtitle: Text(formatoFechaHora(m.fecha)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
```

`hoja_ajuste_conteo.dart` — el título de la hoja ya lleva el nombre ("Ajustar conteo · Pan"). Reemplazar el bloque `if (hay != null) Text(... key: texto_segun_app)` por un recuadro destacado, conservando texto y clave:

```dart
        if (hay != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresApp.of(context).primarioSuave,
              borderRadius: BorderRadius.circular(radioCampo),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded,
                    color: ColoresApp.of(context).primario),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Según la app hay $hay. ¿Cuántas hay?',
                    key: const Key('texto_segun_app'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.of(context).texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
```

con imports `import '../../ui/colores_app.dart';` y `import '../../ui/tema_app.dart';` (de donde sale `radioCampo`).

`detalle_entrada_screen.dart` — imports nuevos `../../ui/boton_principal.dart`, `../../ui/icono_cuadrado.dart`, `../../ui/monto.dart`. Reemplazar el `return Scaffold(...)` final por:

```dart
    final c = ColoresApp.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(detalle.resumen.proveedor)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('cabecera_entrada'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconoCuadrado(
                        icono: Icons.local_shipping_rounded,
                        color:
                            entrada.anulada ? c.textoSecundario : c.entra,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detalle.resumen.proveedor,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${formatoFechaHora(entrada.fecha)} · '
                              '${detalle.resumen.usuario}',
                              style: TextStyle(
                                  fontSize: 13, color: c.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Monto(entrada.total, tamano: 28, tachado: entrada.anulada),
                  if (entrada.anulada)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Entrada anulada',
                          style: TextStyle(
                              color: c.sale, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final l in detalle.lineas)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${l.linea.cantidad} × ${l.producto} · '
                      '${formatoMoneda(l.linea.precioCompra)}',
                    ),
                  ),
              ],
            ),
          ),
          if (entrada.nota != null) ...[
            const SizedBox(height: 12),
            Text(entrada.nota!, style: TextStyle(color: c.textoSecundario)),
          ],
          if (!entrada.anulada) ...[
            const SizedBox(height: 24),
            BotonPrincipal(
              key: const Key('boton_anular_entrada'),
              texto: 'Anular entrada',
              variante: VarianteBoton.peligro,
              onPressed: () => _anular(context, ref),
            ),
          ],
        ],
      ),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/inventario`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/detalle_inventario_screen.dart lib/screens/inventario/hoja_ajuste_conteo.dart lib/screens/inventario/detalle_entrada_screen.dart test/screens/inventario
git commit -m "Give the stock detail a hero card, typed history and a styled delivery detail"
```

---

### Task 5: Recibir mercancía y Pedido sugerido con barra fija

**Files:**
- Modify: `lib/screens/inventario/recibir_mercancia_screen.dart`, `lib/screens/inventario/pedido_sugerido_screen.dart`
- Test: `test/screens/inventario/recibir_mercancia_screen_test.dart`, `test/screens/inventario/pedido_sugerido_screen_test.dart`

**Interfaces:**
- Consumes: `BarraAccionFija`, `BotonCantidad` (Tarea 1).

- [ ] **Step 1: Write the failing tests**

En `recibir_mercancia_screen_test.dart`, con el montaje que ya usa el archivo (pantalla abierta con `lineasIniciales`), agregar:

```dart
  testWidgets('con muchos productos el total y Guardar siguen a la vista',
      (tester) async {
    // Montar RecibirMercanciaScreen con 12 LineaInicial (productos creados
    // con ProductoRepository(db).guardarProducto) usando el montaje del
    // archivo.
    final pantalla = tester.getRect(find.byType(Scaffold).last);
    for (final clave in ['total_recibir', 'boton_guardar_recibir']) {
      final r = tester.getRect(find.byKey(Key(clave)));
      expect(r.bottom, lessThanOrEqualTo(pantalla.bottom), reason: clave);
      expect(r.top, greaterThanOrEqualTo(pantalla.top), reason: clave);
    }
    expect(
        find.ancestor(
            of: find.byKey(const Key('boton_guardar_recibir')),
            matching: find.byType(BarraAccionFija)),
        findsOneWidget);
  });
```

En `pedido_sugerido_screen_test.dart`, en la prueba que ya espera `'Total estimado $23.400'`, agregar:

```dart
    expect(
        find.ancestor(
            of: find.byKey(const Key('total_pedido')),
            matching: find.byType(BarraAccionFija)),
        findsOneWidget);
```

(import `package:app_ventas/ui/barra_accion_fija.dart` en ambos.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/recibir_mercancia_screen_test.dart test/screens/inventario/pedido_sugerido_screen_test.dart`
Expected: FAIL (no hay `BarraAccionFija`).

- [ ] **Step 3: Implement**

`recibir_mercancia_screen.dart`:
- Imports: `../../ui/barra_accion_fija.dart`, `../../ui/boton_cantidad.dart`.
- En el `Scaffold`, agregar:

```dart
      bottomNavigationBar: BarraAccionFija(
        total: Text(
          'Total ${formatoMoneda(_total)}',
          key: const Key('total_recibir'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        boton: BotonPrincipal(
          key: const Key('boton_guardar_recibir'),
          texto: 'Guardar',
          onPressed: _puedeGuardar ? _guardar : null,
        ),
      ),
```

- Quitar del `ListView` el `Text('Total …')` con su `SizedBox` y el `BotonPrincipal` final con su `SizedBox(height: 24)`. Dejar nota y error.
- Cambiar el padding de cada línea `Card` a `EdgeInsets.all(12)` y reemplazar los dos `IconButton` de restar/sumar por:

```dart
                        BotonCantidad(
                          key: Key('restar_recibir_${l.producto.id}'),
                          icono: Icons.remove_rounded,
                          tooltip: 'Restar',
                          onPressed: l.cantidad > 1
                              ? () => setState(() => l.cantidad--)
                              : null,
                        ),
```

```dart
                        BotonCantidad(
                          key: Key('sumar_recibir_${l.producto.id}'),
                          icono: Icons.add_rounded,
                          tooltip: 'Sumar',
                          onPressed: () => setState(() => l.cantidad++),
                        ),
```

- El texto de la cantidad pasa a `style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)`.

`pedido_sugerido_screen.dart`:
- Imports: `../../ui/barra_accion_fija.dart`, `../../ui/boton_cantidad.dart`.
- En el `Scaffold`, agregar (solo cuando hay líneas):

```dart
      bottomNavigationBar: pedido.hasValue && lineas.isNotEmpty
          ? BarraAccionFija(
              total: Text(
                'Total estimado ${formatoMoneda(total)}',
                key: const Key('total_pedido'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              boton: BotonPrincipal(
                key: const Key('boton_recibir_pedido'),
                texto: 'Recibir este pedido',
                onPressed: hayAlgo ? () => _recibir(lineas) : null,
              ),
            )
          : null,
```

- Quitar del `ListView` el `SizedBox(height: 12)`, el `Text('Total estimado …')`, el `SizedBox(height: 24)` y el `BotonPrincipal`.
- Reemplazar los `IconButton` de restar/sumar por `BotonCantidad` con las mismas claves, tooltips y `onPressed`.
- Padding de cada `Card` a `EdgeInsets.all(12)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/inventario test/screens/correccion`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/recibir_mercancia_screen.dart lib/screens/inventario/pedido_sugerido_screen.dart test/screens/inventario
git commit -m "Pin the total and action of receiving and suggested orders to the bottom"
```

---

### Task 6: Productos con buscador y margen

**Files:**
- Modify: `lib/screens/configuracion/productos_screen.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `Pildora`, `TituloSeccion` (Tarea 1); `sinTildes`, `claveNombre`, `AvatarInicial`, `Monto`, `EntradaEscalonada`.

- [ ] **Step 1: Update and add tests**

Reemplazar en `productos_screen_test.dart`:
- `expect(find.text(r'$3.000 · sin costo'), findsOneWidget);` →

```dart
    expect(find.text(r'$3.000'), findsOneWidget);
    expect(find.text('sin costo'), findsOneWidget);
```

- `expect(find.text(r'$3.500 · sin costo'), findsOneWidget);` →

```dart
    expect(find.text(r'$3.500'), findsOneWidget);
    expect(find.text('sin costo'), findsOneWidget);
```

- `expect(find.text(r'$3.500 · gana $1.200'), findsOneWidget);` →

```dart
    expect(find.text(r'gana $1.200'), findsOneWidget);
```

Agregar (con los ayudantes del archivo para montar `ProductosScreen` y crear productos con `ProductoRepository(db).guardarProducto`; el costo sale del proveedor preferido con `ProveedorDeProducto`):

```dart
  testWidgets('el buscador filtra sin tildes ni espacios', (tester) async {
    final repo = ProductoRepository(db);
    final cafe = await repo.guardarProducto(nombre: 'Café', precio: 2000);
    final pan = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    // montar ProductosScreen
    await tester.enterText(
        find.byKey(const Key('campo_buscar_productos')), '  cafe ');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$cafe')), findsOneWidget);
    expect(find.byKey(Key('producto_item_$pan')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('campo_buscar_productos')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('texto_sin_coincidencias')), findsOneWidget);
    expect(find.text('Ningún producto coincide'), findsOneWidget);
  });

  testWidgets('un producto que se vende por debajo del costo dice "pierde"',
      (tester) async {
    final proveedor = await ProveedorRepository(db).crear(nombre: 'Alpina');
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Yogur',
      precio: 2000,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: proveedor, precioCompra: 2500, preferido: true),
      ],
    );
    // montar ProductosScreen
    expect(
        find.descendant(
            of: find.byKey(Key('margen_$id')),
            matching: find.text(r'pierde $500')),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

En `productos_screen.dart`:
- Imports nuevos: `../../ui/avatar_inicial.dart`, `../../ui/entrada_escalonada.dart`, `../../ui/monto.dart`, `../../ui/pildora.dart`, `../../ui/titulo_seccion.dart`, `../../util/texto_util.dart`.
- En el estado:

```dart
  final _buscar = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  bool _coincide(Producto p) {
    final q = sinTildes(claveNombre(_busqueda));
    return q.isEmpty || sinTildes(claveNombre(p.nombre)).contains(q);
  }
```

- Dentro de `data:` (después del `EstadoVacio` de lista vacía), reemplazar el `return ListView(...)` por:

```dart
          final c = ColoresApp.of(context);
          final visibles = productos.where(_coincide).toList();
          final inactivosVisibles = inactivos.where(_coincide).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                key: const Key('campo_buscar_productos'),
                controller: _buscar,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('borrar_busqueda_productos'),
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _buscar.clear();
                            setState(() => _busqueda = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (visibles.isEmpty && inactivosVisibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Ningún producto coincide',
                    key: const Key('texto_sin_coincidencias'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textoSecundario),
                  ),
                ),
              if (visibles.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final (i, p) in visibles.indexed)
                        EntradaEscalonada(
                          indice: i,
                          child: ListTile(
                            key: Key('producto_item_${p.id}'),
                            leading:
                                AvatarInicial(id: p.id, nombre: p.nombre),
                            title: Text(p.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Monto(p.precio, tamano: 15),
                                  _margen(c, p, costos[p.id]),
                                ],
                              ),
                            ),
                            onTap: () => _abrir(producto: p),
                            trailing: IconButton(
                              key: Key('boton_desactivar_${p.id}'),
                              tooltip: 'Desactivar',
                              icon: const Icon(Icons.visibility_off_outlined),
                              onPressed: () => ref
                                  .read(productoRepositoryProvider)
                                  .desactivarProducto(p.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (inactivosVisibles.isNotEmpty) ...[
                const SizedBox(height: 24),
                const TituloSeccion('INACTIVOS'),
                Card(
                  child: Column(
                    children: [
                      for (final p in inactivosVisibles)
                        ListTile(
                          key: Key('producto_inactivo_${p.id}'),
                          leading: Opacity(
                            opacity: 0.5,
                            child: AvatarInicial(id: p.id, nombre: p.nombre),
                          ),
                          title: Text(p.nombre,
                              style: TextStyle(color: c.textoSecundario)),
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
```

- Y el método:

```dart
  Widget _margen(ColoresApp c, Producto p, int? costo) {
    final key = Key('margen_${p.id}');
    if (costo == null) {
      return Pildora(key: key, texto: 'sin costo', color: c.textoSecundario);
    }
    final m = p.precio - costo;
    return m >= 0
        ? Pildora(key: key, texto: 'gana ${formatoMoneda(m)}', color: c.entra)
        : Pildora(
            key: key, texto: 'pierde ${formatoMoneda(-m)}', color: c.sale);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/productos_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Add search, avatars and a margin pill to the product list"
```

---

### Task 7: Ficha de producto en tarjetas con vista previa

**Files:**
- Modify: `lib/screens/configuracion/producto_screen.dart` (`build` de `_ProductoScreenState` y el diálogo de `_cambiarControl`)
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `TituloSeccion` (Tarea 1); `AvatarInicial`, `Monto`.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('la vista previa cambia al escribir y la ficha va en tarjetas',
      (tester) async {
    // montar ProductosScreen y tocar boton_agregar_producto
    final previa = find.byKey(const Key('vista_previa_producto'));
    expect(find.descendant(of: previa, matching: find.text('Sin nombre')),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.pumpAndSettle();
    expect(find.descendant(of: previa, matching: find.text('Arepa')),
        findsOneWidget);
    expect(find.descendant(of: previa, matching: find.text(r'$3.000')),
        findsOneWidget);
    expect(find.text('DATOS'), findsOneWidget);
    expect(find.text('PROVEEDORES Y COSTO'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('EXISTENCIAS'), 200);
    expect(find.text('EXISTENCIAS'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (no existe `vista_previa_producto`).

- [ ] **Step 3: Implement**

Imports: `../../ui/avatar_inicial.dart`, `../../ui/monto.dart`, `../../ui/titulo_seccion.dart`.

Agregar al estado:

```dart
  Widget _tarjeta(String titulo, List<Widget> hijos) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloSeccion(titulo),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: hijos,
                ),
              ),
            ),
          ],
        ),
      );
```

En `build`, reemplazar los `children` del `ListView` por (mismos widgets de hoy, reagrupados; el `TextField` del nombre gana `onChanged: (_) => setState(() {})`):

```dart
        children: [
          Card(
            key: const Key('vista_previa_producto'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarInicial(
                    id: widget.producto?.id ?? 0,
                    nombre: _nombre.text,
                    radio: 26,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombre.text.trim().isEmpty
                              ? 'Sin nombre'
                              : _nombre.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Monto(parsearMonto(_precio.text) ?? 0,
                            tamano: 20, tono: TonoMonto.entra),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tarjeta('DATOS', [
            /* TextField campo_nombre_producto (con onChanged) */
            const SizedBox(height: 12),
            /* TextField campo_precio_producto */
          ]),
          _tarjeta('PROVEEDORES Y COSTO', [
            /* for (final f in _filas) Row(fila_proveedor_…) — sin cambios */
            /* TextButton.icon boton_agregar_proveedor — sin cambios */
            const SizedBox(height: 12),
            _resumen(),
          ]),
          _tarjeta('EXISTENCIAS', [
            /* SwitchListTile interruptor_existencias y todo el bloque
               condicional de hoy (texto_existencias_producto, ajustar conteo,
               campo_hay_ahora, campo_minimo, campo_pedir_hasta), con
               const SizedBox(height: 12) entre campos */
          ]),
          /* bloque de _error — sin cambios */
          const SizedBox(height: 24),
          /* BotonPrincipal boton_guardar_producto — sin cambios */
        ],
```

Los comentarios `/* … */` marcan widgets que **se mueven tal cual** desde el `build` actual (líneas 304–455 de hoy); no se reescriben. Se quitan los `Text('Proveedores')` y `Text('Existencias')` sueltos, reemplazados por los títulos de tarjeta.

En `_cambiarControl`, el botón de confirmación pasa a:

```dart
            FilledButton(
              key: const Key('confirmar_dejar_de_controlar'),
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.of(context).sale,
                foregroundColor: ColoresApp.of(context).sobreSale,
              ),
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Dejar de controlar'),
            ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/configuracion test/screens/inventario`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/producto_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Group the product form in cards under a live preview"
```

---

### Task 8: Proveedores y Usuarios

**Files:**
- Modify: `lib/screens/configuracion/proveedores_screen.dart`, `lib/screens/configuracion/usuarios_screen.dart`
- Test: `test/screens/configuracion/proveedores_screen_test.dart`, `test/screens/configuracion/usuarios_screen_test.dart`

**Interfaces:**
- Consumes: `Pildora`, `TituloSeccion` (Tarea 1); `AvatarInicial`, `etiquetaRol`, `sesionProvider`.

- [ ] **Step 1: Update and add tests**

`proveedores_screen_test.dart`: reemplazar `expect(find.text('3001234567 · Surte 0 productos'), findsOneWidget);` por:

```dart
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
    expect(find.text('Surte 0 productos'), findsOneWidget);
```

`usuarios_screen_test.dart`:
- El toque `await tester.tap(find.text('Administrador'));` (dentro de la hoja) pasa a:

```dart
    await tester.tap(find.descendant(
        of: find.byKey(const Key('selector_rol')),
        matching: find.text('Administrador')));
```

- Agregar:

```dart
  testWidgets('cada usuario lleva su chip de rol y el actual dice (tú)',
      (tester) async {
    // montaje del archivo: sesión de Ana (admin) y un vendedor Beto creado con
    // UsuarioRepository(db).crearUsuario(nombre: 'Beto', rol: 'vendedor', pin: '1234')
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Beto (tú)'), findsNothing);
    // los ids salen de la base
    final beto = (await (db.select(db.usuarios)
              ..where((u) => u.nombre.equals('Beto')))
            .getSingle())
        .id;
    expect(
        find.descendant(
            of: find.byKey(Key('rol_$beto')), matching: find.text('Vendedor')),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/configuracion/proveedores_screen_test.dart test/screens/configuracion/usuarios_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`proveedores_screen.dart` — imports `../../ui/avatar_inicial.dart`, `../../ui/pildora.dart`, `../../ui/titulo_seccion.dart`. Cada `ListTile` activo pasa a:

```dart
                        ListTile(
                          key: Key('proveedor_item_${p.id}'),
                          leading: AvatarInicial(id: p.id, nombre: p.nombre),
                          title: Text(
                            p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (p.telefono != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone_rounded,
                                          size: 14,
                                          color: ColoresApp.of(context)
                                              .textoSecundario),
                                      const SizedBox(width: 4),
                                      Text(p.telefono!),
                                    ],
                                  ),
                                Pildora(
                                  key: Key('texto_surte_${p.id}'),
                                  texto:
                                      'Surte ${plural(conteo[p.id] ?? 0, 'producto', 'productos')}',
                                  color: ColoresApp.of(context).fiado,
                                ),
                              ],
                            ),
                          ),
                          onTap: () => _abrir(context, proveedor: p),
                          trailing: IconButton(
                            key: Key('boton_desactivar_proveedor_${p.id}'),
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => repo.desactivar(p.id),
                          ),
                        ),
```

El encabezado "Inactivos" pasa a `const SizedBox(height: 24), const TituloSeccion('INACTIVOS'),` y cada inactivo gana `leading: Opacity(opacity: 0.5, child: AvatarInicial(id: p.id, nombre: p.nombre)),`.

`usuarios_screen.dart` — imports `../../providers/sesion_provider.dart`, `../../ui/colores_app.dart`, `../../ui/pildora.dart`. En `build`, `final actual = ref.watch(sesionProvider).usuarioActivo?.id;` y cada fila:

```dart
                      ListTile(
                        key: Key('usuario_item_${u.id}'),
                        leading: AvatarInicial(id: u.id, nombre: u.nombre),
                        title: Text(
                            u.id == actual ? '${u.nombre} (tú)' : u.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Pildora(
                              key: Key('rol_${u.id}'),
                              texto: etiquetaRol(u.rol),
                              color: u.rol == 'admin'
                                  ? ColoresApp.of(context).primario
                                  : ColoresApp.of(context).marcaVerde,
                            ),
                          ),
                        ),
                        trailing: const Icon(Icons.lock_reset_rounded),
                        onTap: () => _resetearPin(u),
                      ),
```

El diálogo de resetear PIN ya usa `FilledButton` para Guardar y la hoja ya usa `BotonPrincipal`: no se tocan.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/configuracion`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/proveedores_screen.dart lib/screens/configuracion/usuarios_screen.dart test/screens/configuracion
git commit -m "Add avatars, phone and supply pills to suppliers and role chips to users"
```

---

### Task 9: Respaldo, verificación y configurar QR

**Files:**
- Modify: `lib/screens/respaldo/respaldo_screen.dart`, `lib/screens/respaldo/verificar_telefono_screen.dart`, `lib/screens/qr/configurar_qr_screen.dart`
- Test: `test/screens/respaldo/respaldo_screen_test.dart`, `test/screens/qr/configurar_qr_screen_test.dart`

- [ ] **Step 1: Update and add tests**

`respaldo_screen_test.dart`, en la prueba "activo muestra el número…", reemplazar el toque final de desconectar por:

```dart
    expect(find.byKey(const Key('tarjeta_estado_respaldo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_desconectar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_desconectar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_activar_respaldo')), findsOneWidget);
```

y agregar:

```dart
  testWidgets('cancelar Desconectar deja el respaldo activo', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    await abrir(tester, nube);
    await tester.tap(find.byKey(const Key('boton_desconectar')));
    await tester.pumpAndSettle();
    expect(find.text('¿Desconectar el respaldo?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_respaldar_ahora')), findsOneWidget);
    expect(find.byKey(const Key('boton_activar_respaldo')), findsNothing);
  });
```

`configurar_qr_screen_test.dart`: reemplazar la espera del texto "Descarga tu QR desde la app de Nequi, Daviplata o tu banco y cárgalo aquí." por:

```dart
    expect(find.byKey(const Key('pasos_qr')), findsOneWidget);
    expect(find.text('Descarga tu QR de Nequi, Daviplata o tu banco'),
        findsOneWidget);
    expect(find.text('Cárgalo aquí'), findsOneWidget);
    expect(find.text('Cobra mostrándolo en la venta'), findsOneWidget);
```

y en la prueba que ya carga el QR agregar:

```dart
    expect(
        find.ancestor(
            of: find.byKey(const Key('vista_qr')),
            matching: find.byKey(const Key('tarjeta_qr_configurado'))),
        findsOneWidget);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/respaldo test/screens/qr/configurar_qr_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`respaldo_screen.dart`, en `_Activo.build`:
- La `Card` de estado pasa a:

```dart
        Card(
          key: const Key('tarjeta_estado_respaldo'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ColoresApp.of(context).entra.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_done_rounded,
                      size: 28, color: ColoresApp.of(context).entra),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Respaldo activo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(estado.telefono == null
                          ? 'Celular conectado'
                          : 'Celular: ${telefonoEnmascarado(estado.telefono!)}'),
                      const SizedBox(height: 4),
                      Text(
                        textoEstado,
                        key: const Key('texto_ultimo_respaldo'),
                        style: TextStyle(
                            color: ColoresApp.of(context).textoSecundario),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
```

- El botón Desconectar pasa a:

```dart
        BotonPrincipal(
          key: const Key('boton_desconectar'),
          texto: 'Desconectar',
          variante: VarianteBoton.contorno,
          onPressed: () async {
            final confirmado = await showDialog<bool>(
              context: context,
              builder: (contexto) => AlertDialog(
                title: const Text('¿Desconectar el respaldo?'),
                content: const Text(
                    'Tus datos se quedan en este celular, pero ya no se '
                    'guardará una copia en la nube.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(contexto, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('confirmar_desconectar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresApp.of(context).sale,
                      foregroundColor: ColoresApp.of(context).sobreSale,
                    ),
                    onPressed: () => Navigator.pop(contexto, true),
                    child: const Text('Desconectar'),
                  ),
                ],
              ),
            );
            if (confirmado == true) await notifier.desconectar();
          },
        ),
```

(Si `desconectar()` devuelve `void`, quitar el `await`.)

`verificar_telefono_screen.dart`: al comienzo de los `children` del `ListView`, agregar un ícono de cabecera:

```dart
          Center(
            child: Container(
              key: const Key('icono_verificacion'),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ColoresApp.of(context).primarioSuave,
                shape: BoxShape.circle,
              ),
              child: Icon(
                esperandoCodigo ? Icons.sms_rounded : Icons.phone_iphone_rounded,
                size: 32,
                color: ColoresApp.of(context).primario,
              ),
            ),
          ),
          const SizedBox(height: 16),
```

y el texto explicativo pasa a `style: TextStyle(fontSize: 16, color: ColoresApp.of(context).textoSecundario)`.

`configurar_qr_screen.dart` — import `../../ui/tema_app.dart` no hace falta. En `build`:
- Reemplazar el `Text('Descarga tu QR …')` por:

```dart
          Card(
            key: const Key('pasos_qr'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final (i, paso) in const [
                    'Descarga tu QR de Nequi, Daviplata o tu banco',
                    'Cárgalo aquí',
                    'Cobra mostrándolo en la venta',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                ColoresApp.of(context).primarioSuave,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: ColoresApp.of(context).primario)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(paso)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
```

- El `SizedBox(key: vista_qr, …)` queda dentro de:

```dart
            Container(
              key: const Key('tarjeta_qr_configurado'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColoresApp.blancoMarca,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: ColoresApp.of(context).texto.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: /* SizedBox vista_qr de hoy, sin cambios */,
            ),
```

- "Quitar QR" pasa a:

```dart
            BotonPrincipal(
              key: const Key('boton_quitar_qr'),
              texto: 'Quitar QR',
              variante: VarianteBoton.contorno,
              onPressed: _quitar,
            ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/respaldo test/screens/qr`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/respaldo lib/screens/qr/configurar_qr_screen.dart test/screens/respaldo test/screens/qr
git commit -m "Restyle backup and QR setup and confirm before disconnecting backup"
```

---

### Task 10: Modo oscuro y letra grande en administración; hoja de ruta

**Files:**
- Create: `test/screens/administracion_oscuro_test.dart`
- Modify: `docs/hoja-de-ruta.md`, `docs/superpowers/specs/2026-10-12-vecitienda-renovacion-r4-design.md` (estado)

- [ ] **Step 1: Write the tests**

`test/screens/administracion_oscuro_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:app_ventas/screens/configuracion/proveedores_screen.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_entrada_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/screens/inventario/pedido_sugerido_screen.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/screens/qr/configurar_qr_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Datos de ejemplo: tienda, proveedor con teléfono, tres productos
  /// controlados (uno agotado, uno bajo, uno bien) y una entrada.
  Future<({int coca, int entrada, Producto producto})> datos(
      ProviderContainer container) async {
    final ana = container.read(sesionProvider).usuarioActivo!;
    await ConfiguracionRepository(db)
        .guardarNombreTienda('Tienda Doña Rosa del Barrio');
    final prov = await ProveedorRepository(db)
        .crear(nombre: 'Distribuidora Postobón', telefono: '3001234567');
    final productos = ProductoRepository(db);
    Future<int> nuevo(String nombre, int precio) => productos.guardarProducto(
          nombre: nombre,
          precio: precio,
          proveedores: [
            ProveedorDeProducto(
                proveedorId: prov, precioCompra: 900, preferido: true),
          ],
        );
    final coca = await nuevo('Coca-Cola 1,5 litros familiar', 4500);
    final pan = await nuevo('Pan tajado integral', 600);
    final agua = await nuevo('Agua', 1500);
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 30, minimo: 5, por: ana);
    await inv.activarControl(agua, cantidad: 0, minimo: 3, por: ana);
    final entrada = await inv.recibirMercancia(
      proveedorId: prov,
      lineas: [LineaRecibida(productoId: coca, cantidad: 24, precioCompra: 900)],
      por: ana,
    );
    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(coca)))
        .getSingle();
    return (coca: coca, entrada: entrada, producto: producto);
  }

  /// Monta [construir] en 360×800 dp, tema oscuro y letra 2,0×.
  Future<void> montar(WidgetTester tester,
      Widget Function(({int coca, int entrada, Producto producto})) construir,
      {double escala = 2.0}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final d = await datos(container);
    await tester.pumpWidget(appDePrueba(
      container,
      tema: temaOscuro(),
      inicio: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: construir(d),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final pantallas =
      <String, Widget Function(({int coca, int entrada, Producto producto}))>{
    'inventario (por pedir)': (_) =>
        const Scaffold(body: InventarioScreen()),
    'detalle de inventario': (d) => DetalleInventarioScreen(productoId: d.coca),
    'recibir mercancía': (d) => RecibirMercanciaScreen(lineasIniciales: [
          LineaInicial(producto: d.producto, cantidad: 12, precio: 900),
        ]),
    'pedido sugerido': (_) => const PedidoSugeridoScreen(proveedor: null),
    'detalle de entrada': (d) => DetalleEntradaScreen(entradaId: d.entrada),
    'ajustes': (_) => const Scaffold(body: AjustesScreen()),
    'productos': (_) => const ProductosScreen(),
    'ficha de producto': (d) => ProductoScreen(producto: d.producto),
    'proveedores': (_) => const ProveedoresScreen(),
    'usuarios': (_) => const UsuariosScreen(),
    'configurar QR': (_) => const ConfigurarQrScreen(),
  };

  for (final MapEntry(key: nombre, value: construir) in pantallas.entries) {
    testWidgets('$nombre en oscuro con letra 2,0× no desborda',
        (tester) async {
      await montar(tester, construir);
      expect(tester.takeException(), isNull);
      expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark);
    });
  }

  testWidgets('inventario en la vista Todos con letra 2,0× no desborda',
      (tester) async {
    await montar(tester, (_) => const Scaffold(body: InventarioScreen()));
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

Nota: `ConfigurarQrScreen` usa `selectorImagenProvider`; si sin override falla al recuperar la imagen perdida, montar con `containerConSesion(db, overrides: [selectorImagenProvider.overrideWithValue(SelectorImagenFalso())])` siguiendo `test/screens/qr/configurar_qr_screen_test.dart` (y pasar `overrides` por `montar`). Respaldo y hoja de ajuste ya se cubren en sus propias pruebas; si una de estas pruebas falla por desborde, corregir el widget (envolver en `Flexible`/`Wrap`/`FittedBox`) y no la prueba.

- [ ] **Step 2: Run tests**

Run: `flutter test test/screens/administracion_oscuro_test.dart`
Expected: PASS. Si algo desborda: quitar temporalmente el `expect(tester.takeException(), isNull)` para ver "The relevant error-causing widget", corregir el widget, y volver a poner la verificación.

- [ ] **Step 3: Docs**

En `docs/hoja-de-ruta.md`: mover "Renovación: R4 (administración)" de "En curso" a "Hecho" (con el resto de tandas R1–R3b) y dejar "En curso" sin tanda de renovación. En la spec, `**Estado:** Implementado (falta el recorrido manual en un celular real)`.

- [ ] **Step 4: Full suite**

Run: `flutter test`
Expected: todas pasan (684 + las nuevas).

- [ ] **Step 5: Commit**

```bash
git add test/screens/administracion_oscuro_test.dart docs/hoja-de-ruta.md docs/superpowers/specs/2026-10-12-vecitienda-renovacion-r4-design.md
git commit -m "Check admin screens in dark mode at large text and mark R4 as implemented"
```
