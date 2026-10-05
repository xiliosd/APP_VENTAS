import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/supabase_nube_respaldo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sin internet al refrescar el token no es un problema de sesión', () {
    final error = AuthRetryableFetchException(message: 'Failed host lookup');
    expect(traducirErrorNube(error), same(error));
  });

  test('un token inválido o revocado es un problema de sesión', () {
    expect(
      traducirErrorNube(AuthException('refresh_token_not_found')),
      isA<ErrorSesionRespaldo>(),
    );
  });

  test('Storage 401/403 es sesión; los demás errores pasan tal cual', () {
    expect(
      traducirErrorNube(const StorageException('x', statusCode: '403')),
      isA<ErrorSesionRespaldo>(),
    );
    const otro = StorageException('x', statusCode: '500');
    expect(traducirErrorNube(otro), same(otro));
  });
}
