/// Cliente de una venta fiada. [id] null = cliente nuevo por crear al cobrar.
class ClienteTicket {
  const ClienteTicket({
    this.id,
    required this.nombre,
    this.apellido = '',
    this.telefono,
  });

  final int? id;
  final String nombre;
  final String apellido;
  final String? telefono;

  String get nombreCompleto => '$nombre $apellido'.trim();
}
