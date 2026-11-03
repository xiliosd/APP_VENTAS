import 'dart:io';

import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/supabase_nube_tienda.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sin red es ErrorSinConexion', () {
    expect(
      traducirErrorTienda(const SocketException('sin red')),
      isA<ErrorSinConexion>(),
    );
    expect(
      traducirErrorTienda(AuthRetryableFetchException()),
      isA<ErrorSinConexion>(),
    );
  });

  test('sesión vencida es ErrorSesionTienda', () {
    expect(
      traducirErrorTienda(const AuthException('vencida')),
      isA<ErrorSesionTienda>(),
    );
    expect(
      traducirErrorTienda(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      ),
      isA<ErrorSesionTienda>(),
    );
  });

  test('otros errores pasan igual', () {
    const error = PostgrestException(message: 'otro', code: '23505');
    expect(traducirErrorTienda(error), same(error));
  });
}
