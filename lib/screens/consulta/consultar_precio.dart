import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../servicios/lector_codigo.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../configuracion/producto_screen.dart';
import '../venta/hoja_producto_rapido.dart';

/// Lo que se pide desde la hoja de consulta.
enum AccionConsulta { otra, listo, agregar, editar }

/// Escanea y muestra el precio del producto, tantas veces como se pida, hasta
/// que se elige "Listo" o se cierra el escáner. Es solo consulta: nunca toca
/// el ticket ni registra nada.
Future<void> consultarPrecio(BuildContext context, WidgetRef ref) async {
  final repositorio = ref.read(productoRepositoryProvider);
  final esAdmin = ref.read(sesionProvider).esAdmin;
  while (true) {
    if (!context.mounted) return;
    final leido = await ref
        .read(lectorCodigoProvider)
        .leer(context, uso: UsoEscaner.consulta);
    if (leido == null || !context.mounted) return;
    final codigo = leido.trim();
    var producto = await repositorio.productoPorCodigo(codigo);
    var otraLectura = false;
    while (!otraLectura) {
      if (!context.mounted) return;
      final accion = await mostrarHojaInferior<AccionConsulta>(
        context,
        titulo: 'Consultar precio',
        builder: (_) => HojaConsultaPrecio(
          codigo: codigo,
          producto: producto,
          esAdmin: esAdmin,
        ),
      );
      if (!context.mounted) return;
      switch (accion) {
        case null || AccionConsulta.listo:
          return;
        case AccionConsulta.otra:
          otraLectura = true;
        case AccionConsulta.agregar:
          final nuevo = await mostrarHojaProductoRapido(
            context,
            codigo: codigo,
            textoGuardar: 'Guardar',
          );
          if (nuevo != null) producto = nuevo;
        case AccionConsulta.editar:
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ProductoScreen(producto: producto),
            ),
          );
          if (!context.mounted) return;
          producto = await repositorio.productoPorCodigo(codigo);
      }
    }
  }
}

/// Resultado de una consulta: el precio, o por qué no hay uno.
class HojaConsultaPrecio extends StatelessWidget {
  const HojaConsultaPrecio({
    super.key,
    required this.codigo,
    required this.producto,
    required this.esAdmin,
  });

  final String codigo;
  final Producto? producto;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final colores = ColoresApp.of(context);
    final actual = producto;
    final detalle = actual == null
        ? null
        : [
            if (actual.marca != null && actual.marca!.isNotEmpty) actual.marca,
            if (actual.tamano != null && actual.tamano!.isNotEmpty)
              actual.tamano,
          ].join(' · ');
    return Column(
      key: const Key('hoja_consulta_precio'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actual == null) ...[
          const Text(
            'Este código aún no está en tus productos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(codigo, style: TextStyle(color: colores.textoSecundario)),
        ] else ...[
          Text(
            actual.nombre,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (detalle != null && detalle.isNotEmpty)
            Text(detalle, style: TextStyle(color: colores.textoSecundario)),
          const SizedBox(height: 8),
          if (actual.activo)
            Semantics(
              label: 'Precio: ${formatoMoneda(actual.precio)}',
              excludeSemantics: true,
              child: Text(
                formatoMoneda(actual.precio),
                key: const Key('texto_precio_consulta'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: colores.texto,
                ),
              ),
            )
          else ...[
            const Text(
              'Este producto está inactivo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'El administrador lo reactiva en Productos.',
              style: TextStyle(color: colores.textoSecundario),
            ),
          ],
        ],
        const SizedBox(height: 16),
        if (actual == null)
          BotonPrincipal(
            key: const Key('boton_agregar_consulta'),
            texto: 'Agregar producto',
            onPressed: () => Navigator.of(context).pop(AccionConsulta.agregar),
          ),
        if (actual == null) const SizedBox(height: 8),
        BotonPrincipal(
          key: const Key('boton_otra_consulta'),
          texto: 'Consultar otro',
          variante: actual == null
              ? VarianteBoton.contorno
              : VarianteBoton.primario,
          onPressed: () => Navigator.of(context).pop(AccionConsulta.otra),
        ),
        if (actual != null && esAdmin)
          TextButton(
            key: const Key('boton_editar_consulta'),
            onPressed: () => Navigator.of(context).pop(AccionConsulta.editar),
            child: const Text('Editar producto'),
          ),
        TextButton(
          key: const Key('boton_listo_consulta'),
          onPressed: () => Navigator.of(context).pop(AccionConsulta.listo),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
