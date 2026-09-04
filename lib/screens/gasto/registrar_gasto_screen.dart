import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';

class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key});

  @override
  ConsumerState<RegistrarGastoScreen> createState() =>
      _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends ConsumerState<RegistrarGastoScreen> {
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  Future<void> _registrar() async {
    final monto = int.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) return;
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await ref.read(gastoRepositoryProvider).registrarGasto(
          monto: monto,
          descripcion: _descripcionController.text.trim().isEmpty
              ? null
              : _descripcionController.text.trim(),
          usuarioId: sesion.id,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('campo_monto_gasto'),
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              key: const Key('campo_descripcion_gasto'),
              controller: _descripcionController,
              decoration:
                  const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('boton_registrar_gasto'),
              onPressed: _registrar,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
