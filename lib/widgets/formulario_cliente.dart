import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/fiado_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/ticket_provider.dart';
import '../respaldo/telefono.dart';
import '../ui/boton_principal.dart';
import '../ui/hoja_inferior.dart';
import '../util/formato_moneda.dart';
import '../util/nombre_cliente.dart';

/// Pide los datos de un cliente nuevo. No guarda nada: devuelve un
/// [ClienteTicket] con `id` null (por crear) o el de un cliente parecido que
/// el vendedor eligió. Null si cierra la hoja.
Future<ClienteTicket?> pedirClienteNuevo(
  BuildContext context, {
  String textoInicial = '',
}) {
  return mostrarHojaInferior<ClienteTicket>(
    context,
    titulo: 'Nuevo cliente',
    builder: (_) => _FormularioCliente(textoInicial: textoInicial),
  );
}

/// Edita a [cliente]; true si guardó los cambios.
Future<bool> editarCliente(BuildContext context, Cliente cliente) async {
  final guardado = await mostrarHojaInferior<bool>(
    context,
    titulo: 'Editar cliente',
    builder: (_) => _FormularioCliente(cliente: cliente),
  );
  return guardado ?? false;
}

/// Para la pantalla Clientes: devuelve el id del cliente creado o del
/// existente que se eligió; null si se cerró el formulario.
Future<int?> crearClienteDesdeFormulario(BuildContext context) async {
  final contenedor = ProviderScope.containerOf(context);
  final elegido = await pedirClienteNuevo(context);
  if (elegido == null) return null;
  if (elegido.id != null) return elegido.id;
  return contenedor
      .read(clienteRepositoryProvider)
      .crearCliente(
        nombre: elegido.nombre,
        apellido: elegido.apellido,
        telefono: elegido.telefono,
      );
}

class _FormularioCliente extends ConsumerStatefulWidget {
  const _FormularioCliente({this.cliente, this.textoInicial = ''});

  final Cliente? cliente;
  final String textoInicial;

  @override
  ConsumerState<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends ConsumerState<_FormularioCliente> {
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _telefono;
  late final TextEditingController _notas;
  String? _errorNombre;
  String? _errorApellido;
  String? _errorTelefono;
  bool _ocupado = false;

  bool get _editando => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    var nombre = cliente?.nombre ?? '';
    var apellido = cliente?.apellido ?? '';
    if (cliente == null) {
      // La primera palabra es el nombre y lo demás el apellido.
      final partes = widget.textoInicial.trim().split(RegExp(r'\s+'));
      nombre = partes.first;
      apellido = partes.skip(1).join(' ');
    }
    _nombre = TextEditingController(text: nombre);
    _apellido = TextEditingController(text: apellido);
    _telefono = TextEditingController(text: cliente?.telefono);
    _notas = TextEditingController(text: cliente?.notas);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  bool _validar() {
    final telefono = telefonoNormalizado(_telefono.text);
    final hayTelefono = _telefono.text.trim().isNotEmpty;
    final telefonoValido =
        !hayTelefono || (telefono != null && telefonoE164(telefono) != null);
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Escribe el nombre' : null;
      _errorApellido = _apellido.text.trim().isEmpty
          ? 'Escribe el apellido'
          : null;
      _errorTelefono = telefonoValido
          ? null
          : 'Escribe un celular de 10 dígitos';
    });
    return _errorNombre == null && _errorApellido == null && telefonoValido;
  }

  Future<void> _continuar() async {
    if (_ocupado || !_validar()) return;
    setState(() => _ocupado = true);
    try {
      final repositorio = ref.read(clienteRepositoryProvider);
      final nombre = _nombre.text.trim();
      final apellido = _apellido.text.trim();
      final telefono = telefonoNormalizado(_telefono.text);
      final parecidos = await repositorio.clientesParecidos(
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
        salvo: widget.cliente?.id,
      );
      Cliente? elegido;
      if (parecidos.isNotEmpty) {
        if (!mounted) return;
        final decision = await _mostrarParecidos(parecidos);
        if (decision == null) return; // Volvió al formulario.
        elegido = decision.usar;
      }
      if (!mounted) return;
      if (elegido != null) {
        Navigator.of(context).pop(
          ClienteTicket(
            id: elegido.id,
            nombre: elegido.nombre,
            apellido: elegido.apellido ?? '',
            telefono: elegido.telefono,
          ),
        );
      } else if (_editando) {
        await repositorio.actualizarCliente(
          widget.cliente!.id,
          nombre: nombre,
          apellido: apellido,
          telefono: telefono,
          notas: _notas.text,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop(
          ClienteTicket(nombre: nombre, apellido: apellido, telefono: telefono),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorNombre = '${e.message}');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<_Decision?> _mostrarParecidos(List<Cliente> parecidos) {
    return mostrarHojaInferior<_Decision>(
      context,
      titulo: 'Ya existe un cliente parecido',
      builder: (_) => _HojaParecidos(parecidos: parecidos, editando: _editando),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_nombre_cliente'),
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre',
            errorText: _errorNombre,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_apellido_cliente'),
          controller: _apellido,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Apellido',
            errorText: _errorApellido,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_telefono_cliente'),
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Teléfono (opcional)',
            errorText: _errorTelefono,
          ),
        ),
        if (_editando) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_notas_cliente'),
            controller: _notas,
            decoration: const InputDecoration(labelText: 'Notas'),
          ),
        ],
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_continuar_cliente'),
          texto: _editando ? 'Guardar' : 'Continuar',
          onPressed: _ocupado ? null : _continuar,
        ),
      ],
    );
  }
}

/// Lo que decidió el vendedor ante clientes parecidos: [usar] un cliente
/// existente, o null para seguir con los datos escritos.
class _Decision {
  const _Decision({this.usar});

  final Cliente? usar;
}

class _HojaParecidos extends StatelessWidget {
  const _HojaParecidos({required this.parecidos, required this.editando});

  final List<Cliente> parecidos;
  final bool editando;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cliente in parecidos) ...[
          _FilaParecido(cliente: cliente),
          if (!editando) ...[
            const SizedBox(height: 8),
            BotonPrincipal(
              key: Key('usar_cliente_${cliente.id}'),
              texto: 'Usar este cliente',
              variante: VarianteBoton.contorno,
              onPressed: () =>
                  Navigator.of(context).pop(_Decision(usar: cliente)),
            ),
          ],
          const SizedBox(height: 12),
        ],
        BotonPrincipal(
          key: const Key('crear_otro_cliente'),
          texto: editando
              ? 'Guardar de todas formas'
              : 'Crear otro de todas formas',
          onPressed: () => Navigator.of(context).pop(const _Decision()),
        ),
        if (editando) ...[
          const SizedBox(height: 8),
          BotonPrincipal(
            key: const Key('volver_cliente'),
            texto: 'Volver',
            variante: VarianteBoton.contorno,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}

class _FilaParecido extends ConsumerWidget {
  const _FilaParecido({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoClienteProvider(cliente.id)).valueOrNull ?? 0;
    final telefono = cliente.telefono;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cliente.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(telefono == null || telefono.isEmpty ? 'Sin teléfono' : telefono),
        Text(saldo == 0 ? 'Al día' : 'Debe ${formatoMoneda(saldo)}'),
      ],
    );
  }
}
