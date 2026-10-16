import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Cómo terminó un intento de entrar con la huella.
enum ResultadoHuella { aprobada, cancelada, bloqueada, sinHuellas }

/// La huella (u otra biometría) del celular, sin el PIN ni el patrón del
/// celular: esos no prueban que sea el usuario de la app.
abstract class AutenticacionHuella {
  /// El celular tiene biometría y al menos una registrada.
  Future<bool> disponible();

  /// Muestra el diálogo del sistema con [motivo].
  Future<ResultadoHuella> confirmar(String motivo);
}

class AutenticacionHuellaLocal implements AutenticacionHuella {
  AutenticacionHuellaLocal([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> disponible() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ResultadoHuella> confirmar(String motivo) async {
    try {
      final aprobada = await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Entrar a VeciTienda',
            signInHint: 'Toca el sensor de huella',
            cancelButton: 'Usar PIN',
          ),
        ],
      );
      return aprobada ? ResultadoHuella.aprobada : ResultadoHuella.cancelada;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => ResultadoHuella.bloqueada,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet => ResultadoHuella.sinHuellas,
        _ => ResultadoHuella.cancelada,
      };
    } catch (_) {
      // Un fallo inesperado del plugin no debe tumbar la pantalla: queda el PIN.
      return ResultadoHuella.cancelada;
    }
  }
}

final autenticacionHuellaProvider = Provider<AutenticacionHuella>(
  (ref) => AutenticacionHuellaLocal(),
);
