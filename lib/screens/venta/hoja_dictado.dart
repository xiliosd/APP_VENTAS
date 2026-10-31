import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../ui/boton_cantidad.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../../util/interpretar_dictado.dart';

/// Lo que decidió el tendero en la hoja del dictado.
sealed class RespuestaDictado {
  const RespuestaDictado();
}

/// Agregar al ticket estas líneas.
class AgregarDictado extends RespuestaDictado {
  const AgregarDictado(this.lineas);

  final List<({Producto producto, int cantidad})> lineas;
}

/// Buscar a mano lo que no se encontró.
class BuscarDictado extends RespuestaDictado {
  const BuscarDictado(this.texto);

  final String texto;
}

/// Volver a escuchar.
class DictarOtraVez extends RespuestaDictado {
  const DictarOtraVez();
}

/// "¿Agrego esto?": nada entra al ticket sin pasar por aquí.
Future<RespuestaDictado?> mostrarHojaDictado(
  BuildContext context, {
  required String oido,
  required List<ParteDictada> partes,
}) => mostrarHojaInferior<RespuestaDictado>(
  context,
  titulo: '¿Agrego esto?',
  builder: (_) => _HojaDictado(oido: oido, partes: partes),
);

class _Fila {
  _Fila(this.parte)
    : cantidad = parte.cantidad,
      elegido = parte.tipo == TipoParteDictada.reconocida
          ? parte.opciones.single
          : null;

  final ParteDictada parte;
  int cantidad;
  Producto? elegido;
}

class _HojaDictado extends StatefulWidget {
  const _HojaDictado({required this.oido, required this.partes});

  final String oido;
  final List<ParteDictada> partes;

  @override
  State<_HojaDictado> createState() => _HojaDictadoState();
}

class _HojaDictadoState extends State<_HojaDictado> {
  late final List<_Fila> _filas = [for (final p in widget.partes) _Fila(p)];

  Iterable<_Fila> get _conProducto => _filas.where((f) => f.elegido != null);

  /// Hay algo por agregar y ninguna duda sin resolver.
  bool get _puedeAgregar =>
      _conProducto.isNotEmpty &&
      !_filas.any(
        (f) => f.parte.tipo == TipoParteDictada.dudosa && f.elegido == null,
      );

  int get _unidades => _conProducto.fold(0, (s, f) => s + f.cantidad);

  int get _total =>
      _conProducto.fold(0, (s, f) => s + f.cantidad * f.elegido!.precio);

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.oido, style: TextStyle(color: c.textoSecundario)),
        const SizedBox(height: 8),
        for (final (i, f) in _filas.indexed) _fila(context, i, f),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_agregar_dictado'),
          texto: 'Agregar al ticket ($_unidades)',
          variante: VarianteBoton.entra,
          onPressed: _puedeAgregar
              ? () => Navigator.pop(
                  context,
                  AgregarDictado([
                    for (final f in _conProducto)
                      (producto: f.elegido!, cantidad: f.cantidad),
                  ]),
                )
              : null,
        ),
        if (_conProducto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formatoMoneda(_total),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textoSecundario),
            ),
          ),
        TextButton.icon(
          key: const Key('boton_dictar_otra_vez'),
          onPressed: () => Navigator.pop(context, const DictarOtraVez()),
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Dictar otra vez'),
        ),
      ],
    );
  }

  Widget _fila(BuildContext context, int i, _Fila f) {
    final c = ColoresApp.of(context);
    if (f.parte.tipo == TipoParteDictada.noEncontrada) {
      return Card(
        child: ListTile(
          title: Text('No lo encontré: ${f.parte.texto}'),
          trailing: Wrap(
            spacing: 4,
            children: [
              TextButton(
                key: Key('buscar_dictado_$i'),
                onPressed: () =>
                    Navigator.pop(context, BuscarDictado(f.parte.texto)),
                child: const Text('Buscar'),
              ),
              IconButton(
                key: Key('quitar_no_encontrado_$i'),
                tooltip: 'Quitar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _filas.remove(f)),
              ),
            ],
          ),
        ),
      );
    }
    final elegido = f.elegido;
    final id = elegido?.id;
    // La clave por producto va adentro: dos filas pueden terminar con el
    // mismo producto y entre hermanas las claves no se pueden repetir.
    return Card(
      key: ObjectKey(f),
      child: KeyedSubtree(
        key: elegido == null
            ? Key('parte_dudosa_$i')
            : Key('parte_reconocida_$id'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.parte.tipo == TipoParteDictada.dudosa) ...[
                Text(
                  '¿Cuál ${f.parte.texto}?',
                  style: TextStyle(color: c.textoSecundario),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in f.parte.opciones)
                      ChoiceChip(
                        key: Key('opcion_dictado_${i}_${p.id}'),
                        label: Text(
                          [p.nombre, p.tamano].whereType<String>().join(' '),
                        ),
                        selected: elegido?.id == p.id,
                        onSelected: (_) => setState(() => f.elegido = p),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      elegido == null
                          ? 'Elige una opción'
                          : '${[elegido.nombre, elegido.tamano].whereType<String>().join(' ')} · '
                                '${formatoMoneda(elegido.precio)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  BotonCantidad(
                    key: Key('restar_dictado_${id ?? 'd$i'}'),
                    icono: Icons.remove_rounded,
                    tooltip: 'Restar',
                    onPressed: f.cantidad > 1
                        ? () => setState(() => f.cantidad--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Semantics(
                      label: 'Cantidad: ${f.cantidad}',
                      excludeSemantics: true,
                      child: Text(
                        '${f.cantidad}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  BotonCantidad(
                    key: Key('sumar_dictado_${id ?? 'd$i'}'),
                    icono: Icons.add_rounded,
                    tooltip: 'Sumar',
                    onPressed: f.cantidad < 99
                        ? () => setState(() => f.cantidad++)
                        : null,
                  ),
                  IconButton(
                    key: Key('quitar_dictado_${id ?? 'd$i'}'),
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _filas.remove(f)),
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
