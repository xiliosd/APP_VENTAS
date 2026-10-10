import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ticket_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/recorrido/objetivo_recorrido.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_cliente.dart';

enum FormaPago { efectivo, transferencia, fiado }

/// Pregunta cómo paga el cliente. Con Fiado, el cliente se elige dentro de la
/// hoja (queda en el ticket). Null si se cierra sin elegir.
Future<FormaPago?> mostrarHojaComoPaga(BuildContext context) {
  final ticket = ProviderScope.containerOf(context).read(ticketProvider);
  return mostrarHojaInferior<FormaPago>(
    context,
    titulo: 'Cobrar ${formatoMoneda(ticket.total)}',
    builder: (_) => const _ComoPaga(),
  );
}

class _ComoPaga extends ConsumerStatefulWidget {
  const _ComoPaga();
  @override
  ConsumerState<_ComoPaga> createState() => _ComoPagaState();
}

class _ComoPagaState extends ConsumerState<_ComoPaga> {
  var _fiado = false;
  var _elegido = false; // evita doble toque

  void _elegir(FormaPago forma) {
    if (_elegido) return;
    _elegido = true;
    Navigator.of(context).pop(forma);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final ticket = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final cliente = ticket.clienteParaCobrar;
    return Column(
      key: const Key('hoja_como_paga'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${plural(ticket.cantidadArticulos, 'artículo', 'artículos')} · ¿Cómo paga?',
          style: TextStyle(color: c.textoSecundario),
        ),
        const SizedBox(height: 12),
        // Con Fiado escogido quedan solo el cliente y Fiar, para que con el
        // teclado abierto quepan en celulares pequeños.
        if (!_fiado) ...[
        ObjetivoRecorrido(
          id: 'pago_efectivo',
          child: _Opcion(
            key: const Key('pago_efectivo'),
            icono: Icons.payments_rounded,
            texto: 'Efectivo',
            color: c.entra,
            onTap: () => _elegir(FormaPago.efectivo),
          ),
        ),
        _Opcion(
          key: const Key('pago_transferencia'),
          icono: Icons.qr_code_2_rounded,
          texto: 'Transferencia (mostrar QR)',
          color: c.primario,
          onTap: () => _elegir(FormaPago.transferencia),
        ),
        ],
        _Opcion(
          key: const Key('pago_fiado'),
          icono: Icons.edit_note_rounded,
          texto: 'Fiado',
          color: c.fiado,
          seleccionada: _fiado,
          onTap: () {
            notifier.cambiarFiado(true);
            setState(() => _fiado = true);
          },
        ),
        if (_fiado) ...[
          const SizedBox(height: 8),
          SelectorCliente(
            elegido: ticket.cliente,
            onElegir: notifier.elegirCliente,
            onEscribir: notifier.escribirCliente,
            exigir: true,
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_fiar'),
            texto: cliente == null
                ? 'Fiar ${formatoMoneda(ticket.total)}'
                : 'Fiar ${formatoMoneda(ticket.total)} a ${cliente.nombre}',
            variante: VarianteBoton.entra,
            onPressed: cliente == null ? null : () => _elegir(FormaPago.fiado),
          ),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({super.key, required this.icono, required this.texto,
      required this.color, required this.onTap, this.seleccionada = false});
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: seleccionada ? color : c.borde, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(texto,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}
