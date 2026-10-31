import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/clientes_providers.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/error_carga.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/pildora.dart';
import '../../util/nombre_cliente.dart';
import '../../widgets/formulario_cliente.dart';
import 'detalle_cliente_general_screen.dart';

/// Todos los clientes de la tienda, con o sin fiado, para cualquier usuario.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  String _filtro = '';

  void _abrirDetalle(int clienteId) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DetalleClienteGeneralScreen(clienteId: clienteId),
    ),
  );

  Future<void> _agregar() async {
    final id = await crearClienteDesdeFormulario(context);
    if (id != null && mounted) _abrirDetalle(id);
  }

  bool _coincide(Cliente cliente) {
    if (_filtro.isEmpty) return true;
    if (claveCliente(cliente.nombreCompleto).contains(claveCliente(_filtro))) {
      return true;
    }
    final telefonoBuscado = telefonoNormalizado(_filtro);
    final telefono = telefonoNormalizado(cliente.telefono);
    return telefonoBuscado != null &&
        telefono != null &&
        telefono.contains(telefonoBuscado);
  }

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    final clientesAsync = ref.watch(listaClientesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_cliente'),
        onPressed: _agregar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: clientesAsync.when(
        skipLoadingOnReload: true,
        data: (clientes) {
          if (clientes.isEmpty) {
            return const EstadoVacio(
              icono: Icons.people_outline_rounded,
              titulo: 'Aún no tienes clientes',
              mensaje: 'Agrega a quien te compra para ver sus compras',
            );
          }
          final visibles =
              [
                for (final c in clientes)
                  if (_coincide(c)) c,
              ]..sort(
                (a, b) =>
                    claveCliente(a.nombreCompleto)
                        .compareTo(claveCliente(b.nombreCompleto)),
              );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                key: const Key('buscador_clientes'),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o teléfono…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (texto) => setState(() => _filtro = texto.trim()),
              ),
              const SizedBox(height: 12),
              if (visibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Sin resultados',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colores.textoSecundario),
                  ),
                ),
              for (final (i, cliente) in visibles.indexed)
                EntradaEscalonada(
                  indice: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        key: Key('cliente_item_${cliente.id}'),
                        leading: AvatarInicial(
                          id: cliente.id,
                          nombre: cliente.nombreCompleto,
                        ),
                        title: Text(
                          cliente.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: _Detalle(cliente: cliente),
                        onTap: () => _abrirDetalle(cliente.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const ErrorCarga(),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    final faltaApellido = (cliente.apellido?.trim() ?? '').isEmpty;
    final telefono = cliente.telefono;
    if (!faltaApellido && telefono == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (telefono != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: colores.textoSecundario,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(telefono, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          if (faltaApellido)
            Pildora(
              key: Key('falta_apellido_${cliente.id}'),
              texto: 'Falta apellido',
              color: colores.fiado,
            ),
        ],
      ),
    );
  }
}
