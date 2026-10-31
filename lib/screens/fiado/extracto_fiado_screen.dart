import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/fiado_providers.dart';
import '../../ui/colores_app.dart';
import '../../ui/error_carga.dart';
import '../../ui/monto.dart';
import '../../ui/tema_app.dart';
import '../../ui/tipografia.dart';
import '../../util/extracto_fiado.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/nombre_cliente.dart';
import '../../widgets/nombre_tienda.dart';

const double _tamanoBase = 18;
const double _tamanoMonto = 20;

/// Extracto de fiado de un cliente, de solo lectura y con letra grande para
/// mostrárselo al cliente: lo reciente a la vista y el resto plegado.
class ExtractoFiadoScreen extends ConsumerWidget {
  const ExtractoFiadoScreen({super.key, required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extractoAsync = ref.watch(extractoClienteProvider(cliente.id));
    final c = ColoresApp.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Extracto')),
      body: DefaultTextStyle.merge(
        style: TextStyle(fontSize: _tamanoBase, color: c.texto),
        child: extractoAsync.when(
          skipLoadingOnReload: true,
          data: (extracto) => _Contenido(cliente: cliente, extracto: extracto),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const ErrorCarga(),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.cliente, required this.extracto});

  final Cliente cliente;
  final ExtractoFiado extracto;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final ultimo = extracto.ultimoAbono;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NombreTienda(
          estilo: estiloTitulo(tamano: 20, color: c.textoSecundario),
          espacioAbajo: 4,
        ),
        Text(cliente.nombreCompleto, style: estiloTitulo(tamano: 28)),
        Text(
          'Extracto al ${formatoFechaHora(DateTime.now())}',
          style: TextStyle(color: c.textoSecundario),
        ),
        const SizedBox(height: 16),
        if (ultimo != null) ...[
          _FilaConsolidado(
            key: const Key('consolidado_ultimo_abono'),
            abono: ultimo,
            destacada: true,
          ),
          if (extracto.anteriores.isNotEmpty)
            Theme(
              // Sin las líneas divisorias por defecto del ExpansionTile.
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('ver_detalle_anterior'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Ver detalle anterior',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.primario,
                  ),
                ),
                children: [
                  for (final entrada in extracto.anteriores)
                    _FilaEntrada(entrada: entrada),
                ],
              ),
            ),
        ],
        for (final entrada in extracto.recientes)
          _FilaEntrada(entrada: entrada),
        const Divider(height: 32),
        _SaldoActual(saldo: extracto.saldoActual),
      ],
    );
  }
}

/// Consolidado: saldo tras el abono; es el resumen que le
/// permite al cliente no repasar todo lo anterior.
class _FilaConsolidado extends StatelessWidget {
  const _FilaConsolidado({
    super.key,
    required this.abono,
    this.destacada = false,
  });

  final AbonoExtracto abono;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final texto = Text(
      'Saldo al ${formatoFechaHora(abono.fecha)} después de abonar '
      '${formatoMoneda(abono.monto)}: ${formatoMoneda(abono.saldoDespues)}',
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    if (!destacada) {
      return Padding(padding: const EdgeInsets.only(top: 4), child: texto);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.borde),
        borderRadius: BorderRadius.circular(radioCampo),
      ),
      child: texto,
    );
  }
}

class _FilaEntrada extends StatelessWidget {
  const _FilaEntrada({required this.entrada});

  final EntradaExtracto entrada;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final entrada = this.entrada;
    final fecha = formatoFechaHora(entrada.fecha);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: switch (entrada) {
        AbonoExtracto() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextoYMonto(
              texto: fecha,
              etiqueta: 'Abono',
              monto: entrada.monto,
              tono: TonoMonto.entra,
            ),
            _FilaConsolidado(abono: entrada),
          ],
        ),
        FiadoExtracto() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fecha, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (entrada.lineas.isEmpty)
              Text(
                'Venta sin detalle',
                style: TextStyle(color: c.textoSecundario),
              )
            else
              for (final l in entrada.lineas)
                Text(
                  '${l.descripcion} · ${l.cantidad} × '
                  '${formatoMoneda(l.precioUnitario)} = '
                  '${formatoMoneda(l.cantidad * l.precioUnitario)}',
                ),
            _TextoYMonto(
              texto: 'Total',
              monto: entrada.monto,
              tono: TonoMonto.fiado,
            ),
          ],
        ),
      },
    );
  }
}

/// Texto a la izquierda y monto grande a la derecha; el monto se encoge antes
/// de desbordar.
class _TextoYMonto extends StatelessWidget {
  const _TextoYMonto({
    required this.texto,
    required this.monto,
    required this.tono,
    this.etiqueta,
  });

  final String texto;
  final String? etiqueta;
  final int monto;
  final TonoMonto tono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (etiqueta != null) ...[Text(etiqueta!), const SizedBox(width: 12)],
        Flexible(
          child: Monto(monto, tamano: _tamanoMonto, tono: tono),
        ),
      ],
    );
  }
}

class _SaldoActual extends StatelessWidget {
  const _SaldoActual({required this.saldo});

  final int saldo;

  @override
  Widget build(BuildContext context) {
    final texto = saldo > 0
        ? 'Saldo actual ${formatoMoneda(saldo)}'
        : saldo == 0
        ? 'Al día'
        : 'Saldo a favor ${formatoMoneda(-saldo)}';
    return Container(
      key: const Key('saldo_actual_extracto'),
      child: Text(texto, style: estiloTitulo(tamano: 28)),
    );
  }
}
