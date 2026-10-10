import 'package:flutter/widgets.dart';

/// Marca un elemento que los globos del recorrido pueden señalar por [id].
class ObjetivoRecorrido extends StatefulWidget {
  const ObjetivoRecorrido({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  static final _registro = <String, GlobalKey>{};

  /// Contexto del elemento montado con [id], o null si no está.
  static BuildContext? contextoDe(String id) => _registro[id]?.currentContext;

  @override
  State<ObjetivoRecorrido> createState() => _ObjetivoRecorridoState();
}

class _ObjetivoRecorridoState extends State<ObjetivoRecorrido> {
  final _clave = GlobalKey();

  @override
  void initState() {
    super.initState();
    ObjetivoRecorrido._registro[widget.id] = _clave;
  }

  @override
  void didUpdateWidget(ObjetivoRecorrido anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.id != widget.id) {
      _quitar(anterior.id);
      ObjetivoRecorrido._registro[widget.id] = _clave;
    }
  }

  void _quitar(String id) {
    if (ObjetivoRecorrido._registro[id] == _clave) {
      ObjetivoRecorrido._registro.remove(id);
    }
  }

  @override
  void dispose() {
    _quitar(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _clave, child: widget.child);
}
