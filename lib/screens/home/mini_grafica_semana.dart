import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../ui/movimiento.dart';
import '../../util/formato_moneda.dart';

const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Barras de las ventas de los 7 días que terminan en [hasta]; la del día
/// elegido va en verde. Va sobre la tarjeta del día (fondo azul).
class MiniGraficaSemana extends StatelessWidget {
  const MiniGraficaSemana(
      {super.key, required this.valores, required this.hasta, this.onTap});

  final List<int> valores;
  final DateTime hasta;
  final VoidCallback? onTap;

  static const _altoMaximo = 44.0;
  static const _altoMinimo = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final maximo = valores.fold<int>(0, (m, v) => v > m ? v : m);
    final dias = [
      for (var i = 0; i < valores.length; i++)
        hasta.subtract(Duration(days: valores.length - 1 - i)),
    ];
    final descripcion = [
      for (var i = 0; i < valores.length; i++)
        '${_iniciales[dias[i].weekday - 1]} ${formatoMoneda(valores[i])}',
    ].join(', ');
    return Semantics(
      label: 'Ventas de los últimos 7 días: $descripcion',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Movimiento.duracion(context, Movimiento.larga),
          curve: Movimiento.resorte,
          builder: (context, avance, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _altoMaximo,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < valores.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            key: Key('barra_dia_$i'),
                            height: (maximo == 0 || valores[i] == 0
                                    ? _altoMinimo
                                    : (_altoMinimo +
                                        (valores[i] / maximo) *
                                            (_altoMaximo - _altoMinimo)) *
                                        avance.clamp(0.0, 1.2))
                                .clamp(_altoMinimo, _altoMaximo),
                            decoration: BoxDecoration(
                              color: i == valores.length - 1
                                  ? c.marcaVerde
                                  : c.sobreTarjetaPrincipal
                                      .withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                  bottom: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final d in dias)
                    Expanded(
                      child: Text(
                        _iniciales[d.weekday - 1],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.sobreTarjetaPrincipal.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
