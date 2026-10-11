import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/monto.dart';
import '../../ui/teclado_monto.dart';
import '../../util/categorias_gasto.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';

class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key});

  @override
  ConsumerState<RegistrarGastoScreen> createState() =>
      _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends ConsumerState<RegistrarGastoScreen> {
  final _descripcionController = TextEditingController();
  int _monto = 0;
  bool _guardando = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  /// Pone [categoria] al inicio de la descripción; "Otro" o volver a tocar
  /// la elegida la quita.
  void _elegirCategoria(String categoria) {
    final actual = categoriaDe(_descripcionController.text.trim());
    final nueva = (categoria == 'Otro' || actual == categoria) ? null : categoria;
    final texto = aplicarCategoria(_descripcionController.text, nueva);
    setState(() => _descripcionController.value = TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        ));
  }

  Future<void> _registrar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final sesion = ref.read(sesionProvider).usuarioActivo!;
      final descripcion = _descripcionController.text.trim();
      await ref.read(gastoRepositoryProvider).registrarGasto(
            monto: _monto,
            descripcion: descripcion.isEmpty ? null : descripcion,
            usuarioId: sesion.id,
          );
      if (!mounted) return;
      avisar(context, 'Gasto registrado · ${formatoMoneda(_monto)}');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Monto(
              _monto,
              key: const Key('texto_monto_gasto'),
              tamano: 36,
              tono: TonoMonto.sale,
              animado: true,
            ),
          ),
          const SizedBox(height: 16),
          TecladoMonto(
            onTecla: (tecla) =>
                setState(() => _monto = aplicarTecla(_monto, tecla)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final categoria in [...categoriasGasto, 'Otro'])
                ChoiceChip(
                  key: Key('categoria_${sinTildes(categoria)}'),
                  label: Text(categoria),
                  selected: categoria != 'Otro' &&
                      categoriaDe(_descripcionController.text.trim()) ==
                          categoria,
                  onSelected: (_) => _elegirCategoria(categoria),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_descripcion_gasto'),
            controller: _descripcionController,
            // Para que el chip elegido siga lo que se escribe.
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Ej: hielo, bolsas, transporte',
            ),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_registrar_gasto'),
            texto: 'Registrar gasto',
            variante: VarianteBoton.peligro,
            onPressed: _monto > 0 && !_guardando ? _registrar : null,
          ),
        ],
      ),
    );
  }
}
