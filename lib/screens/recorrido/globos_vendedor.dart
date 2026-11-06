import '../../ui/recorrido/globos.dart';

/// Recorrido corto del vendedor la primera vez que entra en su celular.
const globosVendedor = [
  PasoGlobo(
    objetivos: ['tarjeta_ventas'],
    texto: 'Aquí ves cuánto se vendió hoy en la tienda.',
  ),
  PasoGlobo(
    objetivos: ['boton_nueva_venta'],
    texto: 'Registra cada venta aquí. Llega sola al celular del administrador.',
  ),
  PasoGlobo(
    objetivos: ['boton_consultar_precio'],
    texto:
        '¿Te preguntan cuánto vale algo? Escanéalo aquí y ves el precio sin '
        'vender.',
  ),
  PasoGlobo(
    objetivos: ['pestana_fiado'],
    texto: 'Aquí está lo que deben los clientes.',
  ),
  PasoGlobo(
    objetivos: ['menu_cuenta'],
    texto:
        'Tu cuenta: entrar con huella, apariencia, preguntas y cerrar sesión.',
  ),
];
