import 'package:app_ventas/screens/escaner/escaner_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  const base = MobileScannerState.uninitialized();

  test('sin cámara no hay linterna', () {
    final estado = base.copyWith(
      torchState: TorchState.off,
      error: const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    expect(linternaDisponible(estado), isFalse);
  });

  test('con linterna no disponible no se ofrece', () {
    final estado = base.copyWith(torchState: TorchState.unavailable);
    expect(linternaDisponible(estado), isFalse);
  });

  test('con cámara y linterna se ofrece', () {
    final estado = base.copyWith(torchState: TorchState.off);
    expect(linternaDisponible(estado), isTrue);
  });
}
