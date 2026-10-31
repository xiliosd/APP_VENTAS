import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/catalogo_producto.dart';

/// Lo que se pudo averiguar de un producto por su código.
class DatosProducto {
  const DatosProducto({
    this.nombre,
    this.marca,
    this.tamano,
    this.envase,
    this.tipo,
  });

  final String? nombre;
  final String? marca;
  final String? tamano;
  final String? envase;
  final String? tipo;
}

/// Busca los datos de un producto por su código de barras. Devuelve null si
/// no lo encuentra o si falla (sin internet, lento, respuesta rara).
abstract class ConsultaProducto {
  Future<DatosProducto?> buscar(String codigo);
}

/// Open Food Facts: base abierta y gratuita de productos.
class OpenFoodFacts implements ConsultaProducto {
  OpenFoodFacts({Uri? base, this.limite = const Duration(seconds: 5)})
    : base = base ?? Uri.parse('https://world.openfoodfacts.org');

  final Uri base;
  final Duration limite;

  static const _campos =
      'product_name,product_name_es,brands,quantity,'
      'packaging_tags,categories_tags';

  @override
  Future<DatosProducto?> buscar(String codigo) async {
    final cliente = HttpClient()..connectionTimeout = limite;
    try {
      return await _buscar(cliente, codigo.trim()).timeout(limite);
    } catch (_) {
      return null;
    } finally {
      cliente.close(force: true);
    }
  }

  Future<DatosProducto?> _buscar(HttpClient cliente, String codigo) async {
    final uri = base.replace(
      path: '/api/v2/product/${Uri.encodeComponent(codigo)}',
      queryParameters: {'fields': _campos},
    );
    final pedido = await cliente.getUrl(uri);
    pedido.headers.set(HttpHeaders.userAgentHeader, 'VeciTienda/1.0 (Android)');
    final respuesta = await pedido.close();
    if (respuesta.statusCode != 200) return null;
    final cuerpo = jsonDecode(await respuesta.transform(utf8.decoder).join());
    if (cuerpo is! Map || cuerpo['status'] != 1) return null;
    final p = cuerpo['product'];
    if (p is! Map) return null;

    String? texto(Object? v) {
      final t = v is String ? v.trim() : null;
      return t == null || t.isEmpty ? null : t;
    }

    List<String> etiquetas(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];

    // OFF a veces antepone comas o espacios: se toma la primera marca real.
    final marca = p['brands'] is String
        ? (p['brands'] as String)
              .split(',')
              .map(texto)
              .firstWhere((m) => m != null, orElse: () => null)
        : null;
    return DatosProducto(
      nombre: texto(p['product_name_es']) ?? texto(p['product_name']),
      marca: marca,
      tamano: texto(p['quantity']),
      envase: envaseDesdeOff(etiquetas(p['packaging_tags'])),
      tipo: tipoDesdeOff(etiquetas(p['categories_tags'])),
    );
  }
}

final consultaProductoProvider = Provider<ConsultaProducto>(
  (ref) => OpenFoodFacts(),
);
