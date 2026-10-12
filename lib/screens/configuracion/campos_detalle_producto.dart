import 'package:flutter/material.dart';

import '../../util/catalogo_producto.dart';

/// Marca (con sugerencias), tamaño, envase y tipo. [sufijo] distingue las
/// claves cuando hay dos formularios (la hoja rápida usa "_rapido").
class CamposDetalleProducto extends StatefulWidget {
  const CamposDetalleProducto({
    super.key,
    required this.marca,
    required this.tamano,
    required this.envase,
    required this.tipo,
    required this.onEnvase,
    required this.onTipo,
    required this.marcas,
    this.sufijo = '',
  });

  final TextEditingController marca;
  final TextEditingController tamano;
  final String? envase;
  final String? tipo;
  final ValueChanged<String?> onEnvase;
  final ValueChanged<String?> onTipo;
  final List<String> marcas;
  final String sufijo;

  @override
  State<CamposDetalleProducto> createState() => _CamposDetalleProductoState();
}

class _CamposDetalleProductoState extends State<CamposDetalleProducto> {
  final _focoMarca = FocusNode();

  @override
  void dispose() {
    _focoMarca.dispose();
    super.dispose();
  }

  /// Selector de [opciones]; se reconstruye (con [ValueKey]) cuando el valor
  /// cambia desde afuera, p. ej. al autocompletar.
  Widget _selector({
    required String clave,
    required String etiqueta,
    required String? valor,
    required Map<String, String> opciones,
    required ValueChanged<String?> onCambio,
  }) {
    return KeyedSubtree(
      key: ValueKey('$clave=$valor'),
      child: DropdownButtonFormField<String?>(
        key: Key(clave),
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiqueta),
        items: [
          const DropdownMenuItem(value: null, child: Text('Sin elegir')),
          for (final MapEntry(:key, :value) in opciones.entries)
            DropdownMenuItem(value: key, child: Text(value)),
        ],
        onChanged: onCambio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sufijo = widget.sufijo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<String>(
          textEditingController: widget.marca,
          focusNode: _focoMarca,
          optionsBuilder: (valor) {
            final q = valor.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return widget.marcas.where(
                (m) => m.toLowerCase().contains(q) && m.toLowerCase() != q);
          },
          fieldViewBuilder: (context, controlador, foco, alEnviar) => TextField(
            key: Key('campo_marca$sufijo'),
            controller: controlador,
            focusNode: foco,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Marca'),
          ),
          optionsViewBuilder: (context, alElegir, opciones) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 200, maxWidth: 320),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in opciones)
                      ListTile(title: Text(o), onTap: () => alElegir(o)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key('campo_tamano$sufijo'),
          controller: widget.tamano,
          decoration: const InputDecoration(
            labelText: 'Tamaño',
            hintText: '1,5 L · 400 ml · 500 g',
          ),
        ),
        const SizedBox(height: 12),
        _selector(
          clave: 'selector_envase$sufijo',
          etiqueta: 'Envase',
          valor: widget.envase,
          opciones: envasesProducto,
          onCambio: widget.onEnvase,
        ),
        const SizedBox(height: 12),
        _selector(
          clave: 'selector_tipo$sufijo',
          etiqueta: 'Tipo',
          valor: widget.tipo,
          opciones: tiposProducto,
          onCambio: widget.onTipo,
        ),
      ],
    );
  }
}
