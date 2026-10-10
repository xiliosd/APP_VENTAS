# Renovación R2b — Recorrido de primer uso — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recorrido de primer uso en 4 pasos (tu tienda → primeros productos → venta de
práctica guiada con globos → globos del Inicio), omitible y repetible, sobre la app real.

**Architecture:** Un `recorridoProvider` persistido en `shared_preferences` guarda el paso.
**`HomeScreen` es el único que dirige el recorrido**: al montarse y cuando el paso cambia
estando el Inicio visible, abre la pantalla del paso pendiente o lanza los globos del Inicio.
Los globos son un sistema propio en `lib/ui/recorrido/`: `ObjetivoRecorrido` registra
elementos por id, `mostrarGlobos` inserta una `CapaGlobos` (velo con hueco + burbuja) en el
`Overlay` raíz y devuelve un `ControladorGlobos`. La venta de práctica reutiliza
`RegistrarVentaScreen(practica: true)`.

**Tech Stack:** Flutter 3.47, Riverpod 2, shared_preferences 2.5.5, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-10-vecitienda-renovacion-r2b-design.md`

## Global Constraints

- Sin dependencias nuevas ni cambios de esquema.
- Colores solo con `ColoresApp.of(context)`; nuevo token `velo` (claro `#B30F172A`, oscuro
  `#CC000000`). Prueba `colores_sueltos_test` vigente.
- Duraciones/curvas de `Movimiento`; con reducir movimiento, instantáneo.
- Botones ≥ 48 dp; letra grande sin desbordes; modo oscuro sin excepciones.
- Solo el administrador ve el recorrido. Restaurar un respaldo o instalaciones previas:
  `recorrido_paso` ausente → `ninguno` (nunca se muestra).
- La venta de práctica **no escribe nada** en la base (ventas, líneas, clientes, inventario).
- Tests primero; `flutter test` verde, `flutter analyze` limpio, APK compila.
- No aplicar `dart format` a archivos enteros.
- Rama `renovacion-r2b` desde `master`.

## Review Focus

- Cerrar la app a mitad del recorrido (en el paso 2 o 3) y volver a entrar con el PIN: se
  retoma ese paso una sola vez, sin pantallas duplicadas — Task 6.
- En la práctica, cerrar la hoja "¿Cómo paga?" sin elegir: el globo vuelve a "Toca Cobrar" y
  sigue sin guardarse nada — Task 5.
- La capa de globos debe quedar **encima** de la hoja "¿Cómo paga?" (ruta nueva) y no
  bloquear el toque en "Efectivo" — Task 5.
- Un vendedor que entra en un celular donde el admin dejó el recorrido a medias no ve nada —
  Task 6.
- Globos informativos: tocar dentro del hueco (p. ej. "+ Venta") **no** navega; solo
  "Siguiente" avanza — Task 2.

---

### Task 1: Token `velo` y estado del recorrido

**Files:**
- Modify: `lib/ui/colores_app.dart`, `test/ui/tema_app_test.dart`
- Create: `lib/providers/recorrido_provider.dart`, `test/providers/recorrido_provider_test.dart`

**Interfaces — Produces:**
- `ColoresApp.velo` (campo `Color`, en `claro`, `oscuro` y `lerp`).
- `enum PasoRecorrido { ninguno, productos, venta, inicio, hecho }`
- `final recorridoProvider = NotifierProvider<RecorridoNotifier, PasoRecorrido>`
- `RecorridoNotifier.iniciar()` (→ productos), `irA(PasoRecorrido)`, `saltar()` (→ hecho),
  todos `Future<void>`; `bool get enCurso` (productos/venta/inicio) como extensión
  `PasoRecorridoX.enCurso` sobre el enum.

- [ ] **Step 1: Crear la rama** — `git checkout -b renovacion-r2b`

- [ ] **Step 2: Tests (fallan)**

En `test/ui/tema_app_test.dart`, dentro del test `'la paleta clara es la de VeciTienda y la
oscura es Azul noche'` agregar:

```dart
expect(ColoresApp.claro.velo, const Color(0xB30F172A));
expect(ColoresApp.oscuro.velo, const Color(0xCC000000));
```

`test/providers/recorrido_provider_test.dart`:

```dart
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
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
  test('sin valor guardado no hay recorrido', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.ninguno);
    expect(c.read(recorridoProvider).enCurso, isFalse);
  });

  test('iniciar, avanzar y saltar se guardan', () async {
    final c = await contenedor({});
    addTearDown(c.dispose);
    final n = c.read(recorridoProvider.notifier);
    await n.iniciar();
    expect(c.read(recorridoProvider), PasoRecorrido.productos);
    expect(c.read(recorridoProvider).enCurso, isTrue);
    await n.irA(PasoRecorrido.venta);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recorrido_paso'), 'venta');
    await n.saltar();
    expect(c.read(recorridoProvider), PasoRecorrido.hecho);
    expect(prefs.getString('recorrido_paso'), 'hecho');
  });

  test('se retoma al reabrir', () async {
    final c = await contenedor({'recorrido_paso': 'inicio'});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.inicio);
  });

  test('un valor ilegible se toma como ninguno', () async {
    final c = await contenedor({'recorrido_paso': 'marte'});
    addTearDown(c.dispose);
    expect(c.read(recorridoProvider), PasoRecorrido.ninguno);
  });
}
```

- [ ] **Step 3: Run** `flutter test test/ui/tema_app_test.dart test/providers/recorrido_provider_test.dart` — Expected: FAIL de compilación.

- [ ] **Step 4: Implementar**

`colores_app.dart`: agregar `required this.velo,`, el campo

```dart
  /// Oscurecido detrás de los globos del recorrido.
  final Color velo;
```

`velo: Color(0xB30F172A),` en `claro`, `velo: Color(0xCC000000),` en `oscuro` y
`velo: l(velo, otro.velo),` en `lerp`.

`lib/providers/recorrido_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

/// Paso del recorrido de primer uso. `ninguno`: nunca empezó (instalaciones
/// previas o restauradas); `hecho`: terminado u omitido.
enum PasoRecorrido { ninguno, productos, venta, inicio, hecho }

extension PasoRecorridoX on PasoRecorrido {
  bool get enCurso =>
      this == PasoRecorrido.productos ||
      this == PasoRecorrido.venta ||
      this == PasoRecorrido.inicio;
}

const _clave = 'recorrido_paso';

class RecorridoNotifier extends Notifier<PasoRecorrido> {
  @override
  PasoRecorrido build() {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return PasoRecorrido.values
            .where((p) => p.name == guardado)
            .firstOrNull ??
        PasoRecorrido.ninguno;
  }

  Future<void> iniciar() => irA(PasoRecorrido.productos);

  Future<void> saltar() => irA(PasoRecorrido.hecho);

  Future<void> irA(PasoRecorrido paso) async {
    state = paso;
    await ref.read(preferenciasProvider).setString(_clave, paso.name);
  }
}

final recorridoProvider =
    NotifierProvider<RecorridoNotifier, PasoRecorrido>(RecorridoNotifier.new);
```

- [ ] **Step 5: Run** los mismos tests — Expected: PASS; `flutter analyze` limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/colores_app.dart lib/providers/recorrido_provider.dart test/ui/tema_app_test.dart test/providers/recorrido_provider_test.dart
git commit -m "Add the tour step state and the scrim color token"
```

---

### Task 2: Sistema de globos

**Files:**
- Create: `lib/ui/recorrido/objetivo_recorrido.dart`, `lib/ui/recorrido/globos.dart`,
  `test/ui/globos_test.dart`

**Interfaces:**
- Consumes: `ColoresApp.velo` (Task 1), `Movimiento`.
- Produces:
  - `ObjetivoRecorrido({required String id, required Widget child})`;
    `static BuildContext? ObjetivoRecorrido.contextoDe(String id)`.
  - `PasoGlobo({required List<String> objetivos, required String texto, bool deAccion = false})`.
  - `ControladorGlobos mostrarGlobos(BuildContext context, List<PasoGlobo> pasos, {VoidCallback? onTerminar, VoidCallback? onSaltar})`.
  - `ControladorGlobos`: `int get indice`, `bool get activo`, `void avanzar()`,
    `void irA(int indice)`, `void saltar()`, `void cerrar()`.
  - Claves: `capa_globos`, `velo_recorrido`, `burbuja_globo`, `boton_siguiente_globo`,
    `boton_saltar_recorrido`.

- [ ] **Step 1: Tests (fallan)** — `test/ui/globos_test.dart`:

```dart
import 'package:app_ventas/ui/recorrido/globos.dart';
import 'package:app_ventas/ui/recorrido/objetivo_recorrido.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int toquesA;
  late BuildContext contexto;

  Future<void> montar(WidgetTester tester, {ThemeData? tema, double letra = 1}) async {
    toquesA = 0;
    await tester.pumpWidget(MaterialApp(
      theme: tema ?? temaClaro(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(letra)),
        child: Scaffold(
          body: Builder(builder: (c) {
            contexto = c;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ObjetivoRecorrido(
                  id: 'a',
                  child: ElevatedButton(
                      onPressed: () => toquesA++, child: const Text('A')),
                ),
                const ObjetivoRecorrido(id: 'b', child: Text('B')),
              ],
            );
          }),
        ),
      ),
    ));
  }

  testWidgets('informativos: Siguiente avanza y Terminar cierra', (tester) async {
    await montar(tester);
    var terminado = false;
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Este es A'),
      PasoGlobo(objetivos: ['b'], texto: 'Este es B'),
    ], onTerminar: () => terminado = true);
    await tester.pumpAndSettle();
    expect(find.text('Este es A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(find.text('Este es B'), findsOneWidget);
    expect(find.text('Terminar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(terminado, isTrue);
    expect(ctrl.activo, isFalse);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('informativo: tocar dentro del hueco no llega al objetivo',
      (tester) async {
    await montar(tester);
    mostrarGlobos(contexto, const [PasoGlobo(objetivos: ['a'], texto: 'A')]);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('A').first));
    await tester.pumpAndSettle();
    expect(toquesA, 0);
  });

  testWidgets('de acción: el toque en el hueco llega; fuera no hace nada',
      (tester) async {
    await montar(tester);
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Toca A', deAccion: true),
      PasoGlobo(objetivos: ['b'], texto: 'Mira B'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_siguiente_globo')), findsNothing);
    await tester.tapAt(const Offset(780, 300)); // fuera del hueco y de la burbuja
    await tester.pumpAndSettle();
    expect(toquesA, 0);
    await tester.tapAt(tester.getCenter(find.widgetWithText(ElevatedButton, 'A')));
    await tester.pumpAndSettle();
    expect(toquesA, 1);
    ctrl.avanzar(); // la pantalla avisa que se hizo la acción
    await tester.pumpAndSettle();
    expect(find.text('Mira B'), findsOneWidget);
  });

  testWidgets('usa la alternativa y salta pasos sin objetivo', (tester) async {
    await montar(tester);
    var terminado = false;
    mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['x', 'b'], texto: 'Alternativa B'),
      PasoGlobo(objetivos: ['z'], texto: 'Nunca'),
    ], onTerminar: () => terminado = true);
    await tester.pumpAndSettle();
    expect(find.text('Alternativa B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(find.text('Nunca'), findsNothing);
    expect(terminado, isTrue);
  });

  testWidgets('Saltar recorrido llama onSaltar y quita la capa', (tester) async {
    await montar(tester);
    var saltado = false;
    mostrarGlobos(contexto, const [PasoGlobo(objetivos: ['a'], texto: 'A')],
        onSaltar: () => saltado = true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(saltado, isTrue);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('irA vuelve a un paso anterior', (tester) async {
    await montar(tester);
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Uno'),
      PasoGlobo(objetivos: ['b'], texto: 'Dos'),
    ]);
    await tester.pumpAndSettle();
    ctrl.avanzar();
    await tester.pumpAndSettle();
    ctrl.irA(0);
    await tester.pumpAndSettle();
    expect(find.text('Uno'), findsOneWidget);
    expect(ctrl.indice, 0);
  });

  testWidgets('oscuro y letra grande sin excepciones', (tester) async {
    await montar(tester, tema: temaOscuro(), letra: 1.6);
    mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['b'], texto: 'Un texto largo para ver cómo se acomoda la burbuja con letra grande'),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/ui/globos_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`lib/ui/recorrido/objetivo_recorrido.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Marca un elemento que los globos del recorrido pueden señalar por [id].
class ObjetivoRecorrido extends StatefulWidget {
  const ObjetivoRecorrido({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  static final _registro = <String, GlobalKey>{};

  /// Contexto del elemento montado con [id], o null si no está.
  static BuildContext? contextoDe(String id) => _registro[id]?.currentContext;

  @override
  State<ObjetivoRecorrido> createState() => _ObjetivoRecorridoState();
}

class _ObjetivoRecorridoState extends State<ObjetivoRecorrido> {
  final _clave = GlobalKey();

  @override
  void initState() {
    super.initState();
    ObjetivoRecorrido._registro[widget.id] = _clave;
  }

  @override
  void didUpdateWidget(ObjetivoRecorrido anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.id != widget.id) {
      _quitar(anterior.id);
      ObjetivoRecorrido._registro[widget.id] = _clave;
    }
  }

  void _quitar(String id) {
    if (ObjetivoRecorrido._registro[id] == _clave) {
      ObjetivoRecorrido._registro.remove(id);
    }
  }

  @override
  void dispose() {
    _quitar(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _clave, child: widget.child);
}
```

`lib/ui/recorrido/globos.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../colores_app.dart';
import '../movimiento.dart';
import 'objetivo_recorrido.dart';

/// Un globo del recorrido: señala el primer objetivo de [objetivos] que esté
/// montado. Los de acción no tienen "Siguiente": avanzan cuando la pantalla
/// llama a [ControladorGlobos.avanzar], y el toque en el hueco llega al
/// elemento.
class PasoGlobo {
  const PasoGlobo(
      {required this.objetivos, required this.texto, this.deAccion = false});

  final List<String> objetivos;
  final String texto;
  final bool deAccion;
}

/// Muestra los globos [pasos] encima de todo y devuelve su controlador.
ControladorGlobos mostrarGlobos(BuildContext context, List<PasoGlobo> pasos,
    {VoidCallback? onTerminar, VoidCallback? onSaltar}) {
  final ctrl = ControladorGlobos._(Overlay.of(context, rootOverlay: true),
      pasos, onTerminar, onSaltar);
  ctrl._mostrar();
  return ctrl;
}

class ControladorGlobos {
  ControladorGlobos._(this._overlay, this._pasos, this._onTerminar, this._onSaltar);

  final OverlayState _overlay;
  final List<PasoGlobo> _pasos;
  final VoidCallback? _onTerminar;
  final VoidCallback? _onSaltar;
  OverlayEntry? _entrada;
  int _indice = 0;
  bool _cerrado = false;

  int get indice => _indice;
  bool get activo => !_cerrado;

  static BuildContext? _contexto(PasoGlobo paso) {
    for (final id in paso.objetivos) {
      final c = ObjetivoRecorrido.contextoDe(id);
      if (c != null && c.mounted) return c;
    }
    return null;
  }

  /// Quita la capa y la vuelve a insertar en el siguiente cuadro, así queda
  /// encima de rutas nuevas (por ejemplo una hoja que se acaba de abrir).
  void _mostrar() {
    _entrada?.remove();
    _entrada = null;
    if (_cerrado) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_cerrado) return;
      while (_indice < _pasos.length && _contexto(_pasos[_indice]) == null) {
        _indice++;
      }
      if (_indice >= _pasos.length) {
        _terminar();
        return;
      }
      final objetivo = _contexto(_pasos[_indice])!;
      await Scrollable.ensureVisible(objetivo,
          alignment: 0.5,
          duration: Movimiento.duracion(objetivo, Movimiento.media));
      if (_cerrado || _entrada != null) return;
      final paso = _pasos[_indice];
      final esUltimo = _indice == _pasos.length - 1;
      _entrada = OverlayEntry(
        builder: (_) => CapaGlobos(
          paso: paso,
          esUltimo: esUltimo,
          onSiguiente: avanzar,
          onSaltar: saltar,
        ),
      );
      _overlay.insert(_entrada!);
    });
  }

  void avanzar() {
    if (_cerrado) return;
    _indice++;
    if (_indice >= _pasos.length) {
      _terminar();
    } else {
      _mostrar();
    }
  }

  void irA(int indice) {
    if (_cerrado) return;
    _indice = indice.clamp(0, _pasos.length - 1);
    _mostrar();
  }

  void saltar() {
    if (_cerrado) return;
    cerrar();
    _onSaltar?.call();
  }

  void _terminar() {
    cerrar();
    _onTerminar?.call();
  }

  void cerrar() {
    _cerrado = true;
    _entrada?.remove();
    _entrada = null;
  }
}

/// Velo con hueco sobre el objetivo y burbuja con el texto.
class CapaGlobos extends StatefulWidget {
  const CapaGlobos({
    super.key,
    required this.paso,
    required this.esUltimo,
    required this.onSiguiente,
    required this.onSaltar,
  });

  final PasoGlobo paso;
  final bool esUltimo;
  final VoidCallback onSiguiente;
  final VoidCallback onSaltar;

  @override
  State<CapaGlobos> createState() => _CapaGlobosState();
}

class _CapaGlobosState extends State<CapaGlobos> {
  Rect? _hueco;

  @override
  void initState() {
    super.initState();
    _medir();
    WidgetsBinding.instance.addPostFrameCallback(_cadaCuadro);
  }

  /// Vuelve a medir en cada cuadro que ocurra (scroll, teclado) sin pedir
  /// cuadros nuevos, para no impedir que la app quede quieta.
  void _cadaCuadro(Duration _) {
    if (!mounted) return;
    _medir();
    WidgetsBinding.instance.addPostFrameCallback(_cadaCuadro);
  }

  void _medir() {
    Rect? rect;
    for (final id in widget.paso.objetivos) {
      final caja = ObjetivoRecorrido.contextoDe(id)?.findRenderObject();
      if (caja is RenderBox && caja.attached && caja.hasSize) {
        rect = (caja.localToGlobal(Offset.zero) & caja.size).inflate(8);
        break;
      }
    }
    if (rect != _hueco) setState(() => _hueco = rect);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final pantalla = MediaQuery.sizeOf(context);
    final hueco = _hueco;
    final ancho = (pantalla.width - 32).clamp(0.0, 320.0);
    final centroX = hueco?.center.dx ?? pantalla.width / 2;
    final izquierda =
        (centroX - ancho / 2).clamp(16.0, pantalla.width - 16 - ancho);
    final arriba = hueco != null && hueco.top > pantalla.height - hueco.bottom;

    final burbuja = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: Movimiento.duracion(context, Movimiento.media),
      curve: Movimiento.resorte,
      builder: (_, escala, hijo) => Transform.scale(scale: escala, child: hijo),
      child: Material(
        key: const Key('burbuja_globo'),
        color: c.superficie,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(widget.paso.texto,
                      style: TextStyle(fontSize: 16, color: c.texto)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const Key('boton_saltar_recorrido'),
                    onPressed: widget.onSaltar,
                    child: const Text('Saltar recorrido'),
                  ),
                  if (!widget.paso.deAccion)
                    FilledButton(
                      key: const Key('boton_siguiente_globo'),
                      onPressed: widget.onSiguiente,
                      child: Text(widget.esUltimo ? 'Terminar' : 'Siguiente'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      key: const Key('capa_globos'),
      children: [
        Positioned.fill(
          child: _Velo(
            key: const Key('velo_recorrido'),
            hueco: hueco,
            color: c.velo,
            dejaPasar: widget.paso.deAccion,
          ),
        ),
        Positioned(
          left: izquierda,
          width: ancho,
          top: hueco == null ? null : (arriba ? null : hueco.bottom + 12),
          bottom: hueco == null
              ? pantalla.height / 3
              : (arriba ? pantalla.height - hueco.top + 12 : null),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: pantalla.height * 0.45),
            child: SingleChildScrollView(child: burbuja),
          ),
        ),
      ],
    );
  }
}

/// Oscurece toda la pantalla salvo [hueco]. Absorbe los toques fuera del
/// hueco; dentro, los deja pasar solo si [dejaPasar] (globos de acción).
class _Velo extends LeafRenderObjectWidget {
  const _Velo(
      {super.key, required this.hueco, required this.color, required this.dejaPasar});

  final Rect? hueco;
  final Color color;
  final bool dejaPasar;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVelo(hueco, color, dejaPasar);

  @override
  void updateRenderObject(BuildContext context, _RenderVelo render) {
    render
      ..hueco = hueco
      ..color = color
      ..dejaPasar = dejaPasar;
  }
}

class _RenderVelo extends RenderBox {
  _RenderVelo(this._hueco, this._color, this._dejaPasar);

  Rect? _hueco;
  Color _color;
  bool _dejaPasar;

  set hueco(Rect? valor) {
    if (valor == _hueco) return;
    _hueco = valor;
    markNeedsPaint();
  }

  set color(Color valor) {
    if (valor == _color) return;
    _color = valor;
    markNeedsPaint();
  }

  set dejaPasar(bool valor) => _dejaPasar = valor;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset posicion) {
    final hueco = _hueco;
    if (_dejaPasar && hueco != null) {
      final global = localToGlobal(posicion);
      if (hueco.contains(global)) return false;
    }
    return true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final todo = Path()..addRect(offset & size);
    final hueco = _hueco;
    final camino = hueco == null
        ? todo
        : Path.combine(
            PathOperation.difference,
            todo,
            Path()
              ..addRRect(RRect.fromRectAndRadius(
                  hueco.shift(offset - localToGlobal(Offset.zero)),
                  const Radius.circular(18))),
          );
    context.canvas.drawPath(camino, Paint()..color = _color);
  }
}
```

Nota: el hueco está en coordenadas globales; `shift(offset - localToGlobal(Offset.zero))`
lo pasa a las del lienzo del velo.

- [ ] **Step 4: Run** `flutter test test/ui/globos_test.dart` — Expected: PASS. `flutter analyze` limpio.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/recorrido test/ui/globos_test.dart
git commit -m "Add a lightweight spotlight tour with targets, scrim and bubbles"
```

---

### Task 3: Paso 1 · Tu tienda e indicador de pasos

**Files:**
- Create: `lib/screens/recorrido/indicador_pasos.dart`
- Move: `lib/screens/login/crear_admin_inicial_screen.dart` → `lib/screens/recorrido/paso_tienda_screen.dart` (clase `PasoTiendaScreen`)
- Move: `test/screens/login/crear_admin_inicial_screen_test.dart` → `test/screens/recorrido/paso_tienda_screen_test.dart`
- Modify: `lib/screens/login/bienvenida_screen.dart`

**Interfaces:**
- Consumes: `recorridoProvider` (Task 1).
- Produces: `IndicadorPasos({required int paso, int total = 4})` (clave `indicador_pasos`,
  texto "Paso N de 4", `LinearProgressIndicator` con `value: paso / total`);
  `PasoTiendaScreen` (mismas claves de campos que hoy).

- [ ] **Step 1:** `git mv` de los dos archivos; renombrar la clase a `PasoTiendaScreen` en la
pantalla, en `bienvenida_screen.dart` y en la prueba.

- [ ] **Step 2: Tests (fallan)** en `paso_tienda_screen_test.dart`: el montaje agrega
`SharedPreferences.setMockInitialValues({})` y `preferenciasProvider.overrideWithValue(prefs)`;
en el test que crea el admin agregar:

```dart
expect(find.text('Paso 1 de 4'), findsOneWidget);
// … tras tocar Continuar:
expect(container.read(recorridoProvider), PasoRecorrido.productos);
```

y en el de "sin nombre de tienda":
`expect(container.read(recorridoProvider), PasoRecorrido.ninguno);`.
El botón pasa a decir "Continuar" (actualizar el `find.text('Crear tienda')` si el test lo usa;
conservar la clave del botón).

- [ ] **Step 3: Run** `flutter test test/screens/recorrido` — Expected: FAIL.

- [ ] **Step 4: Implementar**

`indicador_pasos.dart`:

```dart
import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';

/// "Paso N de 4" con una barra de avance.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.paso, this.total = 4});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Column(
      key: const Key('indicador_pasos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paso $paso de $total',
            style: TextStyle(
                color: c.textoSecundario, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: paso / total,
            minHeight: 6,
            color: c.primario,
            backgroundColor: c.primarioSuave,
          ),
        ),
      ],
    );
  }
}
```

`PasoTiendaScreen`: arriba de la marca `const IndicadorPasos(paso: 1)` + `SizedBox(height: 16)`;
texto del botón "Continuar"; en `_crear`, justo antes de `iniciarSesion`:
`await ref.read(recorridoProvider.notifier).iniciar();` (el `pop` final se conserva: el Inicio
que queda debajo abre el paso 2 — Task 6).

- [ ] **Step 5: Run** `flutter test test/screens/recorrido test/screens/login` — Expected: PASS.
(`test/widget_test.dart` se actualiza en la Task 7.)

- [ ] **Step 6: Commit**

```bash
git add -A lib/screens/recorrido lib/screens/login test/screens/recorrido test/screens/login
git commit -m "Turn store setup into step 1 of the first-run tour"
```

---

### Task 4: Paso 2 · Tus primeros productos

**Files:**
- Create: `lib/screens/recorrido/paso_productos_screen.dart`,
  `test/screens/recorrido/paso_productos_screen_test.dart`

**Interfaces:**
- Consumes: `IndicadorPasos` (Task 3), `recorridoProvider` (Task 1),
  `ProductoRepository.crearProducto({required String nombre, required int precio})`,
  `productosActivosProvider` (o el repositorio) para nombres existentes, `claveNombre`.
- Produces: `PasoProductosScreen` (claves `fila_nombre_{i}`, `fila_precio_{i}`,
  `boton_agregar_fila`, `boton_guardar_productos`, `boton_omitir_productos`; mensajes
  `error_fila_{i}`). Al terminar u omitir: `irA(venta)` y `pushReplacement` a
  `PasoVentaScreen` (Task 5; mientras no exista, `Navigator.pop`). Ver nota del Step 4.

- [ ] **Step 1: Tests (fallan)**

```dart
// montaje: containerConSesion(db, overrides: [preferenciasProvider…]) y
// appDePrueba(container, inicio: const PasoProductosScreen()); vista 411x914.

testWidgets('guarda solo las filas completas', (tester) async {
  await montar(tester);
  await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Gaseosa');
  await tester.enterText(find.byKey(const Key('fila_precio_0')), '2500');
  await tester.enterText(find.byKey(const Key('fila_nombre_2')), 'Pan');
  await tester.enterText(find.byKey(const Key('fila_precio_2')), '6000');
  await tester.tap(find.byKey(const Key('boton_guardar_productos')));
  await tester.pumpAndSettle();
  final productos = await db.select(db.productos).get();
  expect(productos.map((p) => (p.nombre, p.precio)),
      unorderedEquals([('Gaseosa', 2500), ('Pan', 6000)]));
  expect(container.read(recorridoProvider), PasoRecorrido.venta);
});

testWidgets('una fila a medias se marca y no avanza', (tester) async {
  await montar(tester);
  await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Leche');
  await tester.tap(find.byKey(const Key('boton_guardar_productos')));
  await tester.pumpAndSettle();
  expect(find.text('Falta el precio'), findsOneWidget);
  expect(await db.select(db.productos).get(), isEmpty);
  expect(container.read(recorridoProvider), isNot(PasoRecorrido.venta));
});

testWidgets('nombres repetidos o ya existentes se marcan', (tester) async {
  await db.into(db.productos).insert(ProductosCompanion.insert(nombre: 'Arroz', precio: 3900));
  await montar(tester);
  await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
  await tester.enterText(find.byKey(const Key('fila_precio_0')), '6000');
  await tester.enterText(find.byKey(const Key('fila_nombre_1')), ' pan ');
  await tester.enterText(find.byKey(const Key('fila_precio_1')), '6000');
  await tester.enterText(find.byKey(const Key('fila_nombre_2')), 'arroz');
  await tester.enterText(find.byKey(const Key('fila_precio_2')), '3900');
  await tester.tap(find.byKey(const Key('boton_guardar_productos')));
  await tester.pumpAndSettle();
  expect(find.text('Ya está en la lista'), findsNWidgets(2));
  expect(await db.select(db.productos).get(), hasLength(1));
});

testWidgets('Omitir no guarda y avanza', (tester) async {
  await montar(tester);
  await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
  await tester.tap(find.byKey(const Key('boton_omitir_productos')));
  await tester.pumpAndSettle();
  expect(await db.select(db.productos).get(), isEmpty);
  expect(container.read(recorridoProvider), PasoRecorrido.venta);
});

testWidgets('empieza con 3 filas y no pasa de 20', (tester) async {
  await montar(tester);
  expect(find.byKey(const Key('fila_nombre_2')), findsOneWidget);
  expect(find.byKey(const Key('fila_nombre_3')), findsNothing);
  for (var i = 0; i < 25; i++) {
    final boton = find.byKey(const Key('boton_agregar_fila'));
    if (boton.evaluate().isEmpty) break;
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump();
  }
  await tester.scrollUntilVisible(find.byKey(const Key('fila_nombre_19')), 200);
  expect(find.byKey(const Key('fila_nombre_19')), findsOneWidget);
  expect(find.byKey(const Key('fila_nombre_20')), findsNothing);
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar** `PasoProductosScreen` (`ConsumerStatefulWidget`):

- Estado: `final _filas = <(TextEditingController, TextEditingController)>[]` con 3 al
  inicio; `final _errores = <int, String>{}`; `bool _guardando`; `dispose` de todos.
- `build`: `Scaffold` con `SafeArea` → `ListView(padding: 24)`: `IndicadorPasos(paso: 2)`,
  título `estiloTitulo()` "Tus primeros productos", texto secundario "Escribe lo que más
  vendes. El costo, el proveedor y las existencias los completas después en Productos.";
  por fila: `Row(Expanded(flex 3, TextField(key: fila_nombre_i, labelText 'Producto')),
  SizedBox(8), Expanded(flex 2, TextField(key: fila_precio_i, labelText 'Precio',
  keyboardType: number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  prefixText: r'$ '))))` y, si hay error, `Text(error, key: error_fila_i, style: sale)`;
  `TextButton.icon(key: boton_agregar_fila, '+ Agregar otro')` solo si `_filas.length < 20`.
  Abajo (`bottomNavigationBar` con `SafeArea` y padding 16): `BotonPrincipal(key:
  boton_guardar_productos, 'Guardar y continuar')` y `TextButton(key: boton_omitir_productos,
  'Omitir')`.
- `_guardar()`:

```dart
Future<void> _guardar() async {
  if (_guardando) return;
  final existentes = {
    for (final p in await ref.read(productoRepositoryProvider).productosActivos())
      claveNombre(p.nombre),
  };
  final errores = <int, String>{};
  final vistos = <String>{};
  final nuevos = <(String, int)>[];
  for (var i = 0; i < _filas.length; i++) {
    final nombre = _filas[i].$1.text.trim();
    final precio = int.tryParse(_filas[i].$2.text) ?? 0;
    if (nombre.isEmpty && _filas[i].$2.text.isEmpty) continue;
    if (nombre.isEmpty) {
      errores[i] = 'Falta el nombre';
    } else if (precio <= 0) {
      errores[i] = 'Falta el precio';
    } else if (existentes.contains(claveNombre(nombre)) ||
        !vistos.add(claveNombre(nombre))) {
      errores[i] = 'Ya está en la lista';
    } else {
      nuevos.add((nombre, precio));
    }
  }
  setState(() => _errores..clear()..addAll(errores));
  if (errores.isNotEmpty) return;
  _guardando = true;
  final repo = ref.read(productoRepositoryProvider);
  for (final (nombre, precio) in nuevos) {
    await repo.crearProducto(nombre: nombre, precio: precio);
  }
  await _seguir();
}
```

  Nota: en "nombres repetidos" la primera aparición ("Pan") es válida y la segunda (" pan ")
  es la repetida; la de "arroz" choca con el existente → 2 errores. El test espera que se
  guarde 1 producto **en total** contando el existente, es decir **ninguno nuevo** (no se
  guarda nada si hay errores).
  Usar el método real del repositorio para listar productos activos (leer
  `producto_repository.dart`; si se llama distinto, usar ese nombre).
- `_seguir()`: `await ref.read(recorridoProvider.notifier).irA(PasoRecorrido.venta);` y
  `if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PasoVentaScreen()));`
  — hasta que exista `PasoVentaScreen` (Task 5), usar `Navigator.of(context).pop()` y cambiar a
  `pushReplacement` en la Task 5.
- "Omitir" llama a `_seguir()`.

- [ ] **Step 4: Run** `flutter test test/screens/recorrido` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/recorrido/paso_productos_screen.dart test/screens/recorrido/paso_productos_screen_test.dart
git commit -m "Add the quick first-products step"
```

---

### Task 5: Paso 3 · Venta de práctica guiada

**Files:**
- Create: `lib/screens/recorrido/paso_venta_screen.dart`, `lib/screens/recorrido/globos_venta.dart`,
  `test/screens/recorrido/practica_test.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart`, `lib/screens/venta/hoja_como_paga.dart`,
  `lib/widgets/monto_rapido_grid.dart`, `lib/screens/recorrido/paso_productos_screen.dart`

**Interfaces:**
- Consumes: `mostrarGlobos`, `PasoGlobo`, `ControladorGlobos`, `ObjetivoRecorrido` (Task 2),
  `recorridoProvider` (Task 1), `IndicadorPasos` (Task 3).
- Produces: `RegistrarVentaScreen({bool practica = false})`; `PasoVentaScreen`; constante
  `globosVenta` (lista de `PasoGlobo`); claves `franja_practica`, `hoja_asi_de_facil`,
  `boton_continuar_practica`, `boton_empezar_practica`, `boton_omitir_practica`;
  objetivos `primer_producto`, `monto_rapido_{monto}`, `boton_cobrar`, `pago_efectivo`.

- [ ] **Step 1: Tests (fallan)** — `practica_test.dart` (montaje con `containerConSesion`
+ `preferenciasProvider`, vista 411x914, un producto "Pan" $6.000; abre
`RegistrarVentaScreen(practica: true)` con `navegador.currentState!.push`):

```dart
Future<void> cobrarPractica(WidgetTester tester, String clave) async {
  await tester.tap(find.text('Pan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

Future<void> sinNadaGuardado() async {
  expect(await db.select(db.ventas).get(), isEmpty);
  expect(await db.select(db.lineasVenta).get(), isEmpty);
  expect(await db.select(db.clientes).get(), isEmpty);
}

testWidgets('muestra la franja de práctica y el primer globo', (tester) async {
  await abrirPractica(tester);
  expect(find.byKey(const Key('franja_practica')), findsOneWidget);
  expect(find.text('Toca un producto para sumarlo al ticket.'), findsOneWidget);
});

testWidgets('efectivo: no guarda nada y muestra ¡Así de fácil!', (tester) async {
  await abrirPractica(tester);
  await cobrarPractica(tester, 'pago_efectivo');
  expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
  await sinNadaGuardado();
  await tester.tap(find.byKey(const Key('boton_continuar_practica')));
  await tester.pumpAndSettle();
  expect(find.byType(RegistrarVentaScreen), findsNothing);
  expect(container.read(recorridoProvider), PasoRecorrido.inicio);
  await sinNadaGuardado();
});

testWidgets('transferencia: no abre el QR ni guarda', (tester) async {
  await abrirPractica(tester);
  await cobrarPractica(tester, 'pago_transferencia');
  expect(find.byKey(const Key('imagen_qr')), findsNothing);
  expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
  await sinNadaGuardado();
});

testWidgets('fiado con cliente escrito: no crea cliente ni venta', (tester) async {
  await abrirPractica(tester);
  await tester.tap(find.text('Pan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pago_fiado')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_fiar')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
  await sinNadaGuardado();
});

testWidgets('los globos guían: producto → Cobrar → Efectivo', (tester) async {
  await abrirPractica(tester);
  await tester.tap(find.text('Pan'));
  await tester.pumpAndSettle();
  expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  expect(find.text('Elige cómo paga. Toca Efectivo.'), findsOneWidget);
  // La capa queda encima de la hoja y no tapa Efectivo.
  await tester.tap(find.byKey(const Key('pago_efectivo')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
});

testWidgets('cerrar la hoja sin elegir vuelve al globo de Cobrar', (tester) async {
  await abrirPractica(tester);
  await tester.tap(find.text('Pan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  // Cerrar la hoja (Navigator.pop de la ruta de la hoja).
  navegador.currentState!.pop();
  await tester.pumpAndSettle();
  expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
  await sinNadaGuardado();
});

testWidgets('Saltar recorrido en la práctica cierra y marca hecho', (tester) async {
  await abrirPractica(tester);
  await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
  await tester.pumpAndSettle();
  expect(container.read(recorridoProvider), PasoRecorrido.hecho);
  expect(find.byType(RegistrarVentaScreen), findsNothing);
});

testWidgets('sin productos el primer globo señala un monto rápido', (tester) async {
  // sin insertar "Pan"
  await abrirPractica(tester, conProducto: false);
  expect(find.text('Toca un producto para sumarlo al ticket.'), findsOneWidget);
  await tester.tap(find.byKey(const Key('monto_rapido_1000')));
  await tester.pumpAndSettle();
  expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
});
```

`PasoVentaScreen`:

```dart
testWidgets('PasoVenta: Empezar abre la práctica; Omitir pasa al Inicio', (tester) async {
  // montar con recorrido en 'venta' e inicio: const PasoVentaScreen()
  expect(find.text('Paso 3 de 4'), findsOneWidget);
  await tester.tap(find.byKey(const Key('boton_empezar_practica')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('franja_practica')), findsOneWidget);
});
```

y otro que toca `boton_omitir_practica` y espera `PasoRecorrido.inicio` y que la pantalla se
cierre.

- [ ] **Step 2: Run** `flutter test test/screens/recorrido/practica_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implementar**

`globos_venta.dart`:

```dart
import '../../ui/recorrido/globos.dart';

/// Globos de la venta de práctica (todos de acción).
const globosVenta = [
  PasoGlobo(
      objetivos: ['primer_producto', 'monto_rapido_1000'],
      texto: 'Toca un producto para sumarlo al ticket.',
      deAccion: true),
  PasoGlobo(
      objetivos: ['boton_cobrar'],
      texto: 'Aquí ves el total. Toca Cobrar.',
      deAccion: true),
  PasoGlobo(
      objetivos: ['pago_efectivo'],
      texto: 'Elige cómo paga. Toca Efectivo.',
      deAccion: true),
];
```

Objetivos:
- `registrar_venta_screen.dart`: el primer `Mosaico` de producto visible envuelto en
  `ObjetivoRecorrido(id: 'primer_producto', child: …)`; el `BotonPrincipal(key: boton_cobrar)`
  envuelto en `ObjetivoRecorrido(id: 'boton_cobrar', …)`.
- `monto_rapido_grid.dart`: cada `Mosaico` envuelto en `ObjetivoRecorrido(id: 'monto_rapido_$monto', …)`.
- `hoja_como_paga.dart`: la `_Opcion` de efectivo envuelta en `ObjetivoRecorrido(id: 'pago_efectivo', …)`.

`RegistrarVentaScreen`:
- Parámetro `final bool practica;` (default `false`).
- Estado `ControladorGlobos? _globos;` — en `initState`, si `practica`:
  `WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; _globos = mostrarGlobos(context, globosVenta, onSaltar: _saltarRecorrido); });`
  y `dispose`: `_globos?.cerrar();`.
- `_saltarRecorrido()`: `ref.read(recorridoProvider.notifier).saltar(); Navigator.of(context).pop();`
- Avisos al controlador:
  - En `build`, `ref.listen(ticketProvider, (antes, ahora) { if (practica && _globos?.indice == 0 && (antes?.estaVacio ?? true) && !ahora.estaVacio) _globos!.avanzar(); });`
  - En `_alCobrar`, antes de `mostrarHojaComoPaga`: `if (widget.practica && _globos?.indice == 1) _globos!.avanzar();`
    (la capa se reinserta en el cuadro siguiente, encima de la hoja).
  - Si `forma == null` y práctica: `_globos?.irA(1);` (vuelve a "Toca Cobrar").
  - Si hay forma y práctica: `_globos?.cerrar();` y `await _terminarPractica();` en lugar de
    `_cobrar()` (no se fija medio ni se llama al repositorio ni a `abrirCobroQr`).
- `_terminarPractica()`:

```dart
Future<void> _terminarPractica() async {
  final ticket = ref.read(ticketProvider);
  await mostrarHojaInferior<void>(
    context,
    titulo: '¡Así de fácil!',
    descartable: false,
    builder: (contexto) => Column(
      key: const Key('hoja_asi_de_facil'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${plural(ticket.cantidadArticulos, 'artículo', 'artículos')} · '
            '${formatoMoneda(ticket.total)}'),
        const SizedBox(height: 4),
        Text('Esta venta fue de práctica, no quedó en tus cuentas.',
            style: TextStyle(color: ColoresApp.of(contexto).textoSecundario)),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_continuar_practica'),
          texto: 'Continuar',
          variante: VarianteBoton.entra,
          onPressed: () => Navigator.of(contexto).pop(),
        ),
      ],
    ),
  );
  if (!mounted) return;
  ref.read(ticketProvider.notifier).vaciar();
  Navigator.of(context).pop(true);
  await ref.read(recorridoProvider.notifier).irA(PasoRecorrido.inicio);
}
```

  (El `pop` va antes de `irA` para que el Inicio ya esté visible cuando reaccione — Task 6.)
- Franja: si `practica`, el `body` es `Column(children: [Container(key: franja_practica, width:
  double.infinity, color: c.fiadoSuave, padding: 8, child: Text('MODO PRÁCTICA · no se guarda',
  textAlign: center, style: TextStyle(color: c.fiado, fontWeight: w700))), Expanded(child:
  <ListView actual>)])`.

`PasoVentaScreen` (`ConsumerWidget`): `Scaffold` → `SafeArea` → `Padding(24)` →
`Column`: `IndicadorPasos(paso: 3)`, `Spacer`, `Icon(Icons.point_of_sale_rounded, size: 72,
color: c.primario)`, título "Hagamos una venta de práctica" (`estiloTitulo()`), "Así aprendes
a cobrar. No quedará en tus cuentas.", `Spacer`, `BotonPrincipal(key: boton_empezar_practica,
'Empezar', variante entra, onPressed: pushReplacement a RegistrarVentaScreen(practica: true))`,
`TextButton(key: boton_omitir_practica, 'Omitir', onPressed: () { Navigator.pop(context);
ref.read(recorridoProvider.notifier).irA(PasoRecorrido.inicio); })`.

`paso_productos_screen.dart`: `_seguir` usa ahora `pushReplacement` a `PasoVentaScreen`.

- [ ] **Step 4: Run** `flutter test test/screens/recorrido test/screens/venta` — Expected: PASS
(las pruebas existentes de Nueva venta no cambian: `practica` es `false` por defecto).

- [ ] **Step 5:** `flutter test` completo y `flutter analyze` — Expected: verde / limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/recorrido lib/screens/venta lib/widgets/monto_rapido_grid.dart test/screens/recorrido
git commit -m "Add a guided practice sale that saves nothing"
```

---

### Task 6: El Inicio dirige el recorrido, globos del Inicio y repetir

**Files:**
- Create: `lib/screens/recorrido/globos_inicio.dart`, `test/screens/recorrido/inicio_recorrido_test.dart`
- Modify: `lib/screens/home/home_screen.dart`, `lib/screens/home/resumen_screen.dart`,
  `lib/screens/configuracion/ajustes_screen.dart`

**Interfaces:**
- Consumes: `recorridoProvider`, `PasoRecorridoX.enCurso` (Task 1); `mostrarGlobos`,
  `ObjetivoRecorrido` (Task 2); `PasoProductosScreen` (Task 4); `PasoVentaScreen` (Task 5).
- Produces: `globosInicio`; claves `hoja_listo`, `boton_empezar_a_vender`,
  `boton_repetir_recorrido`; objetivos `tarjeta_ventas`, `boton_nueva_venta`,
  `pestana_fiado`, `menu_cuenta`.

- [ ] **Step 1: Tests (fallan)** — `inicio_recorrido_test.dart` (montaje con
`containerConSesion(db, rol:)` + `preferenciasProvider` con valores iniciales
`{'recorrido_paso': paso}`, `appDePrueba(container, inicio: const HomeScreen())`, vista 411x914):

```dart
testWidgets('con paso productos el Inicio abre el paso 2 una sola vez', (tester) async {
  await montar(tester, paso: 'productos');
  expect(find.byType(PasoProductosScreen), findsOneWidget);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  expect(find.byType(PasoProductosScreen), findsOneWidget);
});

testWidgets('con paso venta el Inicio abre el paso 3', (tester) async {
  await montar(tester, paso: 'venta');
  expect(find.byType(PasoVentaScreen), findsOneWidget);
});

testWidgets('globos del Inicio y ¡Listo!', (tester) async {
  await montar(tester, paso: 'inicio');
  expect(find.text('Aquí ves cuánto vendiste hoy y cómo vas frente a ayer.'), findsOneWidget);
  // "+ Venta" dentro del hueco no navega en un globo informativo.
  await tester.tapAt(tester.getCenter(find.byKey(const Key('boton_nueva_venta'))));
  await tester.pumpAndSettle();
  expect(find.byType(RegistrarVentaScreen), findsNothing);
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const Key('hoja_listo')), findsOneWidget);
  expect(container.read(recorridoProvider), PasoRecorrido.hecho);
  await tester.tap(find.byKey(const Key('boton_empezar_a_vender')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('hoja_listo')), findsNothing);
});

testWidgets('un vendedor no ve el recorrido pendiente', (tester) async {
  await montar(tester, paso: 'productos', rol: 'vendedor');
  expect(find.byType(PasoProductosScreen), findsNothing);
  expect(find.byKey(const Key('capa_globos')), findsNothing);
});

testWidgets('sin recorrido (instalación previa) no pasa nada', (tester) async {
  await montar(tester, paso: null);
  expect(find.byKey(const Key('capa_globos')), findsNothing);
  expect(find.byType(PasoProductosScreen), findsNothing);
});

testWidgets('Ver el recorrido otra vez abre la práctica sin recrear nada', (tester) async {
  await montar(tester, paso: 'hecho');
  await tester.tap(find.text('Ajustes'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('boton_repetir_recorrido')), 200);
  await tester.tap(find.byKey(const Key('boton_repetir_recorrido')));
  await tester.pumpAndSettle();
  expect(find.byType(PasoVentaScreen), findsOneWidget);
  expect(container.read(recorridoProvider), PasoRecorrido.venta);
  expect(await db.select(db.usuarios).get(), hasLength(1));
});
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implementar**

`globos_inicio.dart`:

```dart
import '../../ui/recorrido/globos.dart';

const globosInicio = [
  PasoGlobo(objetivos: ['tarjeta_ventas'],
      texto: 'Aquí ves cuánto vendiste hoy y cómo vas frente a ayer.'),
  PasoGlobo(objetivos: ['boton_nueva_venta'], texto: 'Registra cada venta aquí.'),
  PasoGlobo(objetivos: ['pestana_fiado'],
      texto: 'Aquí está lo que te deben tus clientes.'),
  PasoGlobo(objetivos: ['menu_cuenta'],
      texto: 'Tu cuenta: cerrar sesión y cambiar la apariencia.'),
];
```

Objetivos: en `resumen_screen.dart` envolver el `Container(key: tarjeta_ventas)` en
`ObjetivoRecorrido(id: 'tarjeta_ventas', …)` y el `BotonPrincipal(key: boton_nueva_venta)` en
`ObjetivoRecorrido(id: 'boton_nueva_venta', …)`; en `home_screen.dart` el ícono del destino
Fiado: `icon: t.titulo == 'Fiado' ? ObjetivoRecorrido(id: 'pestana_fiado', child: Icon(t.icono)) : Icon(t.icono)`
y `_MenuCuenta(...)` envuelto en `ObjetivoRecorrido(id: 'menu_cuenta', …)`.

`_HomeScreenState`:

```dart
bool _atendioAlMontar = false;
ControladorGlobos? _globos;

@override
void dispose() {
  _globos?.cerrar();
  super.dispose();
}

/// Abre el paso pendiente del recorrido (solo administrador).
void _atender(PasoRecorrido paso) {
  if (!ref.read(sesionProvider).esAdmin || !mounted) return;
  final navegador = Navigator.of(context);
  switch (paso) {
    case PasoRecorrido.productos:
      navegador.push(MaterialPageRoute(builder: (_) => const PasoProductosScreen()));
    case PasoRecorrido.venta:
      navegador.push(MaterialPageRoute(builder: (_) => const PasoVentaScreen()));
    case PasoRecorrido.inicio:
      if (_globos?.activo ?? false) return;
      setState(() => _tabActual = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _globos = mostrarGlobos(context, globosInicio,
            onTerminar: _terminarRecorrido,
            onSaltar: () => ref.read(recorridoProvider.notifier).saltar());
      });
    case PasoRecorrido.ninguno:
    case PasoRecorrido.hecho:
      break;
  }
}

Future<void> _terminarRecorrido() async {
  await ref.read(recorridoProvider.notifier).irA(PasoRecorrido.hecho);
  if (!mounted) return;
  await mostrarHojaInferior<void>(
    context,
    titulo: '¡Listo! Tu tienda está lista',
    builder: (contexto) => Column(
      key: const Key('hoja_listo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ya puedes vender, fiar y ver cómo va tu tienda.'),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_empezar_a_vender'),
          texto: 'Empezar a vender',
          variante: VarianteBoton.entra,
          onPressed: () => Navigator.of(contexto).pop(),
        ),
      ],
    ),
  );
}
```

En `build`, después de obtener la sesión:

```dart
ref.listen<PasoRecorrido>(recorridoProvider, (_, paso) {
  // Solo si el Inicio está a la vista: las pantallas de pasos encima se
  // encargan de su propia navegación.
  if (ModalRoute.of(context)?.isCurrent ?? true) _atender(paso);
});
if (!_atendioAlMontar) {
  _atendioAlMontar = true;
  final paso = ref.read(recorridoProvider);
  if (paso.enCurso) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _atender(paso));
  }
}
```

Nota: `PasoTiendaScreen` llama `iniciar()` (→ productos) **antes** de `iniciarSesion`, así el
`HomeScreen` se monta con `productos` y lo abre; el `pop` de `PasoTiendaScreen` ocurre después
(queda el paso 2 encima del Inicio). Si el `pop` cerrara el paso 2 (porque se empujó antes),
cambiar el orden en `PasoTiendaScreen`: hacer `pop` primero y luego `iniciarSesion`, o que
`_atender` use `addPostFrameCallback` doble. Verificarlo con el test completo de la Task 7.

`ajustes_screen.dart`: nueva sección (después de las existentes de la tienda) con
`ListTile(key: boton_repetir_recorrido, leading: Icon(Icons.tour_outlined), title: Text('Ver el recorrido otra vez'), subtitle: Text('Venta de práctica y guía del Inicio'), onTap: () => ref.read(recorridoProvider.notifier).irA(PasoRecorrido.venta))`
(el `HomeScreen`, que está a la vista, abre `PasoVentaScreen` vía `ref.listen`).

- [ ] **Step 4: Run** `flutter test test/screens/recorrido test/screens/home` — Expected: PASS.

- [ ] **Step 5:** `flutter test` completo y `flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens test/screens/recorrido
git commit -m "Let the home screen drive the tour, show home bubbles and allow replaying"
```

---

### Task 7: Recorrido completo, modo oscuro, cierre y APK

**Files:**
- Modify: `test/widget_test.dart`, `test/screens/modo_oscuro_test.dart`, `docs/hoja-de-ruta.md`,
  `docs/superpowers/specs/2026-10-10-vecitienda-renovacion-r2b-design.md` (Estado)

- [ ] **Step 1:** Reescribir `test/widget_test.dart` como el recorrido completo:

```dart
testWidgets('primer uso: Bienvenida → 4 pasos → ¡Listo!, sin ventas', (tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(overrides: [
    databaseProvider.overrideWithValue(db),
    preferenciasProvider.overrideWithValue(prefs),
  ], child: const AppVentas()));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('boton_crear_tienda')));
  await tester.pumpAndSettle();
  // Paso 1 (usar las claves reales de los campos de PasoTiendaScreen)
  await tester.enterText(find.byKey(const Key('campo_nombre_tienda')), 'La Esquina');
  await tester.enterText(find.byKey(const Key('campo_nombre')), 'Ana');
  await tester.enterText(find.byKey(const Key('campo_pin')), '1234');
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  // Paso 2
  expect(find.text('Paso 2 de 4'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
  await tester.enterText(find.byKey(const Key('fila_precio_0')), '6000');
  await tester.tap(find.byKey(const Key('boton_guardar_productos')));
  await tester.pumpAndSettle();
  // Paso 3
  expect(find.text('Paso 3 de 4'), findsOneWidget);
  await tester.tap(find.byKey(const Key('boton_empezar_practica')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pago_efectivo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton_continuar_practica')));
  await tester.pumpAndSettle();
  // Paso 4
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const Key('hoja_listo')), findsOneWidget);
  await tester.tap(find.byKey(const Key('boton_empezar_a_vender')));
  await tester.pumpAndSettle();

  expect(prefs.getString('recorrido_paso'), 'hecho');
  expect(await db.select(db.ventas).get(), isEmpty);
  expect(await db.select(db.productos).get(), hasLength(1));
});
```

(Leer las claves reales de los campos en `paso_tienda_screen.dart` y ajustar.)

- [ ] **Step 2:** En `modo_oscuro_test.dart` agregar un caso que monte `PasoProductosScreen`
y otro que monte `HomeScreen` con `recorrido_paso = 'inicio'` (agregar
`preferenciasProvider` al montaje) y verifique `capa_globos` sin excepciones.

- [ ] **Step 3: Run** `flutter test test/widget_test.dart test/screens/modo_oscuro_test.dart` —
Expected: PASS (si el paso 2 no aparece tras el paso 1, aplicar la nota de orden de la
Task 6 y registrar la decisión).

- [ ] **Step 4: Verificación completa** — `flutter analyze`, `flutter test`,
`flutter build apk --release`.

- [ ] **Step 5: Documentación** — hoja de ruta: "Hecho" + `- Renovación R2b — recorrido de
primer uso (tienda, primeros productos, venta de práctica guiada, guía del Inicio).`;
"En curso": `- Renovación: R3 (dinero), R4 (administración).`; "Pendiente de verificar":
agregar `renovación R2b (recorrido completo en un celular nuevo)`. Spec: `**Estado:**
Implementado (falta el recorrido manual en un celular real)`.

- [ ] **Step 6: Commit**

```bash
git add test docs
git commit -m "Cover the full first-run tour end to end and mark R2b as implemented"
```
