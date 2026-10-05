import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late ProviderSubscription<Ticket> suscripcion;

  const arepa = Producto(id: 1, nombre: 'Arepa', precio: 3500, activo: true);
  const pan = Producto(id: 2, nombre: 'Pan', precio: 500, activo: true);

  TicketNotifier notifier() => container.read(ticketProvider.notifier);
  Ticket ticket() => container.read(ticketProvider);

  setUp(() {
    container = ProviderContainer();
    suscripcion = container.listen(ticketProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('empieza vacío y no se puede cobrar', () {
    expect(ticket().estaVacio, isTrue);
    expect(ticket().total, 0);
    expect(ticket().puedeCobrar, isFalse);
  });

  test('agregar el mismo producto suma su cantidad', () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(arepa);
    notifier().agregarMonto(1000);

    expect(ticket().lineas, hasLength(2));
    expect(ticket().cantidadDe('p1'), 2);
    expect(ticket().cantidadArticulos, 3);
    expect(ticket().total, 8000);
  });

  test('restar a cero y quitar sacan la línea; vaciar deja el ticket vacío',
      () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(pan);
    notifier().agregarMonto(2000);

    notifier().restar('p1');
    expect(ticket().cantidadDe('p1'), 0);
    notifier().quitar('m2000');
    expect(ticket().total, 500);
    notifier().sumar('p2');
    expect(ticket().total, 1000);
    notifier().vaciar();
    expect(ticket().estaVacio, isTrue);
  });

  test('agregarMonto ignora montos no positivos', () {
    notifier().agregarMonto(0);
    expect(ticket().estaVacio, isTrue);
  });

  test('productoIdUnico solo con una única línea de producto', () {
    notifier().agregarProducto(arepa);
    notifier().agregarProducto(arepa);
    expect(ticket().productoIdUnico, 1);

    notifier().agregarProducto(pan);
    expect(ticket().productoIdUnico, isNull);

    notifier().vaciar();
    notifier().agregarMonto(5000);
    expect(ticket().productoIdUnico, isNull);
  });

  test('fiado sin cliente no se puede cobrar; con cliente sí', () {
    notifier().agregarMonto(2000);
    notifier().cambiarFiado(true);
    expect(ticket().puedeCobrar, isFalse);

    notifier().elegirCliente(const ClienteTicket(nombre: 'Don Pedro'));
    expect(ticket().puedeCobrar, isTrue);

    notifier().cambiarFiado(false);
    expect(ticket().cliente, isNull);
    expect(ticket().puedeCobrar, isTrue);
  });

  test('al dejar de usarse, el ticket se descarta', () async {
    notifier().agregarMonto(5000);

    suscripcion.close();
    await container.pump();

    expect(container.read(ticketProvider).estaVacio, isTrue);
  });

  test('un nombre escrito cuenta como cliente al fiar', () {
    notifier().agregarMonto(1000);
    notifier().cambiarFiado(true);
    notifier().escribirCliente('  Pedro ');

    expect(ticket().puedeCobrar, isTrue);
    expect(ticket().clienteParaCobrar!.nombre, 'Pedro');
    expect(ticket().clienteParaCobrar!.id, isNull);

    notifier().escribirCliente('   ');
    expect(ticket().puedeCobrar, isFalse);
  });
}
