import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // For Windows host testing, ensure the vendored SQLite3 DLL is available
  // at test/support/sqlite3.dll for sqlite3 package FFI bindings
  if (Platform.isWindows) {
    final dllPath = p.join(Directory.current.path, 'test', 'support', 'sqlite3.dll');
    final dllFile = File(dllPath);
    if (!dllFile.existsSync()) {
      throw StateError('SQLite3 DLL not found at: $dllPath');
    }
  }

  await testMain();
}
