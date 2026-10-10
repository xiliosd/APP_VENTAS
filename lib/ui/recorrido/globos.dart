import 'package:flutter/material.dart';

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
