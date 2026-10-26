import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/clientes_providers.dart';
import '../providers/ticket_provider.dart';
import '../util/nombre_cliente.dart';
import 'formulario_cliente.dart';

/// Buscador de cliente: sugiere clientes existentes (por nombre, apellido o
/// teléfono) y abre el formulario para uno nuevo. Con un cliente [elegido]
/// muestra solo su chip, que se puede quitar.
class SelectorCliente extends ConsumerStatefulWidget {
  const SelectorCliente({
    super.key,
    required this.elegido,
    required this.onElegir,
    this.etiqueta = '¿A quién le fías?',
    this.exigir = false,
  });

  final ClienteTicket? elegido;
  final ValueChanged<ClienteTicket?> onElegir;
  final String etiqueta;

  /// Con true y sin cliente elegido, muestra "Escribe o elige el cliente".
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

  bool _coincide(Cliente cliente, String buscado, String? digitos) {
    if (claveCliente(cliente.nombreCompleto).contains(buscado)) return true;
    final telefono = telefonoNormalizado(cliente.telefono);
    return digitos != null && telefono != null && telefono.contains(digitos);
  }

  Future<void> _crearNuevo(String texto) async {
    final cliente = await pedirClienteNuevo(context, textoInicial: texto);
    if (cliente != null) widget.onElegir(cliente);
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
          label: Text(elegido.nombreCompleto),
          onDeleted: () => widget.onElegir(null),
        ),
      );
    }

    final clientes =
        ref.watch(listaClientesProvider).valueOrNull ?? const <Cliente>[];
    final texto = _busqueda.trim();
    final buscado = claveCliente(texto);
    final digitos = telefonoNormalizado(texto);
    final sugeridos = clientes
        .where((c) => _coincide(c, buscado, digitos))
        .take(6)
        .toList();
    final existeExacto = clientes.any(
      (c) => claveCliente(c.nombreCompleto) == buscado,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('campo_cliente'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            prefixIcon: const Icon(Icons.search_rounded),
            errorText: widget.exigir && texto.isEmpty
                ? 'Escribe o elige el cliente'
                : null,
          ),
          onChanged: (valor) => setState(() => _busqueda = valor),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in sugeridos)
              ActionChip(
                key: Key('cliente_sugerido_${c.id}'),
                label: Text(c.nombreCompleto),
                onPressed: () => widget.onElegir(
                  ClienteTicket(
                    id: c.id,
                    nombre: c.nombre,
                    apellido: c.apellido ?? '',
                    telefono: c.telefono,
                  ),
                ),
              ),
            if (texto.isNotEmpty)
              ActionChip(
                key: const Key('boton_cliente_nuevo'),
                avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text(existeExacto ? 'Nuevo cliente' : 'Nuevo: $texto'),
                onPressed: () => _crearNuevo(texto),
              ),
          ],
        ),
      ],
    );
  }
}
