import 'package:app_ventas/util/pin_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hashPin is deterministic and never returns the raw pin', () {
    final hash = hashPin('1234');
    expect(hash, hashPin('1234'));
    expect(hash, isNot(contains('1234')));
  });

  test('hashPin differs for different pins', () {
    expect(hashPin('1234'), isNot(hashPin('4321')));
  });
}
