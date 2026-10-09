import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import 'detalle_cliente_screen.dart';

class ListaFiadoScreen extends ConsumerWidget {
  const ListaFiadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesConDeudaProvider);
    final alDia =
        ref.watch(clientesAlDiaProvider).valueOrNull ?? const <ClienteConSaldo>[];

    void abrir(ClienteConSaldo item) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalleClienteScreen(clienteConSaldo: item),
          ),
        );

    return Scaffold(
      body: clientesAsync.when(
        data: (clientes) {
          final total = clientes.fold<int>(0, (suma, c) => suma + c.saldo);
          final hoy = DateTime.now();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (clientes.isEmpty)
                const EstadoVacio(
                  icono: Icons.volunteer_activism_rounded,
                  titulo: 'Nadie te debe',
                  mensaje: 'Las ventas fiadas aparecerán aquí',
                )
              else ...[
                TarjetaMonto(
                  key: const Key('tarjeta_te_deben'),
                  etiqueta: 'Te deben',
                  valor: total,
                  tono: TonoMonto.fiado,
                  fondo: ColoresApp.of(context).fiadoSuave,
                  tamano: 28,
                  detalle: plural(clientes.length, 'cliente', 'clientes'),
                ),
                const SizedBox(height: 12),
                for (final item in clientes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        key: Key('cliente_deuda_${item.cliente.id}'),
                        leading: AvatarInicial(
                            id: item.cliente.id, nombre: item.cliente.nombre),
                        title: Text(item.cliente.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            textoDebeDesde(item.fechaDeudaMasAntigua!, hoy)),
                        trailing: Monto(item.saldo,
                            tamano: 16, tono: TonoMonto.fiado),
                        onTap: () => abrir(item),
                      ),
                    ),
                  ),
              ],
              // Quienes ya no deben siguen aquí para poder corregir sus
              // ventas fiadas y abonos.
              if (alDia.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    'AL DÍA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.of(context).textoSecundario,
                    ),
                  ),
                ),
                for (final item in alDia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        key: Key('cliente_al_dia_${item.cliente.id}'),
                        leading: AvatarInicial(
                            id: item.cliente.id, nombre: item.cliente.nombre),
                        title: Text(item.cliente.nombre),
                        subtitle: Text(item.saldo == 0
                            ? 'Al día'
                            : 'Saldo a favor ${formatoMoneda(-item.saldo)}'),
                        onTap: () => abrir(item),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
