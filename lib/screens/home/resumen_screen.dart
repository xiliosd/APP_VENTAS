import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/resumen_repository.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/tipografia.dart';
import '../../ui/monto.dart';
import '../../ui/recorrido/objetivo_recorrido.dart';
import '../../ui/tarjeta_monto.dart';
import '../../ui/tema_app.dart';
import '../../util/fecha_util.dart';
import '../../util/comparacion_ventas.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_fecha.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../reportes/reportes_screen.dart';
import '../venta/registrar_venta_screen.dart';
import 'mini_grafica_semana.dart';

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
    final semana = ref.watch(ventasDiariasProvider(_dia)).valueOrNull;
    final esAdmin = ref.watch(sesionProvider).esAdmin;
    void abrirReportes() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportesScreen()),
        );

    return Column(
      children: [
        Expanded(
          child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SelectorFecha(
          dia: _dia,
          onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
        ),
        const SizedBox(height: 8),
        // Al recargar por un dato nuevo se mantienen las tarjetas (sin
        // rueda): así el monto cuenta y la entrada no se repite.
        resumenAsync.when(
          skipLoadingOnReload: true,
          data: (resumen) => _Tarjetas(
            resumen: resumen,
            dia: _dia,
            esHoy: _dia == inicioDelDia(DateTime.now()),
            semana: semana,
            onVerFiado: widget.onVerFiado,
            onVerReportes: esAdmin ? abrirReportes : null,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Text('Error: $e'),
        ),
        const SizedBox(height: 24),
        Card(
          key: const Key('tarjeta_por_vendedor'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Por vendedor',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (esAdmin)
                      TextButton(
                        key: const Key('boton_ver_reportes'),
                        onPressed: abrirReportes,
                        child: const Text('Ver reportes ›'),
                      ),
                  ],
                ),
                porVendedorAsync.when(
                  skipLoadingOnReload: true,
                  data: (mapa) => Column(
                    children: [
                      for (final entrada in mapa.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
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
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
        ),
        const _BarraAcciones(),
      ],
    );
  }
}

/// "+ Venta" y "− Gasto" fijos abajo del Inicio, siempre a mano del pulgar.
class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones();

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return DecoratedBox(
      key: const Key('barra_acciones_inicio'),
      decoration: BoxDecoration(
        color: c.fondo,
        boxShadow: [
          BoxShadow(
            color: c.texto.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ObjetivoRecorrido(
                  id: 'boton_nueva_venta',
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
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
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
        ),
      ),
    );
  }
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas({
    required this.resumen,
    required this.dia,
    required this.esHoy,
    this.semana,
    this.onVerFiado,
    this.onVerReportes,
  });

  final ResumenDia resumen;
  final DateTime dia;
  final bool esHoy;

  /// Totales de los 7 días que terminan en [dia] (null mientras carga).
  final List<int>? semana;
  final VoidCallback? onVerFiado;
  final VoidCallback? onVerReportes;

  @override
  Widget build(BuildContext context) {
    final ganancia = resumen.totalVendido - resumen.totalGastado;
    final suave =
        ColoresApp.of(context).sobreTarjetaPrincipal.withValues(alpha: 0.75);
    final comparacion = semana == null
        ? null
        : comparacionVentas(semana!.last, semana![semana!.length - 2],
            esHoy: esHoy);
    return Column(
      children: [
        EntradaEscalonada(
          indice: 0,
          child: ObjetivoRecorrido(
            id: 'tarjeta_ventas',
            child: Container(
            key: const Key('tarjeta_ventas'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColoresApp.of(context).tarjetaPrincipal,
              borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(esHoy ? 'Ventas de hoy' : 'Ventas del ${fechaCorta(dia)}',
                    style: estiloTitulo(tamano: 14, color: suave)),
                const SizedBox(height: 4),
                Monto(resumen.totalVendido,
                    tamano: 36, tono: TonoMonto.claro, animado: true),
                if (comparacion != null) ...[
                  const SizedBox(height: 6),
                  _EtiquetaComparacion(comparacion),
                ],
                const SizedBox(height: 4),
                Text(
                  '${plural(resumen.cantidadVentas, 'venta', 'ventas')} · '
                  '${plural(resumen.cantidadFiadas, 'fiada', 'fiadas')}',
                  style: TextStyle(color: suave, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recibido: efectivo ${formatoMoneda(resumen.recibidoEfectivo)}'
                  ' · transferencias '
                  '${formatoMoneda(resumen.recibidoTransferencia)}',
                  key: const Key('texto_recibido'),
                  style: TextStyle(color: suave, fontSize: 12),
                ),
                if (semana != null) ...[
                  const SizedBox(height: 12),
                  MiniGraficaSemana(
                    key: const Key('mini_grafica'),
                    valores: semana!,
                    hasta: dia,
                    onTap: onVerReportes,
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
        const SizedBox(height: 12),
        EntradaEscalonada(
          indice: 1,
          child: Row(
            children: [
              Expanded(
                child: TarjetaMonto(
                  key: const Key('tarjeta_gastos'),
                  etiqueta: 'Gastos',
                  valor: resumen.totalGastado,
                  tono: TonoMonto.sale,
                  colorBorde: ColoresApp.of(context).saleSuave,
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
                      ganancia >= 0 ? ColoresApp.of(context).entraSuave : ColoresApp.of(context).saleSuave,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EntradaEscalonada(
          indice: 2,
          child: TarjetaMonto(
            key: const Key('tarjeta_por_cobrar'),
            etiqueta: 'Por cobrar',
            valor: resumen.totalPorCobrar,
            tono: TonoMonto.fiado,
            fondo: ColoresApp.of(context).fiadoSuave,
            detalle: plural(resumen.clientesConDeuda, 'cliente', 'clientes'),
            onTap: onVerFiado,
          ),
        ),
      ],
    );
  }
}

/// "▲ 12 % vs. ayer" (píldora verde o roja) o "Igual que ayer" (texto).
class _EtiquetaComparacion extends StatelessWidget {
  const _EtiquetaComparacion(this.comparacion);

  final ComparacionVentas comparacion;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final pildora = switch (comparacion.tendencia) {
      TendenciaVentas.sube => c.entra,
      TendenciaVentas.baja => c.sale,
      _ => null,
    };
    return Container(
      key: const Key('comparacion_ventas'),
      padding: pildora == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: pildora == null
          ? null
          : ShapeDecoration(
              shape: const StadiumBorder(),
              color: pildora.withValues(alpha: 0.22),
            ),
      child: Text(
        comparacion.texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: pildora == null
              ? c.sobreTarjetaPrincipal.withValues(alpha: 0.75)
              : c.sobreTarjetaPrincipal,
        ),
      ),
    );
  }
}
