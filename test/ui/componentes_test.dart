import 'package:app_ventas/ui/avatar_inicial.dart';
import 'package:app_ventas/ui/avisos.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/estado_vacio.dart';
import 'package:app_ventas/ui/hoja_inferior.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/ui/selector_segmentado.dart';
import 'package:app_ventas/ui/tarjeta_monto.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) =>
    MaterialApp(theme: temaApp(), home: Scaffold(body: hijo));

void main() {
  testWidgets('Monto muestra el formato y el color de su tono', (tester) async {
    await tester.pumpWidget(_app(const Monto(5000, tono: TonoMonto.sale)));

    final texto = tester.widget<Text>(find.text(r'$5.000'));
    expect(texto.style!.color, ColoresApp.sale);
  });

  testWidgets('Monto grande no desborda en un espacio angosto', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 120,
      child: Monto(123456789, tamano: 32),
    )));

    expect(tester.takeException(), isNull);
    expect(find.text(r'$123.456.789'), findsOneWidget);
  });

  testWidgets('TarjetaMonto muestra etiqueta, monto y responde al toque',
      (tester) async {
    var tocada = false;
    await tester.pumpWidget(_app(TarjetaMonto(
      etiqueta: 'Gastos',
      valor: 1000,
      detalle: '2 gastos',
      onTap: () => tocada = true,
    )));

    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'$1.000'), findsOneWidget);
    expect(find.text('2 gastos'), findsOneWidget);
    await tester.tap(find.text('Gastos'));
    expect(tocada, isTrue);
  });

  testWidgets('BotonPrincipal sin onPressed queda deshabilitado',
      (tester) async {
    await tester.pumpWidget(
        _app(const BotonPrincipal(texto: 'Cobrar', onPressed: null)));

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('BotonPrincipal contorno usa OutlinedButton y llama onPressed',
      (tester) async {
    var llamado = false;
    await tester.pumpWidget(_app(BotonPrincipal(
      texto: '− Gasto',
      variante: VarianteBoton.peligro,
      onPressed: () => llamado = true,
    )));

    await tester.tap(find.byType(OutlinedButton));
    expect(llamado, isTrue);
  });

  testWidgets('SelectorSegmentado avisa la opción elegida', (tester) async {
    bool? elegido;
    await tester.pumpWidget(_app(SelectorSegmentado<bool>(
      opciones: const {false: 'Contado', true: 'Fiado'},
      valor: false,
      onCambio: (v) => elegido = v,
    )));

    await tester.tap(find.text('Fiado'));
    expect(elegido, isTrue);
  });

  testWidgets('EstadoVacio muestra título y mensaje', (tester) async {
    await tester.pumpWidget(_app(const EstadoVacio(
      icono: Icons.inbox_rounded,
      titulo: 'Nadie te debe',
      mensaje: 'Las ventas fiadas aparecerán aquí',
    )));

    expect(find.text('Nadie te debe'), findsOneWidget);
    expect(find.text('Las ventas fiadas aparecerán aquí'), findsOneWidget);
  });

  testWidgets('avisar muestra el texto y Deshacer llama su acción',
      (tester) async {
    var deshecho = false;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => avisar(context, 'Venta registrada',
            onDeshacer: () => deshecho = true),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Venta registrada'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    expect(deshecho, isTrue);
  });

  testWidgets('el aviso con Deshacer se cierra solo a los 5 segundos',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            avisar(context, 'Venta registrada', onDeshacer: () {}),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Venta registrada'), findsNothing);
  });

  testWidgets('mostrarHojaInferior muestra el título y el contenido',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => mostrarHojaInferior<void>(context,
            titulo: 'Nuevo producto', builder: (_) => const Text('form')),
        child: const Text('abrir'),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('AvatarInicial muestra la inicial en mayúscula', (tester) async {
    await tester
        .pumpWidget(_app(const AvatarInicial(id: 3, nombre: ' ana ')));
    expect(find.text('A'), findsOneWidget);
  });

  test('etiquetaRol traduce los roles', () {
    expect(etiquetaRol('admin'), 'Administrador');
    expect(etiquetaRol('vendedor'), 'Vendedor');
  });

  testWidgets('Monto tachado se ve con línea y en gris', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Monto(5000, tachado: true)));
    final texto = tester.widget<Text>(find.text(r'$5.000'));
    expect(texto.style!.decoration, TextDecoration.lineThrough);
    expect(texto.style!.color, ColoresApp.textoSecundario);
  });

  testWidgets('el círculo del estado vacío usa el azul claro de marca',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: EstadoVacio(icono: Icons.inbox_outlined, titulo: 'Nada')),
    ));
    final circulo = tester.widget<Container>(find
        .ancestor(
            of: find.byIcon(Icons.inbox_outlined),
            matching: find.byType(Container))
        .first);
    expect((circulo.decoration! as BoxDecoration).color,
        ColoresApp.primarioSuave);
  });
}
