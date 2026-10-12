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
