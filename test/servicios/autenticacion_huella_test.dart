import 'package:app_ventas/servicios/autenticacion_huella.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// `LocalAuthentication` sin el plugin: responde lo que la prueba indique.
class _AuthFalsa extends LocalAuthentication {
  bool soportado = true;
  List<BiometricType> biometrias = const [BiometricType.strong];
  Object? error;
  bool respuesta = true;
  String? motivo;
  bool? soloBiometria;
  Iterable<AuthMessages>? mensajes;

  @override
  Future<bool> isDeviceSupported() async => soportado;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrias;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    motivo = localizedReason;
    soloBiometria = biometricOnly;
    mensajes = authMessages;
    if (error != null) throw error!;
    return respuesta;
  }
}

void main() {
  late _AuthFalsa falsa;
  late AutenticacionHuellaLocal huella;

  setUp(() {
    falsa = _AuthFalsa();
    huella = AutenticacionHuellaLocal(falsa);
  });

  group('disponible', () {
    test('sí con soporte y una biometría registrada', () async {
      expect(await huella.disponible(), isTrue);
    });

    test('no sin soporte', () async {
      falsa.soportado = false;
      expect(await huella.disponible(), isFalse);
    });

    test('no sin biometrías registradas', () async {
      falsa.biometrias = const [];
      expect(await huella.disponible(), isFalse);
    });
  });

  group('confirmar', () {
    test('pide solo biometría, con el motivo y textos en español', () async {
      expect(
        await huella.confirmar('Confirma que eres Ana'),
        ResultadoHuella.aprobada,
      );
      expect(falsa.motivo, 'Confirma que eres Ana');
      expect(falsa.soloBiometria, isTrue);
      final android = falsa.mensajes!.whereType<AndroidAuthMessages>().single;
      expect(android.cancelButton, 'Usar PIN');
    });

    test('false es cancelada', () async {
      falsa.respuesta = false;
      expect(await huella.confirmar('x'), ResultadoHuella.cancelada);
    });

    LocalAuthException error(LocalAuthExceptionCode codigo) =>
        LocalAuthException(code: codigo);

    test('los bloqueos son bloqueada', () async {
      for (final codigo in [
        LocalAuthExceptionCode.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout,
      ]) {
        falsa.error = error(codigo);
        expect(
          await huella.confirmar('x'),
          ResultadoHuella.bloqueada,
          reason: '$codigo',
        );
      }
    });

    test('sin sensor o sin huellas es sinHuellas', () async {
      for (final codigo in [
        LocalAuthExceptionCode.noBiometricHardware,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.noCredentialsSet,
      ]) {
        falsa.error = error(codigo);
        expect(
          await huella.confirmar('x'),
          ResultadoHuella.sinHuellas,
          reason: '$codigo',
        );
      }
    });

    test('cualquier otro error es cancelada, sin romper la pantalla', () async {
      falsa.error = error(LocalAuthExceptionCode.userCanceled);
      expect(await huella.confirmar('x'), ResultadoHuella.cancelada);
      falsa.error = StateError('plugin roto');
      expect(await huella.confirmar('x'), ResultadoHuella.cancelada);
    });
  });
}
