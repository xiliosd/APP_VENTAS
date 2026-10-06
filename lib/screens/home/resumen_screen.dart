import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../repositories/resumen_repository.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/tipografia.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_fecha.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../venta/registrar_venta_screen.dart';

class ResumenScreen extends ConsumerStatefulWidget {
  const ResumenScreen({super.key, this.onVerFiado});

  /// Se llama al tocar "Por cobrar" (la estructura principal abre Fiado).
  final VoidCallback? onVerFiado;

  @override
  ConsumerState<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends ConsumerState<ResumenScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenDelDiaProvider(_dia));
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider(_dia));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SelectorFecha(
          dia: _dia,
          onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
        ),
        const SizedBox(height: 8),
        resumenAsync.when(
          data: (resumen) =>
              _Tarjetas(resumen: resumen, onVerFiado: widget.onVerFiado),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Text('Error: $e'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BotonPrincipal(
                key: const Key('boton_nueva_venta'),
                texto: '+ Venta',
                variante: VarianteBoton.entra,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RegistrarVentaScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BotonPrincipal(
                key: const Key('boton_nuevo_gasto'),
                texto: '− Gasto',
                variante: VarianteBoton.peligro,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RegistrarGastoScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Por vendedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        porVendedorAsync.when(
          data: (mapa) => Card(
            child: Column(
              children: [
                for (final entrada in mapa.entries)
                  ListTile(
                    leading: AvatarInicial(
                        id: entrada.key.id,
                        nombre: entrada.key.nombre,
                        radio: 16),
                    title: Text(entrada.key.nombre),
                    trailing:
                        Monto(entrada.value.totalVendido, tamano: 16),
                  ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, st) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas({required this.resumen, this.onVerFiado});

  final ResumenDia resumen;
  final VoidCallback? onVerFiado;

  @override
  Widget build(BuildContext context) {
    final ganancia = resumen.totalVendido - resumen.totalGastado;
    return Column(
      children: [
        Container(
          key: const Key('tarjeta_ventas'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColoresApp.primario,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ventas del día',
                  style: estiloTitulo(tamano: 14, color: Colors.white70)),
              const SizedBox(height: 4),
              Monto(resumen.totalVendido, tamano: 32, tono: TonoMonto.claro),
              const SizedBox(height: 4),
              Text(
                '${plural(resumen.cantidadVentas, 'venta', 'ventas')} · '
                '${plural(resumen.cantidadFiadas, 'fiada', 'fiadas')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('tarjeta_gastos'),
                etiqueta: 'Gastos',
                valor: resumen.totalGastado,
                tono: TonoMonto.sale,
                colorBorde: ColoresApp.saleSuave,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TarjetaMonto(
                key: const Key('tarjeta_ganancia'),
                etiqueta: 'Ganancia',
                valor: ganancia,
                tono: ganancia >= 0 ? TonoMonto.entra : TonoMonto.sale,
                colorBorde:
                    ganancia >= 0 ? ColoresApp.entraSuave : ColoresApp.saleSuave,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TarjetaMonto(
          key: const Key('tarjeta_por_cobrar'),
          etiqueta: 'Por cobrar',
          valor: resumen.totalPorCobrar,
          tono: TonoMonto.fiado,
          fondo: ColoresApp.fiadoSuave,
          detalle: plural(resumen.clientesConDeuda, 'cliente', 'clientes'),
          onTap: onVerFiado,
        ),
      ],
    );
  }
}
