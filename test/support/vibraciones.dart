import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intercepta el canal de plataforma y anota cada vibración pedida.
List<String> registrarVibraciones(WidgetTester tester) {
  final registro = <String>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
    if (llamada.method == 'HapticFeedback.vibrate') {
      registro.add(llamada.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return registro;
}
