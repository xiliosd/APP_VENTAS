import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../../ui/movimiento.dart';
import '../../ui/tipografia.dart';

const _duracionCompleta = Duration(milliseconds: 1500);
const _duracionBreve = Duration(milliseconds: 500);
const _duracionQuieta = Duration(milliseconds: 300);

/// Entrada de la app: el toldo de la tienda se abre y aparece la marca.
/// Completa la primera vez; breve (toldo ya abierto) en cada arranque.
/// Un solo controlador dura todo el inicio: al completarse, o al tocar,
/// llama [onTerminar] una vez.
class InicioMarcaScreen extends StatefulWidget {
  const InicioMarcaScreen({
    super.key,
    required this.completa,
    required this.onTerminar,
  });

  final bool completa;
  final VoidCallback onTerminar;

  @override
  State<InicioMarcaScreen> createState() => _InicioMarcaScreenState();
}

class _InicioMarcaScreenState extends State<InicioMarcaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  bool _terminado = false;
  bool _arrancado = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed) _terminar();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    // La duración depende de "reducir movimiento", que llega por MediaQuery.
    _controlador.duration = Movimiento.reducido(context)
        ? _duracionQuieta
        : widget.completa
        ? _duracionCompleta
        : _duracionBreve;
    _controlador.forward();
  }

  void _terminar() {
    if (_terminado) return;
    _terminado = true;
    widget.onTerminar();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Valor de [intervalo] en este momento; quieto (1) si se pide no animar.
  double _tramo(double inicio, double fin, Curve curva) {
    if (Movimiento.reducido(context)) return 1;
    return Interval(inicio, fin, curve: curva).transform(_controlador.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _terminar,
      child: Scaffold(
        backgroundColor: c.fondo,
        body: AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            final completa = widget.completa;
            final toldo = completa ? _tramo(0, 0.3, Movimiento.resorte) : 1.0;
            final insignia = completa
                ? _tramo(0.23, 0.45, Movimiento.resorte)
                : _tramo(0, 0.6, Movimiento.resorte);
            final nombre = completa ? _tramo(0.33, 0.5, Curves.easeOut) : 1.0;
            final eslogan = completa ? _tramo(0.4, 0.57, Curves.easeOut) : 1.0;
            return LayoutBuilder(
              builder: (context, medidas) => Column(
                children: [
                  SizedBox(
                    height: medidas.maxHeight * 0.28,
                    width: double.infinity,
                    child: _Toldo(apertura: toldo),
                  ),
                  Expanded(
                    child: Semantics(
                      container: true,
                      label:
                          'VeciTienda, la tranquilidad de tu tienda, en tu '
                          'bolsillo',
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          // Con letra muy grande se encoge en vez de desbordar.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: insignia.clamp(0, 1),
                                  child: Transform.scale(
                                    scale: completa
                                        ? insignia
                                        : 0.6 + 0.4 * insignia,
                                    child: const _Insignia(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ExcludeSemantics(
                                  child: _Aparecer(
                                    valor: nombre,
                                    child: Text(
                                      'VeciTienda',
                                      style:
                                          estiloTitulo(
                                            tamano: 34,
                                            color: c.primario,
                                          ).copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontVariations: const [
                                              FontVariation('wght', 900),
                                            ],
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ExcludeSemantics(
                                  child: _Aparecer(
                                    valor: eslogan,
                                    child: Text(
                                      MarcaApp.slogan,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: c.textoSecundario,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Sube un poco y se hace visible según [valor] (0 → 1).
class _Aparecer extends StatelessWidget {
  const _Aparecer({required this.valor, required this.child});

  final double valor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: valor.clamp(0, 1),
    child: Transform.translate(
      offset: Offset(0, 16 * (1 - valor)),
      child: child,
    ),
  );
}

/// Seis gajos verdes y blancos que bajan desde arriba según [apertura].
class _Toldo extends StatelessWidget {
  const _Toldo({required this.apertura});

  final double apertura;

  @override
  Widget build(BuildContext context) {
    const radio = Radius.circular(40);
    return Transform(
      key: const Key('toldo_marca'),
      alignment: Alignment.topCenter,
      transform: Matrix4.diagonal3Values(1, apertura, 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 6; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i.isEven
                      ? ColoresApp.verdeMarca
                      : ColoresApp.blancoMarca,
                  border: i.isEven
                      ? null
                      : const Border(
                          left: BorderSide(
                            color: ColoresApp.verdeMarca,
                            width: 3,
                          ),
                          right: BorderSide(
                            color: ColoresApp.verdeMarca,
                            width: 3,
                          ),
                          bottom: BorderSide(
                            color: ColoresApp.verdeMarca,
                            width: 3,
                          ),
                        ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: radio,
                    bottomRight: radio,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// El isotipo en su insignia blanca.
class _Insignia extends StatelessWidget {
  const _Insignia();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('insignia_marca'),
    width: 96,
    height: 96,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ColoresApp.blancoMarca,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x401A539B),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Image.asset(
      'assets/marca/isotipo.png',
      semanticLabel: 'Logo de VeciTienda',
    ),
  );
}
