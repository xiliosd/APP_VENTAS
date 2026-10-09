import 'package:flutter/material.dart';

import '../ui/colores_app.dart';
import '../ui/movimiento.dart';

/// Los 4 puntos del PIN. Un llenado rebota; cada aumento de [errores] los
/// sacude y los pinta de rojo un momento.
class IndicadoresPin extends StatefulWidget {
  const IndicadoresPin({super.key, required this.llenos, this.errores = 0});
  final int llenos;
  final int errores;
  @override
  State<IndicadoresPin> createState() => _IndicadoresPinState();
}

class _IndicadoresPinState extends State<IndicadoresPin>
    with SingleTickerProviderStateMixin {
  late final _sacudida = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  var _enError = false;

  static const _pasos = [0.0, -12.0, 12.0, -8.0, 8.0, -4.0, 4.0, 0.0];

  @override
  void didUpdateWidget(IndicadoresPin anterior) {
    super.didUpdateWidget(anterior);
    if (widget.errores > anterior.errores) {
      setState(() => _enError = true);
      if (Movimiento.reducido(context)) {
        // Sin sacudida: el rojo dura lo mismo que la sacudida.
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _enError = false);
        });
      } else {
        _sacudida.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _enError = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _sacudida.dispose();
    super.dispose();
  }

  double _desplazamiento(double t) {
    final pos = t * (_pasos.length - 1);
    final i = pos.floor().clamp(0, _pasos.length - 2);
    return _pasos[i] + (_pasos[i + 1] - _pasos[i]) * (pos - i);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return AnimatedBuilder(
      animation: _sacudida,
      builder: (context, hijo) => Transform.translate(
          offset: Offset(_desplazamiento(_sacudida.value), 0), child: hijo),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${i < widget.llenos}'),
                tween: Tween(begin: i < widget.llenos ? 1.3 : 1, end: 1),
                duration: Movimiento.duracion(context, Movimiento.media),
                curve: Movimiento.resorte,
                builder: (_, s, hijo) => Transform.scale(scale: s, child: hijo),
                child: Container(
                  key: Key('indicador_pin_$i'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _enError
                        ? c.sale
                        : i < widget.llenos
                            ? c.primario
                            : c.superficie,
                    border: Border.all(
                        color: _enError ? c.sale : (i < widget.llenos ? c.primario : c.borde),
                        width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
