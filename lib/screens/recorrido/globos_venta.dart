import '../../ui/recorrido/globos.dart';

/// Globos de la venta de práctica (todos de acción).
const globosVenta = [
  PasoGlobo(
      objetivos: ['primer_producto', 'monto_rapido_1000'],
      texto: 'Toca un producto para sumarlo al ticket.',
      deAccion: true),
  PasoGlobo(
      objetivos: ['boton_cobrar'],
      texto: 'Aquí ves el total. Toca Cobrar.',
      deAccion: true),
  PasoGlobo(
      objetivos: ['pago_efectivo'],
      texto: 'Elige cómo paga. Toca Efectivo.',
      deAccion: true),
];
