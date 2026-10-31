import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../ui/titulo_seccion.dart';
import 'preguntas_frecuentes.dart';

/// Preguntas frecuentes de toda la app, por tema; cada una se abre y se
/// cierra. Es contenido fijo: funciona sin internet.
class PreguntasFrecuentesScreen extends StatelessWidget {
  const PreguntasFrecuentesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Preguntas frecuentes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final (i, tema) in temasAyuda.indexed) ...[
            if (i > 0) const SizedBox(height: 24),
            Semantics(
              header: true,
              child: TituloSeccion(tema.titulo.toUpperCase()),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (j, p) in tema.preguntas.indexed) ...[
                    if (j > 0) const Divider(height: 1),
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        p.pregunta,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Text(
                          p.respuesta,
                          style: TextStyle(
                            color: colores.textoSecundario,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
