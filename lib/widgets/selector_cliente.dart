import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/clientes_providers.dart';
import '../providers/ticket_provider.dart';

/// Buscador de cliente para ventas fiadas: sugiere clientes existentes y
/// permite uno nuevo con el nombre escrito. Con un cliente [elegido] muestra
/// solo su chip, que se puede quitar.
class SelectorCliente extends ConsumerStatefulWidget {
  const SelectorCliente({
    super.key,
    required this.elegido,
    required this.onElegir,
    this.onEscribir,
    this.exigir = false,
  });

  final ClienteTicket? elegido;
  final ValueChanged<ClienteTicket?> onElegir;
  final ValueChanged<String>? onEscribir;

  /// Con true y nada escrito, muestra "Escribe o elige el cliente".
  final bool exigir;

  @override
  ConsumerState<SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends ConsumerState<SelectorCliente> {
  final _controller = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elegido = widget.elegido;
    if (elegido != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('cliente_elegido'),
          avatar: const Icon(Icons.person_rounded, size: 18),
          label: Text(elegido.nombre),
          onDeleted: () => widget.onElegir(null),
        ),
      );
    }

    final clientes =
        ref.watch(listaClientesProvider).valueOrNull ?? const <Cliente>[];
    final texto = _busqueda.trim();
    final buscado = texto.toLowerCase();
    final sugeridos = clientes
        .where((c) => c.nombre.toLowerCase().contains(buscado))
        .take(6)
        .toList();
    final existeExacto = clientes.any(
      (c) => c.nombre.trim().toLowerCase() == buscado,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('campo_cliente'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: '¿A quién le fías?',
            prefixIcon: const Icon(Icons.search_rounded),
            errorText: widget.exigir && texto.isEmpty
                ? 'Escribe o elige el cliente'
                : null,
          ),
          onChanged: (valor) {
            setState(() => _busqueda = valor);
            widget.onEscribir?.call(valor);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in sugeridos)
              ActionChip(
                key: Key('cliente_sugerido_${c.id}'),
                label: Text(c.nombre),
                onPressed: () =>
                    widget.onElegir(ClienteTicket(id: c.id, nombre: c.nombre)),
              ),
            if (texto.isNotEmpty && !existeExacto)
              ActionChip(
                key: const Key('boton_cliente_nuevo'),
                avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text('Nuevo: $texto'),
                onPressed: () => widget.onElegir(ClienteTicket(nombre: texto)),
              ),
          ],
        ),
      ],
    );
  }
}
