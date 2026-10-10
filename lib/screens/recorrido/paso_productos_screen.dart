import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/recorrido_provider.dart';
import '../../providers/repository_providers.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../../util/texto_util.dart';
import 'indicador_pasos.dart';

/// Paso 2 del recorrido: cargar rápido los productos que más se venden,
/// solo con nombre y precio de venta.
class PasoProductosScreen extends ConsumerStatefulWidget {
  const PasoProductosScreen({super.key});

  @override
  ConsumerState<PasoProductosScreen> createState() =>
      _PasoProductosScreenState();
}

class _PasoProductosScreenState extends ConsumerState<PasoProductosScreen> {
  static const _filasIniciales = 3;
  static const _maximoFilas = 20;

  final _filas = <(TextEditingController, TextEditingController)>[];
  final _errores = <int, String>{};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _filasIniciales; i++) {
      _filas.add((TextEditingController(), TextEditingController()));
    }
  }

  @override
  void dispose() {
    for (final (nombre, precio) in _filas) {
      nombre.dispose();
      precio.dispose();
    }
    super.dispose();
  }

  void _agregarFila() {
    if (_filas.length >= _maximoFilas) return;
    setState(
        () => _filas.add((TextEditingController(), TextEditingController())));
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final repo = ref.read(productoRepositoryProvider);
    final existentes = {
      for (final p in await repo.listarTodos()) claveNombre(p.nombre),
    };
    final errores = <int, String>{};
    final vistos = <String>{};
    final nuevos = <(String, int)>[];
    for (var i = 0; i < _filas.length; i++) {
      final nombre = _filas[i].$1.text.trim();
      final textoPrecio = _filas[i].$2.text.trim();
      final precio = int.tryParse(textoPrecio) ?? 0;
      if (nombre.isEmpty && textoPrecio.isEmpty) continue;
      final clave = claveNombre(nombre);
      if (nombre.isEmpty) {
        errores[i] = 'Falta el nombre';
      } else if (precio <= 0) {
        errores[i] = 'Falta el precio';
      } else if (existentes.contains(clave) || !vistos.add(clave)) {
        errores[i] = 'Ya está en la lista';
      } else {
        nuevos.add((nombre, precio));
      }
    }
    setState(() => _errores
      ..clear()
      ..addAll(errores));
    if (errores.isNotEmpty) return;
    _guardando = true;
    for (final (nombre, precio) in nuevos) {
      await repo.crearProducto(nombre: nombre, precio: precio);
    }
    await _seguir();
  }

  Future<void> _seguir() async {
    await ref.read(recorridoProvider.notifier).irA(PasoRecorrido.venta);
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const IndicadorPasos(paso: 2),
            const SizedBox(height: 24),
            Text('Tus primeros productos', style: estiloTitulo()),
            const SizedBox(height: 4),
            Text(
              'Escribe lo que más vendes. El costo, el proveedor y las '
              'existencias los completas después en Productos.',
              style: TextStyle(color: c.textoSecundario),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _filas.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            key: Key('fila_nombre_$i'),
                            controller: _filas[i].$1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration:
                                const InputDecoration(labelText: 'Producto'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: Key('fila_precio_$i'),
                            controller: _filas[i].$2,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                                labelText: 'Precio', prefixText: r'$ '),
                          ),
                        ),
                      ],
                    ),
                    if (_errores[i] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _errores[i]!,
                          key: Key('error_fila_$i'),
                          style: TextStyle(color: c.sale, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            if (_filas.length < _maximoFilas)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('boton_agregar_fila'),
                  onPressed: _agregarFila,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar otro'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonPrincipal(
                key: const Key('boton_guardar_productos'),
                texto: 'Guardar y continuar',
                onPressed: _guardar,
              ),
              TextButton(
                key: const Key('boton_omitir_productos'),
                onPressed: _seguir,
                child: const Text('Omitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
