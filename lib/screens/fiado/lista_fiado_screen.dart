import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../repositories/fiado_repository.dart';
import '../../ui/error_carga.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/tema_app.dart';
import '../../ui/tipografia.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/nombre_cliente.dart';
import '../../util/texto_util.dart';
import '../clientes/clientes_screen.dart';
import 'detalle_cliente_screen.dart';

class ListaFiadoScreen extends ConsumerStatefulWidget {
  const ListaFiadoScreen({super.key});

  @override
  ConsumerState<ListaFiadoScreen> createState() => _ListaFiadoScreenState();
}

class _ListaFiadoScreenState extends ConsumerState<ListaFiadoScreen> {
  /// Con más de estos clientes aparece el buscador.
  static const _clientesSinBuscador = 5;

  final _busqueda = TextEditingController();
  String _filtro = '';
  bool _porAntiguedad = false;
  bool _verAlDia = false;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Clientes que pasan el filtro, en el orden elegido.
  List<ClienteConSaldo> _ordenar(List<ClienteConSaldo> clientes) {
    // Sin buscador a la vista (5 clientes o menos) no se filtra: si no, una
    // búsqueda vieja dejaría la lista vacía sin forma de borrarla.
    final filtro = clientes.length > _clientesSinBuscador ? _filtro : '';
    final lista = [
      for (final c in clientes)
        if (filtro.isEmpty || claveCliente(c.cliente.nombreCompleto).contains(filtro)) c,
    ];
    lista.sort(_porAntiguedad ? _masAntigua : _mayorDeuda);
    return lista;
  }

  static int _mayorDeuda(ClienteConSaldo a, ClienteConSaldo b) {
    final porSaldo = b.saldo.compareTo(a.saldo);
    return porSaldo != 0
        ? porSaldo
        : a.cliente.nombreCompleto
            .toLowerCase()
            .compareTo(b.cliente.nombreCompleto.toLowerCase());
  }

  static int _masAntigua(ClienteConSaldo a, ClienteConSaldo b) {
    final porFecha =
        a.fechaDeudaMasAntigua!.compareTo(b.fechaDeudaMasAntigua!);
    return porFecha != 0 ? porFecha : b.saldo.compareTo(a.saldo);
  }

  void _abrir(ClienteConSaldo item) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleClienteScreen(clienteConSaldo: item),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final clientesAsync = ref.watch(clientesConDeudaProvider);
    final alDia =
        ref.watch(clientesAlDiaProvider).valueOrNull ?? const <ClienteConSaldo>[];

    return Scaffold(
      body: clientesAsync.when(
        skipLoadingOnReload: true,
        data: (clientes) {
          final hoy = DateTime.now();
          final visibles = _ordenar(clientes);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  key: const Key('ir_a_clientes'),
                  leading: const Icon(Icons.people_outline_rounded),
                  title: const Text('Todos los clientes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClientesScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (clientes.isEmpty)
                const EstadoVacio(
                  icono: Icons.volunteer_activism_rounded,
                  titulo: 'Nadie te debe',
                  mensaje: 'Las ventas fiadas aparecerán aquí',
                )
              else ...[
                _TarjetaTeDeben(clientes: clientes),
                const SizedBox(height: 12),
                if (clientes.length > _clientesSinBuscador) ...[
                  TextField(
                    key: const Key('buscador_fiado'),
                    controller: _busqueda,
                    decoration: const InputDecoration(
                      hintText: 'Buscar cliente…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (t) =>
                        setState(() => _filtro = sinTildes(t.trim())),
                  ),
                  const SizedBox(height: 12),
                ],
                if (clientes.length >= 2) ...[
                  SelectorSegmentado<bool>(
                    key: const Key('selector_orden_fiado'),
                    opciones: const {false: 'Mayor deuda', true: 'Más antigua'},
                    valor: _porAntiguedad,
                    onCambio: (v) => setState(() => _porAntiguedad = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Sin resultados',
                      key: const Key('texto_sin_resultados_fiado'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textoSecundario),
                    ),
                  ),
                for (final (i, item) in visibles.indexed)
                  EntradaEscalonada(
                    indice: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          key: Key('cliente_deuda_${item.cliente.id}'),
                          leading: AvatarInicial(
                              id: item.cliente.id,
                              nombre: item.cliente.nombreCompleto),
                          title: Text(
                            item.cliente.nombreCompleto,
                            key: const Key('nombre_cliente'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: _EtiquetaAntiguedad(
                            clienteId: item.cliente.id,
                            desde: item.fechaDeudaMasAntigua!,
                            hoy: hoy,
                          ),
                          trailing: Monto(item.saldo,
                              tamano: 16, tono: TonoMonto.fiado),
                          onTap: () => _abrir(item),
                        ),
                      ),
                    ),
                  ),
              ],
              // Quienes ya no deben siguen aquí para poder corregir sus
              // ventas fiadas y abonos.
              if (alDia.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListTile(
                  key: const Key('boton_al_dia'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    'Al día (${alDia.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textoSecundario,
                    ),
                  ),
                  trailing: Icon(_verAlDia
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  onTap: () => setState(() => _verAlDia = !_verAlDia),
                ),
                if (_verAlDia)
                  for (final item in alDia)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          key: Key('cliente_al_dia_${item.cliente.id}'),
                          leading: AvatarInicial(
                              id: item.cliente.id, nombre: item.cliente.nombreCompleto),
                          title: Text(item.cliente.nombreCompleto),
                          subtitle: Text(item.saldo == 0
                              ? 'Al día'
                              : 'Saldo a favor ${formatoMoneda(-item.saldo)}'),
                          onTap: () => _abrir(item),
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorCarga(),
      ),
    );
  }
}

/// "Te deben" con el total, cuántos clientes y quién debe más.
class _TarjetaTeDeben extends StatelessWidget {
  const _TarjetaTeDeben({required this.clientes});

  final List<ClienteConSaldo> clientes;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);
    final total = clientes.fold<int>(0, (suma, x) => suma + x.saldo);
    final mayor = clientes.reduce((a, b) {
      if (a.saldo != b.saldo) return a.saldo >= b.saldo ? a : b;
      return a.cliente.nombreCompleto.toLowerCase().compareTo(
                  b.cliente.nombreCompleto.toLowerCase()) <=
              0
          ? a
          : b;
    });
    return Container(
      key: const Key('tarjeta_te_deben'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.tarjetaPrincipal,
        borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Te deben', style: estiloTitulo(tamano: 14, color: suave)),
          const SizedBox(height: 4),
          Monto(total, tamano: 36, tono: TonoMonto.claro, animado: true),
          const SizedBox(height: 4),
          Text(plural(clientes.length, 'cliente', 'clientes'),
              style: TextStyle(color: suave, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            'Mayor deuda: ${mayor.cliente.nombreCompleto} ${formatoMoneda(mayor.saldo)}',
            key: const Key('texto_mayor_deuda'),
            style: TextStyle(color: suave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// "Debe desde hace N días" con un color según qué tan vieja es la deuda.
class _EtiquetaAntiguedad extends StatelessWidget {
  const _EtiquetaAntiguedad(
      {required this.clienteId, required this.desde, required this.hoy});

  final int clienteId;
  final DateTime desde;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final nivel = nivelAntiguedad(desde, hoy);
    // El texto de "reciente" y "vieja" va en el color de texto: en gris o
    // rojo no llega a 4,5:1 sobre esos fondos. La vieja lleva un reloj rojo.
    final (fondo, texto) = switch (nivel) {
      NivelAntiguedad.reciente => (c.primarioSuave, c.texto),
      NivelAntiguedad.media => (c.fiadoSuave, c.fiado),
      NivelAntiguedad.vieja => (c.sale.withValues(alpha: 0.15), c.texto),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: Key('antiguedad_$clienteId'),
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nivel == NivelAntiguedad.vieja) ...[
              Icon(Icons.schedule_rounded, size: 14, color: c.sale),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                textoDebeDesde(desde, hoy),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: texto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
