# App de ventas Fase 2B+2C (respaldo en la nube) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Respaldar automáticamente la base SQLite de la tienda en Supabase Storage, con la tienda identificada por su celular (OTP), y poder restaurarla en un celular nuevo.

**Architecture:** Una interfaz `NubeRespaldo` (implementación Supabase + versión falsa para pruebas) aísla la red. `CopiaBaseDatos` crea y valida copias con `VACUUM INTO`/`sqlite3`; `Restaurador` descarga, valida y reemplaza el archivo. Un `Notifier` de Riverpod (`respaldoProvider`) programa el respaldo 30 s después del último cambio y expone el estado a las pantallas nuevas (Bienvenida, Verificar teléfono, Ajustes → Respaldo), hechas con el sistema de diseño de la 2E (`lib/ui/`).

**Tech Stack:** Flutter 3.47, flutter_riverpod ^2.6.1, drift ^2.34, sqlite3 ^3.5.2, **supabase_flutter ^2.18.0** (nueva).

**Spec:** `docs/superpowers/specs/2026-10-05-app-ventas-fase2bc-respaldo-design.md`

## Global Constraints

- Única dependencia nueva: `supabase_flutter: ^2.18.0` (API verificada: `auth.signInWithOtp(phone:)`, `auth.verifyOTP(phone:, token:, type: OtpType.sms)`, `storage.from(b).upload(path, File, fileOptions: FileOptions(upsert: true))`, `.download(path) → Uint8List`, `.list(path:) → List<FileObject>` con `name`/`updatedAt`).
- Claves solo por compilación: `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_ANON_KEY=...`. Nada en el repo. Sin claves: respaldo "No configurado" y `Supabase.initialize` no se llama.
- Bucket privado `respaldos`; un objeto por tienda en `<auth.uid>/app_ventas.sqlite`; solo la copia más reciente.
- Respaldo automático: al abrir la app y 30 s después del último cambio; uno a la vez; errores de red silenciosos (reintento en el próximo cambio o al abrir).
- Celular: prefijo +57 fijo, 10 dígitos que empiezan por 3 (`^3\d{9}$`); código de 6 dígitos; "Reenviar código" tras 60 s.
- Nunca se toca la base local si el respaldo descargado es inválido o de versión más nueva (`user_version` > `schemaVersion`).
- La app sigue funcionando 100% sin internet y sin registro.
- Pantallas con los componentes de `lib/ui/` (`BotonPrincipal`, `EstadoVacio`, `avisar`, `ColoresApp`…); textos en español.
- Tests: Drift en memoria; la nube es `NubeRespaldoFalsa` (sin red). No hacer I/O de archivos dentro de `testWidgets` (FakeAsync no lo completa): en widget tests el copiador y el restaurador se sustituyen por versiones sin I/O; las pruebas con archivos reales son `test(...)` normales.
- Commits en inglés imperativo, terminando con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Respaldo en curso cuando llegan más cambios**: no deben correr dos subidas a la vez ni perderse el último cambio (debe quedar programado otro respaldo). → Task 5.
2. **Activar con un número que ya tiene respaldo y tocar "Cancelar" o cerrar el diálogo**: no se sube nada y la sesión queda cerrada (no se pisa el respaldo bueno). → Task 6.
3. **Restaurar con un archivo dañado o de versión más nueva**: mensaje claro y la base local intacta. → Tasks 3 y 6.
4. **Cerrar la base dos veces** (al restaurar y al invalidar el provider) no debe fallar. → Task 1.
5. **Sesión vencida al subir** (401/403): estado "Requiere reconexión", no un error silencioso eterno. → Task 5.

---

## File Structure

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `pubspec.yaml` | Modificar | `supabase_flutter` |
| `android/app/src/main/AndroidManifest.xml` | Modificar | Permiso `INTERNET` (release) |
| `lib/main.dart` | Modificar | `Supabase.initialize` si hay claves |
| `lib/data/database.dart` | Modificar | `archivoBaseDatos()`, `close()` idempotente |
| `lib/respaldo/config_respaldo.dart` | Crear | Claves por `--dart-define` |
| `lib/respaldo/telefono.dart` | Crear | `telefonoE164`, `telefonoEnmascarado` |
| `lib/respaldo/nube_respaldo.dart` | Crear | Interfaz `NubeRespaldo`, errores |
| `lib/respaldo/copia_base_datos.dart` | Crear | Crear y validar copias |
| `lib/respaldo/restaurador.dart` | Crear | Descargar, validar, reemplazar |
| `lib/respaldo/supabase_nube_respaldo.dart` | Crear | Implementación Supabase |
| `lib/respaldo/respaldo_provider.dart` | Crear | Estado, providers y `RespaldoNotifier` |
| `lib/util/fecha_util.dart` | Modificar | `textoUltimoRespaldo` |
| `lib/screens/respaldo/verificar_telefono_screen.dart` | Crear | Celular + código, activar/restaurar |
| `lib/screens/respaldo/dialogo_respaldo_existente.dart` | Crear | "Ya hay un respaldo…" |
| `lib/screens/respaldo/respaldo_screen.dart` | Crear | Ajustes → Respaldo |
| `lib/screens/configuracion/ajustes_screen.dart` | Modificar | Entrada "Respaldo" |
| `lib/screens/login/bienvenida_screen.dart` | Crear | Crear tienda / Restaurar |
| `lib/screens/raiz_app.dart` | Modificar | Bienvenida y mantener vivo el respaldo |
| `lib/screens/login/crear_admin_inicial_screen.dart` | Modificar | Cerrarse al crear (ahora se abre desde Bienvenida) |
| `test/support/respaldo_prueba.dart` | Crear | `NubeRespaldoFalsa`, `RestauradorFalso`, `containerRespaldo` |
| `README.md` | Modificar | Configuración de Supabase y compilación |

---

### Task 1: Dependencia, configuración y base de datos preparada

**Files:**
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`, `lib/data/database.dart`
- Create: `lib/respaldo/config_respaldo.dart`
- Test: `test/data/database_test.dart`, `test/respaldo/config_respaldo_test.dart`

**Interfaces:**
- Produces: `abstract final class ConfigRespaldo { static const String url; static const String anonKey; static bool get configurado; }`; `Future<File> archivoBaseDatos()` (top-level en `database.dart`); `AppDatabase.close()` idempotente.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar al final de `test/data/database_test.dart` (antes de la llave final de `main`), y los imports `import 'package:drift/drift.dart';` si faltan:

```dart
  test('cerrar la base dos veces solo la cierra una vez', () async {
    final contador = _ContadorCierres();
    final db = AppDatabase(NativeDatabase.memory().interceptWith(contador));
    await db.customSelect('SELECT 1').get();

    await db.close();
    await db.close();

    expect(contador.cierres, 1);
  });
```

y al final del archivo (fuera de `main`):

```dart
class _ContadorCierres extends QueryInterceptor {
  int cierres = 0;

  @override
  Future<void> close(QueryExecutor inner) {
    cierres++;
    return inner.close();
  }
}
```

Crear `test/respaldo/config_respaldo_test.dart`:

```dart
import 'package:app_ventas/respaldo/config_respaldo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin --dart-define el respaldo no está configurado', () {
    expect(ConfigRespaldo.url, isEmpty);
    expect(ConfigRespaldo.configurado, isFalse);
  });
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/data/database_test.dart test/respaldo/config_respaldo_test.dart`
Expected: FAIL — `cierres` es 2; `config_respaldo.dart` no existe.

- [ ] **Step 3: Implementar**

Run: `flutter pub add supabase_flutter:^2.18.0`

En `android/app/src/main/AndroidManifest.xml`, agregar justo después de la etiqueta de apertura `<manifest ...>`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

Crear `lib/respaldo/config_respaldo.dart`:

```dart
/// Claves de Supabase, pasadas al compilar:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// Nunca se guardan en el repositorio. Sin ellas la app funciona igual y el
/// respaldo aparece como "No configurado".
abstract final class ConfigRespaldo {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configurado => url.isNotEmpty && anonKey.isNotEmpty;
}
```

Reemplazar todo `lib/main.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'respaldo/config_respaldo.dart';
import 'screens/raiz_app.dart';
import 'ui/tema_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (ConfigRespaldo.configurado) {
    await Supabase.initialize(
      url: ConfigRespaldo.url,
      anonKey: ConfigRespaldo.anonKey,
    );
  }
  runApp(const ProviderScope(child: AppVentas()));
}

class AppVentas extends StatelessWidget {
  const AppVentas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Ventas',
      theme: temaApp(),
      home: const RaizApp(),
    );
  }
}
```

En `lib/data/database.dart`:

1. Reemplazar el método `_openConnection` completo por:

```dart
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      return NativeDatabase.createInBackground(await archivoBaseDatos());
    });
  }

  bool _cerrada = false;

  /// Cerrar dos veces no hace nada la segunda vez: al restaurar un respaldo
  /// la base se cierra antes de reemplazar el archivo, y otra vez cuando se
  /// invalida `databaseProvider`.
  @override
  Future<void> close() async {
    if (_cerrada) return;
    _cerrada = true;
    await super.close();
  }
```

2. Agregar al final del archivo:

```dart
/// Archivo SQLite de la app en el celular.
Future<File> archivoBaseDatos() async {
  final carpeta = await getApplicationDocumentsDirectory();
  return File(p.join(carpeta.path, 'app_ventas.sqlite'));
}
```

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test test/data test/respaldo && flutter analyze`
Expected: PASS y `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/main.dart lib/data/database.dart lib/respaldo/config_respaldo.dart test/data/database_test.dart test/respaldo/config_respaldo_test.dart
git commit -m "Add Supabase dependency, build-time config, and idempotent database close"
```

---

### Task 2: Utilidades de teléfono y de fecha del último respaldo

**Files:**
- Create: `lib/respaldo/telefono.dart`
- Modify: `lib/util/fecha_util.dart`
- Test: `test/respaldo/telefono_test.dart`, `test/util/fecha_util_test.dart`

**Interfaces:**
- Produces: `String? telefonoE164(String digitos)` (`'3001234567'` → `'+573001234567'`, inválido → null); `String telefonoEnmascarado(String e164)` (`'+573001234567'` → `'+57 300 *** 4567'`); `String textoUltimoRespaldo(DateTime fecha, DateTime ahora)` (`'hoy 14:32'`, `'ayer 09:05'`, `'03/10/2026 14:32'`).

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/respaldo/telefono_test.dart`:

```dart
import 'package:app_ventas/respaldo/telefono.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telefonoE164 acepta celulares colombianos de 10 dígitos', () {
    expect(telefonoE164('3001234567'), '+573001234567');
    expect(telefonoE164(' 300 123 4567 '), '+573001234567');
  });

  test('telefonoE164 rechaza fijos, longitudes y letras', () {
    expect(telefonoE164('6011234567'), isNull);
    expect(telefonoE164('300123456'), isNull);
    expect(telefonoE164('30012345678'), isNull);
    expect(telefonoE164('300123456a'), isNull);
    expect(telefonoE164(''), isNull);
  });

  test('telefonoEnmascarado oculta el centro del número', () {
    expect(telefonoEnmascarado('+573001234567'), '+57 300 *** 4567');
    expect(telefonoEnmascarado('573001234567'), '+57 300 *** 4567');
  });
}
```

Agregar dentro de `main()` en `test/util/fecha_util_test.dart`:

```dart
  test('textoUltimoRespaldo usa hoy, ayer o la fecha completa', () {
    final ahora = DateTime(2026, 10, 5, 18);
    expect(textoUltimoRespaldo(DateTime(2026, 10, 5, 14, 32), ahora),
        'hoy 14:32');
    expect(textoUltimoRespaldo(DateTime(2026, 10, 4, 9, 5), ahora),
        'ayer 09:05');
    expect(textoUltimoRespaldo(DateTime(2026, 10, 3, 14, 32), ahora),
        '03/10/2026 14:32');
  });
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/respaldo/telefono_test.dart test/util/fecha_util_test.dart`
Expected: FAIL — funciones no definidas.

- [ ] **Step 3: Implementar**

Crear `lib/respaldo/telefono.dart`:

```dart
/// `'+57XXXXXXXXXX'` si [digitos] es un celular colombiano de 10 dígitos que
/// empieza por 3 (se ignoran espacios); si no, null.
String? telefonoE164(String digitos) {
  final limpio = digitos.replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^3\d{9}$').hasMatch(limpio) ? '+57$limpio' : null;
}

/// `'+57 300 *** 4567'`, para mostrar el número sin exponerlo completo.
String telefonoEnmascarado(String e164) {
  final digitos = e164.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 12 || !digitos.startsWith('57')) return e164;
  return '+57 ${digitos.substring(2, 5)} *** ${digitos.substring(8)}';
}
```

Agregar al final de `lib/util/fecha_util.dart`:

```dart
/// "hoy 14:32", "ayer 09:05" o "03/10/2026 14:32".
String textoUltimoRespaldo(DateTime fecha, DateTime ahora) {
  final dias = inicioDelDia(ahora).difference(inicioDelDia(fecha)).inDays;
  if (dias == 0) return 'hoy ${formatoHora(fecha)}';
  if (dias == 1) return 'ayer ${formatoHora(fecha)}';
  return formatoFechaHora(fecha);
}
```

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test test/respaldo test/util`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/respaldo/telefono.dart lib/util/fecha_util.dart test/respaldo/telefono_test.dart test/util/fecha_util_test.dart
git commit -m "Add phone number and last-backup date helpers"
```

---

### Task 3: Copia, validación y restauración de la base (con archivos reales)

**Files:**
- Create: `lib/respaldo/nube_respaldo.dart`, `lib/respaldo/copia_base_datos.dart`, `lib/respaldo/restaurador.dart`, `test/support/respaldo_prueba.dart`
- Test: `test/respaldo/copia_base_datos_test.dart`, `test/respaldo/restaurador_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` con `close()` idempotente (Task 1).
- Produces:
  - `abstract class NubeRespaldo { bool get haySesion; String? get telefonoConectado; Future<void> enviarCodigo(String telefonoE164); Future<void> verificarCodigo(String telefonoE164, String codigo); Future<void> cerrarSesion(); Future<DateTime?> fechaUltimoRespaldo(); Future<void> subir(File copia); Future<void> descargar(File destino); }`
  - `class ErrorSesionRespaldo implements Exception` (sesión vencida/revocada), `class ErrorCodigoRespaldo implements Exception { final String mensaje; }` (código incorrecto/vencido).
  - `abstract final class CopiaBaseDatos { static const tablas; static Future<File> crearCopia(AppDatabase db, Directory temporal); static bool esCopiaValida(File archivo, {required int versionMaxima}); }`
  - `enum ResultadoRestauracion { restaurado, sinRespaldo, invalido }`; `class Restaurador { Restaurador({required Future<File> Function() archivoBase, required Future<Directory> Function() directorioTemporal}); Future<ResultadoRestauracion> restaurar(NubeRespaldo nube, AppDatabase db); }`
  - Test support: `NubeRespaldoFalsa`, `RestauradorFalso`, `containerRespaldo(...)` (este último se completa en la Task 5).

- [ ] **Step 1: Crear la interfaz y la nube falsa**

Crear `lib/respaldo/nube_respaldo.dart`:

```dart
import 'dart:io';

/// Dónde se guarda el respaldo y cómo se identifica la tienda. La app solo
/// conoce esta interfaz; la implementación real es Supabase.
abstract class NubeRespaldo {
  bool get haySesion;

  /// Celular conectado en formato E.164, o null sin sesión.
  String? get telefonoConectado;

  Future<void> enviarCodigo(String telefonoE164);

  /// Lanza [ErrorCodigoRespaldo] si el código es incorrecto o venció.
  Future<void> verificarCodigo(String telefonoE164, String codigo);

  Future<void> cerrarSesion();

  /// Fecha del respaldo guardado para esta tienda, o null si no hay.
  Future<DateTime?> fechaUltimoRespaldo();

  /// Reemplaza el respaldo de la tienda con [copia].
  Future<void> subir(File copia);

  /// Escribe el respaldo de la tienda en [destino].
  Future<void> descargar(File destino);
}

/// La sesión del respaldo venció o fue revocada: hay que verificar de nuevo.
class ErrorSesionRespaldo implements Exception {
  const ErrorSesionRespaldo();
}

/// El código de verificación es incorrecto o venció.
class ErrorCodigoRespaldo implements Exception {
  const ErrorCodigoRespaldo(this.mensaje);

  final String mensaje;
}
```

Crear `test/support/respaldo_prueba.dart`:

```dart
import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/restaurador.dart';

/// Nube en memoria: sin red. `subir` solo recuerda el archivo (no lo lee),
/// para poder usarse dentro de `testWidgets`.
class NubeRespaldoFalsa implements NubeRespaldo {
  NubeRespaldoFalsa({
    bool conSesion = false,
    this.telefono,
    this.fecha,
    this.codigoValido = '123456',
  }) : _sesion = conSesion;

  bool _sesion;
  String? telefono;
  DateTime? fecha;
  final String codigoValido;
  final enviados = <String>[];
  File? archivoSubido;
  int subidas = 0;

  /// Si no es null, `subir` lanza este error.
  Object? errorAlSubir;

  @override
  bool get haySesion => _sesion;

  @override
  String? get telefonoConectado => _sesion ? telefono : null;

  @override
  Future<void> enviarCodigo(String telefonoE164) async =>
      enviados.add(telefonoE164);

  @override
  Future<void> verificarCodigo(String telefonoE164, String codigo) async {
    if (codigo != codigoValido) {
      throw const ErrorCodigoRespaldo('Código incorrecto');
    }
    _sesion = true;
    telefono = telefonoE164;
  }

  @override
  Future<void> cerrarSesion() async => _sesion = false;

  @override
  Future<DateTime?> fechaUltimoRespaldo() async => fecha;

  @override
  Future<void> subir(File copia) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    archivoSubido = copia;
    subidas++;
    fecha = DateTime.now();
  }

  @override
  Future<void> descargar(File destino) async {
    await archivoSubido!.copy(destino.path);
  }
}

/// Restaurador sin archivos: devuelve [resultado] y cuenta las llamadas.
class RestauradorFalso extends Restaurador {
  RestauradorFalso(this.resultado)
      : super(
          archivoBase: () async => File('no_usado.sqlite'),
          directorioTemporal: () async => Directory.systemTemp,
        );

  final ResultadoRestauracion resultado;
  int llamadas = 0;

  @override
  Future<ResultadoRestauracion> restaurar(
      NubeRespaldo nube, AppDatabase db) async {
    llamadas++;
    return resultado;
  }
}
```

- [ ] **Step 2: Escribir los tests que fallan**

Crear `test/respaldo/copia_base_datos_test.dart`:

```dart
import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/copia_base_datos.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory carpeta;

  setUp(() async => carpeta = await Directory.systemTemp.createTemp('copia'));
  tearDown(() => carpeta.delete(recursive: true));

  test('crearCopia produce una copia válida con los mismos datos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    final copia = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();

    expect(CopiaBaseDatos.esCopiaValida(copia, versionMaxima: 1), isTrue);
    final abierta = AppDatabase(NativeDatabase(copia));
    expect((await abierta.select(abierta.usuarios).get()).single.nombre, 'Ana');
    await abierta.close();
  });

  test('crearCopia reemplaza la copia anterior', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final primera = await CopiaBaseDatos.crearCopia(db, carpeta);
    final segunda = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();

    expect(segunda.path, primera.path);
    expect(segunda.existsSync(), isTrue);
  });

  test('esCopiaValida rechaza un archivo que no es una base', () {
    final basura = File('${carpeta.path}/basura.sqlite')
      ..writeAsStringSync('esto no es sqlite');
    expect(CopiaBaseDatos.esCopiaValida(basura, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza una base sin las tablas de la app', () {
    final archivo = File('${carpeta.path}/vacia.sqlite');
    sqlite3.open(archivo.path)
      ..execute('CREATE TABLE otra (id INTEGER)')
      ..close();
    expect(CopiaBaseDatos.esCopiaValida(archivo, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza una copia de una versión más nueva', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final copia = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();
    sqlite3.open(copia.path)
      ..userVersion = 99
      ..close();

    expect(CopiaBaseDatos.esCopiaValida(copia, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza un archivo que no existe', () {
    expect(
        CopiaBaseDatos.esCopiaValida(File('${carpeta.path}/nada.sqlite'),
            versionMaxima: 1),
        isFalse);
  });
}
```

Crear `test/respaldo/restaurador_test.dart`:

```dart
import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/copia_base_datos.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/respaldo_prueba.dart';

void main() {
  late Directory carpeta;
  late File archivoLocal;
  late Restaurador restaurador;

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('restaurar');
    archivoLocal = File('${carpeta.path}/app_ventas.sqlite');
    restaurador = Restaurador(
      archivoBase: () async => archivoLocal,
      directorioTemporal: () async => carpeta,
    );
  });

  tearDown(() => carpeta.delete(recursive: true));

  /// Nube con un respaldo que contiene un usuario "Ana".
  Future<NubeRespaldoFalsa> nubeConRespaldo() async {
    final origen = AppDatabase(NativeDatabase.memory());
    await origen.into(origen.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final copia = await CopiaBaseDatos.crearCopia(
        origen, await carpeta.createTemp('origen'));
    await origen.close();
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(copia);
    return nube;
  }

  test('restaura el respaldo sobre la base local', () async {
    final nube = await nubeConRespaldo();
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.restaurado);
    final reabierta = AppDatabase(NativeDatabase(archivoLocal));
    final usuarios = await reabierta.select(reabierta.usuarios).get();
    expect(usuarios.map((u) => u.nombre), ['Ana']);
    await reabierta.close();
  });

  test('sin respaldo en la nube no toca la base local', () async {
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado =
        await restaurador.restaurar(NubeRespaldoFalsa(conSesion: true), local);

    expect(resultado, ResultadoRestauracion.sinRespaldo);
    expect((await local.select(local.usuarios).get()).single.nombre, 'Viejo');
    await local.close();
  });

  test('un respaldo dañado no toca la base local', () async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    await nube.subir(File('${carpeta.path}/basura.sqlite')
      ..writeAsStringSync('no es sqlite'));
    final local = AppDatabase(NativeDatabase(archivoLocal));
    await local.into(local.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Viejo', rol: 'admin', pinHash: 'y'));

    final resultado = await restaurador.restaurar(nube, local);

    expect(resultado, ResultadoRestauracion.invalido);
    expect((await local.select(local.usuarios).get()).single.nombre, 'Viejo');
    await local.close();
  });
}
```

- [ ] **Step 3: Correr y verificar que fallan**

Run: `flutter test test/respaldo/copia_base_datos_test.dart test/respaldo/restaurador_test.dart`
Expected: FAIL — `copia_base_datos.dart` / `restaurador.dart` no existen.

- [ ] **Step 4: Implementar**

Crear `lib/respaldo/copia_base_datos.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../data/database.dart';

/// Crea y valida copias completas de la base de la app.
abstract final class CopiaBaseDatos {
  /// Tablas que debe tener una copia para considerarse de esta app.
  static const tablas = [
    'usuarios',
    'productos',
    'clientes',
    'ventas',
    'pagos_fiado',
    'gastos',
  ];

  /// Copia consistente de [db] (aunque esté abierta) en [temporal]. Siempre
  /// usa el mismo nombre, así que reemplaza la copia anterior.
  static Future<File> crearCopia(AppDatabase db, Directory temporal) async {
    final destino = File(p.join(temporal.path, 'respaldo_app_ventas.sqlite'));
    if (await destino.exists()) await destino.delete();
    await db.customStatement('VACUUM INTO ?', [destino.path]);
    return destino;
  }

  /// true si [archivo] es una base SQLite de esta app con versión de esquema
  /// no mayor que [versionMaxima].
  static bool esCopiaValida(File archivo, {required int versionMaxima}) {
    if (!archivo.existsSync()) return false;
    Database? bd;
    try {
      bd = sqlite3.open(archivo.path, mode: OpenMode.readOnly);
      final existentes = bd
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((fila) => fila['name'] as String)
          .toSet();
      if (!tablas.every(existentes.contains)) return false;
      return bd.userVersion <= versionMaxima;
    } on SqliteException {
      return false;
    } finally {
      bd?.close();
    }
  }
}
```

Crear `lib/respaldo/restaurador.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/database.dart';
import 'copia_base_datos.dart';
import 'nube_respaldo.dart';

enum ResultadoRestauracion { restaurado, sinRespaldo, invalido }

/// Descarga el respaldo, lo valida y solo entonces reemplaza la base local.
class Restaurador {
  Restaurador({required this.archivoBase, required this.directorioTemporal});

  final Future<File> Function() archivoBase;
  final Future<Directory> Function() directorioTemporal;

  /// Si devuelve [ResultadoRestauracion.restaurado], [db] quedó cerrada y el
  /// archivo local reemplazado: quien llama debe abrir una base nueva.
  Future<ResultadoRestauracion> restaurar(
      NubeRespaldo nube, AppDatabase db) async {
    if (await nube.fechaUltimoRespaldo() == null) {
      return ResultadoRestauracion.sinRespaldo;
    }
    final temporal = await directorioTemporal();
    final descargado = File(p.join(temporal.path, 'restaurar_app_ventas.sqlite'));
    if (await descargado.exists()) await descargado.delete();
    await nube.descargar(descargado);

    if (!CopiaBaseDatos.esCopiaValida(descargado,
        versionMaxima: db.schemaVersion)) {
      await descargado.delete();
      return ResultadoRestauracion.invalido;
    }

    await db.close();
    final base = await archivoBase();
    for (final sufijo in ['-wal', '-shm', '-journal']) {
      final auxiliar = File('${base.path}$sufijo');
      if (await auxiliar.exists()) await auxiliar.delete();
    }
    await descargado.copy(base.path);
    await descargado.delete();
    return ResultadoRestauracion.restaurado;
  }
}
```

- [ ] **Step 5: Correr y verificar que pasan**

Run: `flutter test test/respaldo && flutter analyze`
Expected: PASS (9 tests nuevos) y `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/respaldo test/respaldo test/support/respaldo_prueba.dart
git commit -m "Add backup copy, validation, and safe restore"
```

---

### Task 4: Implementación Supabase de la nube

**Files:**
- Create: `lib/respaldo/supabase_nube_respaldo.dart`

**Interfaces:**
- Consumes: `NubeRespaldo`, `ErrorSesionRespaldo`, `ErrorCodigoRespaldo` (Task 3).
- Produces: `SupabaseNubeRespaldo(SupabaseClient cliente)`.

Esta clase solo traduce llamadas a Supabase; no tiene lógica propia que probar sin red. Se verifica con `flutter analyze` aquí y contra el proyecto real en la Task 9.

- [ ] **Step 1: Implementar**

Crear `lib/respaldo/supabase_nube_respaldo.dart`:

```dart
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'nube_respaldo.dart';

/// [NubeRespaldo] sobre Supabase: Auth por teléfono (OTP) y Storage.
class SupabaseNubeRespaldo implements NubeRespaldo {
  SupabaseNubeRespaldo(this._cliente);

  final SupabaseClient _cliente;

  static const _bucket = 'respaldos';
  static const _archivo = 'app_ventas.sqlite';

  GoTrueClient get _auth => _cliente.auth;

  StorageFileApi get _storage => _cliente.storage.from(_bucket);

  String get _carpeta {
    final usuario = _auth.currentUser;
    if (usuario == null) throw const ErrorSesionRespaldo();
    return usuario.id;
  }

  @override
  bool get haySesion => _auth.currentSession != null;

  @override
  String? get telefonoConectado {
    final telefono = _auth.currentUser?.phone;
    if (telefono == null || telefono.isEmpty) return null;
    return telefono.startsWith('+') ? telefono : '+$telefono';
  }

  @override
  Future<void> enviarCodigo(String telefonoE164) =>
      _auth.signInWithOtp(phone: telefonoE164);

  @override
  Future<void> verificarCodigo(String telefonoE164, String codigo) async {
    try {
      await _auth.verifyOTP(
          phone: telefonoE164, token: codigo, type: OtpType.sms);
    } on AuthException catch (e) {
      throw ErrorCodigoRespaldo(e.message);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<DateTime?> fechaUltimoRespaldo() => _conSesion(() async {
        final archivos = await _storage.list(path: _carpeta);
        for (final archivo in archivos) {
          if (archivo.name == _archivo && archivo.updatedAt != null) {
            return DateTime.parse(archivo.updatedAt!).toLocal();
          }
        }
        return null;
      });

  @override
  Future<void> subir(File copia) => _conSesion(() => _storage.upload(
        '$_carpeta/$_archivo',
        copia,
        fileOptions: const FileOptions(upsert: true),
      ));

  @override
  Future<void> descargar(File destino) => _conSesion(() async {
        final bytes = await _storage.download('$_carpeta/$_archivo');
        await destino.writeAsBytes(bytes, flush: true);
      });

  /// Traduce errores de sesión (401/403, token inválido) a
  /// [ErrorSesionRespaldo]; los demás (red) se propagan tal cual.
  Future<T> _conSesion<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on AuthException {
      throw const ErrorSesionRespaldo();
    } on StorageException catch (e) {
      if (e.statusCode == '401' || e.statusCode == '403') {
        throw const ErrorSesionRespaldo();
      }
      rethrow;
    }
  }
}
```

- [ ] **Step 2: Verificar que compila y pasa el análisis**

Run: `flutter analyze lib/respaldo`
Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/respaldo/supabase_nube_respaldo.dart
git commit -m "Add Supabase-backed backup cloud"
```

---

### Task 5: Estado y programación del respaldo (`respaldoProvider`)

**Files:**
- Create: `lib/respaldo/respaldo_provider.dart`
- Modify: `test/support/respaldo_prueba.dart` (agregar `containerRespaldo`)
- Test: `test/respaldo/respaldo_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4; `databaseProvider`, `sesionProvider`.
- Produces:
  - `const retardoRespaldo = Duration(seconds: 30);`
  - `enum FaseRespaldo { noConfigurado, desactivado, activo, requiereReconexion }`
  - `class EstadoRespaldo { FaseRespaldo fase; String? telefono; DateTime? ultimoRespaldo; bool respaldando; EstadoRespaldo copiar({...}); }`
  - `nubeRespaldoProvider: Provider<NubeRespaldo?>`, `copiadorProvider: Provider<Future<File> Function()>`, `restauradorProvider: Provider<Restaurador>`, `respaldoProvider: NotifierProvider<RespaldoNotifier, EstadoRespaldo>`
  - `RespaldoNotifier`: `Future<bool> respaldarAhora()`, `Future<void> enviarCodigo(String)`, `Future<DateTime?> verificar(String telefonoE164, String codigo)`, `Future<void> desconectar()`, `Future<ResultadoRestauracion> restaurar()`.
  - Test helper: `ProviderContainer containerRespaldo(AppDatabase db, NubeRespaldo? nube, {Restaurador? restaurador})`.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar al final de `test/support/respaldo_prueba.dart` los imports
`import 'package:app_ventas/providers/database_provider.dart';`,
`import 'package:app_ventas/respaldo/respaldo_provider.dart';`,
`import 'package:flutter_riverpod/flutter_riverpod.dart';` (al inicio, con los demás) y la función:

```dart
/// Container con [db] en memoria, la [nube] dada (null = no configurado),
/// un copiador sin I/O y un restaurador falso.
ProviderContainer containerRespaldo(
  AppDatabase db,
  NubeRespaldo? nube, {
  Restaurador? restaurador,
}) {
  return ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    nubeRespaldoProvider.overrideWithValue(nube),
    copiadorProvider
        .overrideWithValue(() async => File('copia_de_prueba.sqlite')),
    restauradorProvider.overrideWithValue(
        restaurador ?? RestauradorFalso(ResultadoRestauracion.restaurado)),
  ]);
}
```

Crear `test/respaldo/respaldo_provider_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });

  tearDown(() => db.close());

  Future<void> vender() => db.into(db.ventas).insert(VentasCompanion.insert(
      monto: 1000, fecha: DateTime.now(), usuarioId: ana));

  // Los containers se cierran al final de cada test (dentro de testWidgets),
  // para que no queden temporizadores pendientes.

  testWidgets('sin configuración la fase es noConfigurado', (tester) async {
    final container = containerRespaldo(db, null);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.noConfigurado);
    container.dispose();
  });

  testWidgets('sin sesión está desactivado y los cambios no suben nada',
      (tester) async {
    final nube = NubeRespaldoFalsa();
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    await vender();
    await tester.pump(const Duration(seconds: 31));

    expect(nube.subidas, 0);
    container.dispose();
  });

  testWidgets('con sesión respalda al abrir', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    final estado = container.read(respaldoProvider);
    expect(nube.subidas, 1);
    expect(estado.fase, FaseRespaldo.activo);
    expect(estado.telefono, '+573001234567');
    expect(estado.ultimoRespaldo, isNotNull);
    container.dispose();
  });

  testWidgets('varios cambios seguidos producen un solo respaldo, 30 s '
      'después del último', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();
    expect(nube.subidas, 1); // el de al abrir

    await vender();
    await tester.pump(const Duration(seconds: 20));
    await vender();
    await tester.pump(const Duration(seconds: 20));
    expect(nube.subidas, 1);

    await tester.pump(const Duration(seconds: 11));
    expect(nube.subidas, 2);
    container.dispose();
  });

  testWidgets('un error de red no cambia la fase y se reintenta en el '
      'siguiente cambio', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = Exception('sin internet');
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    expect(container.read(respaldoProvider).fase, FaseRespaldo.activo);
    expect(container.read(respaldoProvider).ultimoRespaldo, isNull);

    nube.errorAlSubir = null;
    await vender();
    await tester.pump(const Duration(seconds: 31));
    expect(nube.subidas, 1);
    container.dispose();
  });

  testWidgets('una sesión vencida pasa a requiereReconexion', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = const ErrorSesionRespaldo();
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    expect(container.read(respaldoProvider).fase,
        FaseRespaldo.requiereReconexion);
    container.dispose();
  });

  testWidgets('un cambio durante un respaldo programa otro al terminar',
      (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();
    final notifier = container.read(respaldoProvider.notifier);

    final primero = notifier.respaldarAhora();
    final segundo = await notifier.respaldarAhora(); // llega en curso
    await primero;
    expect(segundo, isFalse);
    expect(nube.subidas, 2);

    await tester.pump(const Duration(seconds: 31));
    expect(nube.subidas, 3);
    container.dispose();
  });

  testWidgets('verificar activa la sesión y devuelve el respaldo existente',
      (tester) async {
    final existente = DateTime(2026, 10, 3, 14, 32);
    final nube = NubeRespaldoFalsa(fecha: existente);
    final container = containerRespaldo(db, nube);
    final notifier = container.read(respaldoProvider.notifier);

    final fecha = await notifier.verificar('+573001234567', '123456');

    expect(fecha, existente);
    expect(container.read(respaldoProvider).fase, FaseRespaldo.activo);
    expect(nube.haySesion, isTrue);
    container.dispose();
  });

  testWidgets('desconectar cierra la sesión sin borrar nada', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final container = containerRespaldo(db, nube);
    container.listen(respaldoProvider, (_, _) {});
    await tester.pump();

    await container.read(respaldoProvider.notifier).desconectar();

    expect(container.read(respaldoProvider).fase, FaseRespaldo.desactivado);
    expect(nube.haySesion, isFalse);
    expect(nube.archivoSubido, isNotNull);
    container.dispose();
  });

  testWidgets('restaurar con éxito cierra la sesión local', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true);
    final restaurador = RestauradorFalso(ResultadoRestauracion.restaurado);
    final container = containerRespaldo(db, nube, restaurador: restaurador);
    final usuario = await (db.select(db.usuarios)).getSingle();
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);

    final resultado = await container.read(respaldoProvider.notifier).restaurar();

    expect(resultado, ResultadoRestauracion.restaurado);
    expect(restaurador.llamadas, 1);
    expect(container.read(sesionProvider).haySesion, isFalse);
    container.dispose();
  });
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/respaldo/respaldo_provider_test.dart`
Expected: FAIL — `respaldo_provider.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/respaldo/respaldo_provider.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database.dart';
import '../providers/database_provider.dart';
import '../providers/sesion_provider.dart';
import 'config_respaldo.dart';
import 'copia_base_datos.dart';
import 'nube_respaldo.dart';
import 'restaurador.dart';
import 'supabase_nube_respaldo.dart';

/// Espera tras el último cambio antes de respaldar (varios cambios seguidos
/// producen un solo respaldo).
const retardoRespaldo = Duration(seconds: 30);

enum FaseRespaldo { noConfigurado, desactivado, activo, requiereReconexion }

class EstadoRespaldo {
  const EstadoRespaldo({
    required this.fase,
    this.telefono,
    this.ultimoRespaldo,
    this.respaldando = false,
  });

  final FaseRespaldo fase;
  final String? telefono;
  final DateTime? ultimoRespaldo;
  final bool respaldando;

  EstadoRespaldo copiar({
    FaseRespaldo? fase,
    String? telefono,
    DateTime? ultimoRespaldo,
    bool? respaldando,
  }) {
    return EstadoRespaldo(
      fase: fase ?? this.fase,
      telefono: telefono ?? this.telefono,
      ultimoRespaldo: ultimoRespaldo ?? this.ultimoRespaldo,
      respaldando: respaldando ?? this.respaldando,
    );
  }
}

/// La nube real, o null si la app se compiló sin claves de Supabase.
final nubeRespaldoProvider = Provider<NubeRespaldo?>((ref) {
  if (!ConfigRespaldo.configurado) return null;
  return SupabaseNubeRespaldo(Supabase.instance.client);
});

/// Crea una copia de la base actual lista para subir.
final copiadorProvider = Provider<Future<File> Function()>((ref) {
  final db = ref.watch(databaseProvider);
  return () async => CopiaBaseDatos.crearCopia(db, await getTemporaryDirectory());
});

final restauradorProvider = Provider<Restaurador>((ref) {
  return Restaurador(
    archivoBase: archivoBaseDatos,
    directorioTemporal: getTemporaryDirectory,
  );
});

final respaldoProvider =
    NotifierProvider<RespaldoNotifier, EstadoRespaldo>(RespaldoNotifier.new);

class RespaldoNotifier extends Notifier<EstadoRespaldo> {
  Timer? _temporizador;
  bool _enCurso = false;
  bool _pendiente = false;

  NubeRespaldo? get _nube => ref.read(nubeRespaldoProvider);

  @override
  EstadoRespaldo build() {
    final nube = ref.watch(nubeRespaldoProvider);
    if (nube == null) {
      return const EstadoRespaldo(fase: FaseRespaldo.noConfigurado);
    }
    final cambios =
        ref.watch(databaseProvider).tableUpdates().listen((_) => _programar());
    ref.onDispose(() {
      cambios.cancel();
      _temporizador?.cancel();
    });
    if (!nube.haySesion) {
      return const EstadoRespaldo(fase: FaseRespaldo.desactivado);
    }
    Future.microtask(_alAbrir);
    return EstadoRespaldo(
        fase: FaseRespaldo.activo, telefono: nube.telefonoConectado);
  }

  Future<void> _alAbrir() async {
    try {
      final fecha = await _nube?.fechaUltimoRespaldo();
      if (fecha != null) state = state.copiar(ultimoRespaldo: fecha);
    } on ErrorSesionRespaldo {
      state = state.copiar(fase: FaseRespaldo.requiereReconexion);
      return;
    } catch (_) {
      // Sin internet: el respaldo de abajo también fallará en silencio.
    }
    await respaldarAhora();
  }

  void _programar() {
    if (!(_nube?.haySesion ?? false)) return;
    _temporizador?.cancel();
    _temporizador = Timer(retardoRespaldo, () => respaldarAhora());
  }

  /// Sube una copia de la base. Devuelve true si quedó respaldada. Si ya hay
  /// un respaldo en curso, deja otro programado para cuando termine.
  Future<bool> respaldarAhora() async {
    final nube = _nube;
    if (nube == null || !nube.haySesion) return false;
    if (_enCurso) {
      _pendiente = true;
      return false;
    }
    _enCurso = true;
    state = state.copiar(respaldando: true);
    try {
      final copia = await ref.read(copiadorProvider)();
      await nube.subir(copia);
      state = state.copiar(
        fase: FaseRespaldo.activo,
        telefono: nube.telefonoConectado,
        ultimoRespaldo: DateTime.now(),
        respaldando: false,
      );
      return true;
    } on ErrorSesionRespaldo {
      state = state.copiar(
          fase: FaseRespaldo.requiereReconexion, respaldando: false);
      return false;
    } catch (_) {
      // Sin internet u otro error: se reintenta en el próximo cambio o al
      // abrir la app; no se molesta al usuario.
      state = state.copiar(respaldando: false);
      return false;
    } finally {
      _enCurso = false;
      if (_pendiente) {
        _pendiente = false;
        _programar();
      }
    }
  }

  Future<void> enviarCodigo(String telefonoE164) =>
      _nube!.enviarCodigo(telefonoE164);

  /// Verifica el código y deja la sesión activa. Devuelve la fecha del
  /// respaldo que ya existía para ese número, o null si no hay.
  Future<DateTime?> verificar(String telefonoE164, String codigo) async {
    final nube = _nube!;
    await nube.verificarCodigo(telefonoE164, codigo);
    final fecha = await nube.fechaUltimoRespaldo();
    state = EstadoRespaldo(
      fase: FaseRespaldo.activo,
      telefono: nube.telefonoConectado ?? telefonoE164,
      ultimoRespaldo: fecha,
    );
    return fecha;
  }

  /// Cierra la sesión del respaldo. No borra el respaldo de la nube ni los
  /// datos locales.
  Future<void> desconectar() async {
    _temporizador?.cancel();
    await _nube?.cerrarSesion();
    state = const EstadoRespaldo(fase: FaseRespaldo.desactivado);
  }

  /// Reemplaza la base local con el respaldo. Si lo logra, cierra la sesión
  /// local (vuelve a "¿Quién eres?") y reabre la base.
  Future<ResultadoRestauracion> restaurar() async {
    _temporizador?.cancel();
    final resultado = await ref
        .read(restauradorProvider)
        .restaurar(_nube!, ref.read(databaseProvider));
    if (resultado == ResultadoRestauracion.restaurado) {
      ref.read(sesionProvider.notifier).cerrarSesion();
      ref.invalidate(databaseProvider);
    }
    return resultado;
  }
}
```

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test test/respaldo && flutter analyze`
Expected: PASS y `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/respaldo/respaldo_provider.dart test/respaldo/respaldo_provider_test.dart test/support/respaldo_prueba.dart
git commit -m "Add backup state notifier with debounced automatic uploads"
```

---

### Task 6: Pantalla "Verificar teléfono" (activar y restaurar)

**Files:**
- Create: `lib/screens/respaldo/verificar_telefono_screen.dart`, `lib/screens/respaldo/dialogo_respaldo_existente.dart`
- Test: `test/screens/respaldo/verificar_telefono_screen_test.dart`

**Interfaces:**
- Consumes: `respaldoProvider` (Task 5), `telefonoE164`, `telefonoEnmascarado` (Task 2), `ErrorCodigoRespaldo`, `ResultadoRestauracion`; `BotonPrincipal`, `avisar`; `formatoFechaHora`.
- Produces: `enum ModoVerificacion { activar, restaurar }`; `VerificarTelefonoScreen({required ModoVerificacion modo})`; `enum EleccionRespaldoExistente { restaurar, reemplazar, cancelar }`; `DialogoRespaldoExistente({required DateTime fecha})`. Claves: `campo_telefono`, `boton_enviar_codigo`, `campo_codigo`, `boton_verificar`, `boton_reenviar`, `boton_restaurar_existente`, `boton_reemplazar_existente`, `boton_cancelar_existente`, `boton_confirmar_restaurar`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/screens/respaldo/verificar_telefono_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> abrir(
    WidgetTester tester,
    NubeRespaldoFalsa nube, {
    ModoVerificacion modo = ModoVerificacion.activar,
    RestauradorFalso? restaurador,
  }) async {
    final container = containerRespaldo(db, nube, restaurador: restaurador);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: temaApp(),
        navigatorKey: navegador,
        home: const Scaffold(body: Text('Inicio')),
      ),
    ));
    navegador.currentState!.push(MaterialPageRoute(
        builder: (_) => VerificarTelefonoScreen(modo: modo)));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> enviarYVerificar(WidgetTester tester,
      {String codigo = '123456'}) async {
    await tester.enterText(
        find.byKey(const Key('campo_telefono')), '3001234567');
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo')), codigo);
    await tester.tap(find.byKey(const Key('boton_verificar')));
    await tester.pumpAndSettle();
  }

  testWidgets('un celular inválido muestra error y no envía código',
      (tester) async {
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);

    await tester.enterText(find.byKey(const Key('campo_telefono')), '6011234567');
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un celular de 10 dígitos que empiece por 3'),
        findsOneWidget);
    expect(nube.enviados, isEmpty);
  });

  testWidgets('código incorrecto muestra error; el correcto activa y respalda',
      (tester) async {
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);

    await enviarYVerificar(tester, codigo: '000000');
    expect(nube.enviados, ['+573001234567']);
    expect(find.text('Código incorrecto o vencido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_codigo')), '123456');
    await tester.tap(find.byKey(const Key('boton_verificar')));
    await tester.pumpAndSettle();

    expect(nube.subidas, 1);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Respaldo activado'), findsOneWidget);
  });

  testWidgets('Reenviar código se habilita a los 60 segundos', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());
    await tester.enterText(
        find.byKey(const Key('campo_telefono')), '3001234567');
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();

    TextButton reenviar() =>
        tester.widget<TextButton>(find.byKey(const Key('boton_reenviar')));
    expect(reenviar().onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    expect(reenviar().onPressed, isNotNull);
  });

  testWidgets('con respaldo existente, Cancelar cierra sesión sin subir nada',
      (tester) async {
    final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
    await abrir(tester, nube);

    await enviarYVerificar(tester);
    expect(find.textContaining('03/10/2026 14:32'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_cancelar_existente')));
    await tester.pumpAndSettle();

    expect(nube.subidas, 0);
    expect(nube.haySesion, isFalse);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('con respaldo existente, Reemplazar sube la copia de este '
      'celular', (tester) async {
    final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
    await abrir(tester, nube);

    await enviarYVerificar(tester);
    await tester.tap(find.byKey(const Key('boton_reemplazar_existente')));
    await tester.pumpAndSettle();

    expect(nube.subidas, 1);
    expect(find.text('Respaldo activado'), findsOneWidget);
  });

  testWidgets('con respaldo existente, Restaurar pide confirmación y restaura',
      (tester) async {
    final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
    final restaurador = RestauradorFalso(ResultadoRestauracion.restaurado);
    await abrir(tester, nube, restaurador: restaurador);

    await enviarYVerificar(tester);
    await tester.tap(find.byKey(const Key('boton_restaurar_existente')));
    await tester.pumpAndSettle();
    expect(find.text('Se reemplazarán los datos de este celular'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_confirmar_restaurar')));
    await tester.pumpAndSettle();

    expect(restaurador.llamadas, 1);
    expect(find.text('Respaldo restaurado. Entra con tu PIN.'), findsOneWidget);
  });

  testWidgets('restaurar sin respaldo avisa y vuelve atrás', (tester) async {
    final restaurador = RestauradorFalso(ResultadoRestauracion.sinRespaldo);
    await abrir(tester, NubeRespaldoFalsa(),
        modo: ModoVerificacion.restaurar, restaurador: restaurador);

    await enviarYVerificar(tester);

    expect(find.text('No encontramos un respaldo para este número'),
        findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('restaurar un respaldo dañado muestra el error y no sale',
      (tester) async {
    final restaurador = RestauradorFalso(ResultadoRestauracion.invalido);
    await abrir(tester, NubeRespaldoFalsa(),
        modo: ModoVerificacion.restaurar, restaurador: restaurador);

    await enviarYVerificar(tester);

    expect(
        find.text(
            'El respaldo no se pudo leer; tus datos actuales no se tocaron'),
        findsOneWidget);
    expect(find.byType(VerificarTelefonoScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/screens/respaldo/verificar_telefono_screen_test.dart`
Expected: FAIL — la pantalla no existe.

- [ ] **Step 3: Implementar el diálogo**

Crear `lib/screens/respaldo/dialogo_respaldo_existente.dart`:

```dart
import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../util/fecha_util.dart';

enum EleccionRespaldoExistente { restaurar, reemplazar, cancelar }

/// Pregunta qué hacer cuando el número ya tiene un respaldo en la nube, para
/// no pisar por accidente un respaldo bueno con los datos de este celular.
class DialogoRespaldoExistente extends StatelessWidget {
  const DialogoRespaldoExistente({super.key, required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    void elegir(EleccionRespaldoExistente eleccion) =>
        Navigator.of(context).pop(eleccion);
    return AlertDialog(
      title: const Text('Ya hay un respaldo'),
      content: Text(
        'Ya hay un respaldo de esta tienda del ${formatoFechaHora(fecha)}. '
        '¿Qué quieres hacer?',
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        FilledButton(
          key: const Key('boton_restaurar_existente'),
          onPressed: () => elegir(EleccionRespaldoExistente.restaurar),
          child: const Text('Restaurarlo en este celular'),
        ),
        OutlinedButton(
          key: const Key('boton_reemplazar_existente'),
          onPressed: () => elegir(EleccionRespaldoExistente.reemplazar),
          child: const Text('Reemplazarlo con los datos de este celular'),
        ),
        TextButton(
          key: const Key('boton_cancelar_existente'),
          style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
          onPressed: () => elegir(EleccionRespaldoExistente.cancelar),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implementar la pantalla**

Crear `lib/screens/respaldo/verificar_telefono_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/nube_respaldo.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../respaldo/restaurador.dart';
import '../../respaldo/telefono.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import 'dialogo_respaldo_existente.dart';

enum ModoVerificacion { activar, restaurar }

/// Verifica el celular de la tienda con un código, para activar el respaldo
/// o restaurarlo en este celular.
class VerificarTelefonoScreen extends ConsumerStatefulWidget {
  const VerificarTelefonoScreen({super.key, required this.modo});

  final ModoVerificacion modo;

  @override
  ConsumerState<VerificarTelefonoScreen> createState() =>
      _VerificarTelefonoScreenState();
}

class _VerificarTelefonoScreenState
    extends ConsumerState<VerificarTelefonoScreen> {
  final _telefonoController = TextEditingController();
  final _codigoController = TextEditingController();

  /// Número (E.164) al que se envió el código; null mientras se pide.
  String? _telefono;
  String? _error;
  bool _ocupado = false;
  int _segundosParaReenviar = 0;
  Timer? _cuentaRegresiva;

  RespaldoNotifier get _respaldo => ref.read(respaldoProvider.notifier);

  @override
  void dispose() {
    _cuentaRegresiva?.cancel();
    _telefonoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _iniciarCuentaRegresiva() {
    _cuentaRegresiva?.cancel();
    setState(() => _segundosParaReenviar = 60);
    _cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundosParaReenviar--);
      if (_segundosParaReenviar <= 0) timer.cancel();
    });
  }

  /// Corre [accion] con la pantalla ocupada (evita dobles toques) y traduce
  /// los errores a mensajes.
  Future<void> _ejecutar(Future<void> Function() accion,
      {required String errorGeneral}) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on ErrorCodigoRespaldo {
      if (mounted) setState(() => _error = 'Código incorrecto o vencido');
    } catch (_) {
      if (mounted) setState(() => _error = errorGeneral);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarCodigo() async {
    final telefono = telefonoE164(_telefonoController.text);
    if (telefono == null) {
      setState(
          () => _error = 'Escribe un celular de 10 dígitos que empiece por 3');
      return;
    }
    await _ejecutar(() async {
      await _respaldo.enviarCodigo(telefono);
      if (!mounted) return;
      setState(() => _telefono = telefono);
      _iniciarCuentaRegresiva();
    },
        errorGeneral:
            'No pudimos enviar el código. Revisa el número y tu internet.');
  }

  Future<void> _reenviar() => _ejecutar(() async {
        await _respaldo.enviarCodigo(_telefono!);
        if (mounted) _iniciarCuentaRegresiva();
      }, errorGeneral: 'No pudimos reenviar el código. Revisa tu internet.');

  Future<void> _verificar() async {
    final codigo = _codigoController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'El código tiene 6 dígitos');
      return;
    }
    await _ejecutar(() async {
      final fecha = await _respaldo.verificar(_telefono!, codigo);
      if (!mounted) return;
      if (widget.modo == ModoVerificacion.restaurar) {
        await _restaurar();
      } else {
        await _activar(fecha);
      }
    }, errorGeneral: 'No hay conexión. Revisa tu internet e inténtalo de nuevo.');
  }

  Future<void> _restaurar() async {
    final resultado = await _respaldo.restaurar();
    if (!mounted) return;
    switch (resultado) {
      case ResultadoRestauracion.restaurado:
        avisar(context, 'Respaldo restaurado. Entra con tu PIN.');
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      case ResultadoRestauracion.sinRespaldo:
        avisar(context, 'No encontramos un respaldo para este número');
        Navigator.of(context).pop();
      case ResultadoRestauracion.invalido:
        setState(() => _error =
            'El respaldo no se pudo leer; tus datos actuales no se tocaron');
    }
  }

  Future<void> _activar(DateTime? fechaExistente) async {
    if (fechaExistente == null) return _terminarActivacion();

    final eleccion = await showDialog<EleccionRespaldoExistente>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoRespaldoExistente(fecha: fechaExistente),
    );
    if (!mounted) return;
    switch (eleccion) {
      case EleccionRespaldoExistente.restaurar:
        if (await _confirmarRestauracion()) {
          await _restaurar();
        } else {
          await _cancelarActivacion();
        }
      case EleccionRespaldoExistente.reemplazar:
        await _terminarActivacion();
      case EleccionRespaldoExistente.cancelar:
      case null:
        await _cancelarActivacion();
    }
  }

  Future<bool> _confirmarRestauracion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Restaurar el respaldo?'),
        content: const Text('Se reemplazarán los datos de este celular'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('boton_confirmar_restaurar'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  Future<void> _terminarActivacion() async {
    await _respaldo.respaldarAhora();
    if (!mounted) return;
    avisar(context, 'Respaldo activado');
    Navigator.of(context).pop();
  }

  Future<void> _cancelarActivacion() async {
    await _respaldo.desconectar();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esperandoCodigo = _telefono != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modo == ModoVerificacion.restaurar
            ? 'Restaurar respaldo'
            : 'Activar respaldo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            esperandoCodigo
                ? 'Escribe el código que llegó por SMS al '
                    '${telefonoEnmascarado(_telefono!)}.'
                : 'Escribe el celular de la tienda. Te enviaremos un código '
                    'por SMS.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (!esperandoCodigo)
            TextField(
              key: const Key('campo_telefono'),
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Celular',
                prefixText: '+57 ',
                errorText: _error,
                errorMaxLines: 2,
              ),
            )
          else
            TextField(
              key: const Key('campo_codigo'),
              controller: _codigoController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Código de 6 dígitos',
                errorText: _error,
                errorMaxLines: 2,
              ),
            ),
          const SizedBox(height: 8),
          BotonPrincipal(
            key: Key(esperandoCodigo ? 'boton_verificar' : 'boton_enviar_codigo'),
            texto: esperandoCodigo ? 'Verificar' : 'Enviarme el código',
            onPressed: _ocupado
                ? null
                : (esperandoCodigo ? _verificar : _enviarCodigo),
          ),
          if (esperandoCodigo)
            TextButton(
              key: const Key('boton_reenviar'),
              onPressed:
                  _segundosParaReenviar > 0 || _ocupado ? null : _reenviar,
              child: Text(_segundosParaReenviar > 0
                  ? 'Reenviar código en $_segundosParaReenviar s'
                  : 'Reenviar código'),
            ),
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: CircularProgressIndicator(color: ColoresApp.primario),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr y verificar que pasan**

Run: `flutter test test/screens/respaldo && flutter analyze`
Expected: PASS (8 tests) y `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/respaldo test/screens/respaldo
git commit -m "Add phone verification screen for activating and restoring backups"
```

---

### Task 7: Ajustes → Respaldo

**Files:**
- Create: `lib/screens/respaldo/respaldo_screen.dart`
- Modify: `lib/screens/configuracion/ajustes_screen.dart`
- Test: `test/screens/respaldo/respaldo_screen_test.dart`; agregar una línea a `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `respaldoProvider`, `FaseRespaldo` (Task 5); `VerificarTelefonoScreen` (Task 6); `telefonoEnmascarado`, `textoUltimoRespaldo` (Task 2); `EstadoVacio`, `BotonPrincipal`, `avisar`.
- Produces: `RespaldoScreen()`; claves `boton_activar_respaldo`, `texto_ultimo_respaldo`, `boton_respaldar_ahora`, `boton_desconectar`, `boton_reconectar`, `menu_respaldo`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/screens/respaldo/respaldo_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/screens/respaldo/respaldo_screen.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> abrir(WidgetTester tester, NubeRespaldo? nube) async {
    final container = containerRespaldo(db, nube);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: temaApp(), home: const RespaldoScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sin configuración lo dice', (tester) async {
    await abrir(tester, null);
    expect(find.text('Respaldo no configurado'), findsOneWidget);
  });

  testWidgets('desactivado ofrece activarlo', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());

    await tester.tap(find.byKey(const Key('boton_activar_respaldo')));
    await tester.pumpAndSettle();

    expect(find.byType(VerificarTelefonoScreen), findsOneWidget);
  });

  testWidgets('activo muestra el número, el último respaldo y permite '
      'respaldar y desconectar', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    await abrir(tester, nube);

    expect(find.text('Celular: +57 300 *** 4567'), findsOneWidget);
    expect(find.textContaining('Último respaldo: hoy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_respaldar_ahora')));
    await tester.pumpAndSettle();
    expect(nube.subidas, 2);
    expect(find.text('Respaldo guardado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_desconectar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_activar_respaldo')), findsOneWidget);
  });

  testWidgets('sesión vencida pide reconectar', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = const ErrorSesionRespaldo();
    await abrir(tester, nube);

    expect(find.text('Reconecta el respaldo'), findsOneWidget);
    expect(find.byKey(const Key('boton_reconectar')), findsOneWidget);
  });
}
```

En `test/screens/home/home_screen_test.dart`, dentro del test `'Ajustes tiene Productos, Usuarios y Cerrar sesión'`, después de `expect(find.byKey(const Key('menu_usuarios')), findsOneWidget);` agregar:

```dart
    expect(find.byKey(const Key('menu_respaldo')), findsOneWidget);
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/screens/respaldo/respaldo_screen_test.dart test/screens/home/home_screen_test.dart`
Expected: FAIL — `respaldo_screen.dart` no existe; falta `menu_respaldo`.

- [ ] **Step 3: Implementar la pantalla**

Crear `lib/screens/respaldo/respaldo_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/respaldo_provider.dart';
import '../../respaldo/telefono.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../util/fecha_util.dart';
import 'verificar_telefono_screen.dart';

class RespaldoScreen extends ConsumerWidget {
  const RespaldoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(respaldoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo')),
      body: switch (estado.fase) {
        FaseRespaldo.noConfigurado => const EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'Respaldo no configurado',
            mensaje: 'Esta versión de la app no tiene conexión a la nube.',
          ),
        FaseRespaldo.desactivado => const _Desactivado(),
        FaseRespaldo.activo => _Activo(estado: estado),
        FaseRespaldo.requiereReconexion => const _Reconectar(),
      },
    );
  }
}

void _abrirVerificacion(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) =>
        const VerificarTelefonoScreen(modo: ModoVerificacion.activar),
  ));
}

class _Desactivado extends StatelessWidget {
  const _Desactivado();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const EstadoVacio(
          icono: Icons.cloud_upload_outlined,
          titulo: 'Tus datos solo están en este celular',
          mensaje: 'Activa el respaldo para guardar una copia en la nube y '
              'recuperarla si pierdes o cambias el celular.',
        ),
        BotonPrincipal(
          key: const Key('boton_activar_respaldo'),
          texto: 'Activar respaldo',
          onPressed: () => _abrirVerificacion(context),
        ),
      ],
    );
  }
}

class _Activo extends ConsumerWidget {
  const _Activo({required this.estado});

  final EstadoRespaldo estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(respaldoProvider.notifier);
    final ultimo = estado.ultimoRespaldo;
    final textoEstado = estado.respaldando
        ? 'Respaldando…'
        : ultimo == null
            ? 'Aún no hay respaldo'
            : 'Último respaldo: ${textoUltimoRespaldo(ultimo, DateTime.now())}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: ColoresApp.entra),
                    SizedBox(width: 8),
                    Text('Respaldo activo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(estado.telefono == null
                    ? 'Celular conectado'
                    : 'Celular: ${telefonoEnmascarado(estado.telefono!)}'),
                const SizedBox(height: 4),
                Text(
                  textoEstado,
                  key: const Key('texto_ultimo_respaldo'),
                  style: const TextStyle(color: ColoresApp.textoSecundario),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_respaldar_ahora'),
          texto: 'Respaldar ahora',
          onPressed: estado.respaldando
              ? null
              : () async {
                  final ok = await notifier.respaldarAhora();
                  if (context.mounted) {
                    avisar(context,
                        ok ? 'Respaldo guardado' : 'No se pudo respaldar');
                  }
                },
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          key: const Key('boton_desconectar'),
          texto: 'Desconectar',
          variante: VarianteBoton.peligro,
          onPressed: () => notifier.desconectar(),
        ),
      ],
    );
  }
}

class _Reconectar extends StatelessWidget {
  const _Reconectar();

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.sync_problem_rounded,
      titulo: 'Reconecta el respaldo',
      mensaje: 'La sesión del respaldo venció. Verifica de nuevo el celular '
          'de la tienda.',
      accion: BotonPrincipal(
        key: const Key('boton_reconectar'),
        texto: 'Reconectar',
        onPressed: () => _abrirVerificacion(context),
      ),
    );
  }
}
```

- [ ] **Step 4: Agregar la entrada en Ajustes**

En `lib/screens/configuracion/ajustes_screen.dart`:
1. Agregar el import `import '../respaldo/respaldo_screen.dart';`.
2. Dentro de la `Card` de "TIENDA", después del `ListTile` con clave `menu_usuarios`, agregar:

```dart
              const Divider(height: 1),
              ListTile(
                key: const Key('menu_respaldo'),
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Respaldo'),
                subtitle: const Text('Copia de seguridad en la nube'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RespaldoScreen()),
                ),
              ),
```

- [ ] **Step 5: Correr y verificar que pasan**

Run: `flutter test test/screens/respaldo test/screens/home && flutter analyze`
Expected: PASS y `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/respaldo/respaldo_screen.dart lib/screens/configuracion/ajustes_screen.dart test/screens/respaldo/respaldo_screen_test.dart test/screens/home/home_screen_test.dart
git commit -m "Add backup settings screen"
```

---

### Task 8: Bienvenida y respaldo siempre activo

**Files:**
- Create: `lib/screens/login/bienvenida_screen.dart`
- Modify: `lib/screens/raiz_app.dart`, `lib/screens/login/crear_admin_inicial_screen.dart`
- Test: `test/screens/login/bienvenida_screen_test.dart`; reescribir `test/widget_test.dart`

**Interfaces:**
- Consumes: `respaldoProvider`, `FaseRespaldo`; `VerificarTelefonoScreen`; `CrearAdminInicialScreen`; `MarcaApp`, `BotonPrincipal`.
- Produces: `BienvenidaScreen()`; claves `boton_crear_tienda`, `boton_restaurar_tienda`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/screens/login/bienvenida_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/login/bienvenida_screen.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> abrir(WidgetTester tester, NubeRespaldoFalsa? nube) async {
    final container = containerRespaldo(db, nube);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: temaApp(), home: const BienvenidaScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sin respaldo configurado solo ofrece crear la tienda',
      (tester) async {
    await abrir(tester, null);

    expect(find.byKey(const Key('boton_crear_tienda')), findsOneWidget);
    expect(find.byKey(const Key('boton_restaurar_tienda')), findsNothing);
  });

  testWidgets('con respaldo configurado ofrece restaurar', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());

    await tester.tap(find.byKey(const Key('boton_restaurar_tienda')));
    await tester.pumpAndSettle();

    final pantalla = tester.widget<VerificarTelefonoScreen>(
        find.byType(VerificarTelefonoScreen));
    expect(pantalla.modo, ModoVerificacion.restaurar);
  });
}
```

Reemplazar todo `test/widget_test.dart` por:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primer uso: Bienvenida → crear tienda → entra al Inicio',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const AppVentas(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear tienda nueva'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_crear_tienda')));
    await tester.pumpAndSettle();
    expect(find.text('Configura tu tienda'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Configura tu tienda'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/screens/login/bienvenida_screen_test.dart test/widget_test.dart`
Expected: FAIL — `bienvenida_screen.dart` no existe.

- [ ] **Step 3: Implementar**

Crear `lib/screens/login/bienvenida_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../respaldo/respaldo_provider.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/marca_app.dart';
import '../respaldo/verificar_telefono_screen.dart';
import 'crear_admin_inicial_screen.dart';

/// Primera pantalla cuando el celular no tiene usuarios: crear la tienda o
/// restaurar un respaldo.
class BienvenidaScreen extends ConsumerWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayRespaldo =
        ref.watch(respaldoProvider).fase != FaseRespaldo.noConfigurado;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MarcaApp(),
            const SizedBox(height: 32),
            const Text('Bienvenido',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Registra ventas, fiados y gastos de tu tienda, incluso sin '
              'internet.',
              style: TextStyle(color: ColoresApp.textoSecundario),
            ),
            const SizedBox(height: 32),
            BotonPrincipal(
              key: const Key('boton_crear_tienda'),
              texto: 'Crear tienda nueva',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CrearAdminInicialScreen())),
            ),
            if (hayRespaldo) ...[
              const SizedBox(height: 12),
              BotonPrincipal(
                key: const Key('boton_restaurar_tienda'),
                texto: 'Ya tengo una tienda: restaurar respaldo',
                variante: VarianteBoton.contorno,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VerificarTelefonoScreen(
                        modo: ModoVerificacion.restaurar))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Reemplazar todo `lib/screens/raiz_app.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sesion_provider.dart';
import '../respaldo/respaldo_provider.dart';
import 'home/home_screen.dart';
import 'login/bienvenida_screen.dart';
import 'login/seleccionar_usuario_screen.dart';

class RaizApp extends ConsumerWidget {
  const RaizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el respaldo automático mientras la app está abierta,
    // sin reconstruir esta pantalla en cada cambio de su estado.
    ref.listen(respaldoProvider, (_, _) {});

    final sesion = ref.watch(sesionProvider);
    if (sesion.haySesion) return const HomeScreen();

    final hayUsuariosAsync = ref.watch(haySesionUsuariosProvider);
    return hayUsuariosAsync.when(
      data: (existe) =>
          existe ? const SeleccionarUsuarioScreen() : const BienvenidaScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
```

En `lib/screens/login/crear_admin_inicial_screen.dart`, al final de `_crear()`, después de
`await ref.read(sesionProvider.notifier).iniciarSesion(id, pin);` agregar:

```dart
    // Se abrió desde la Bienvenida: al entrar, quitarla de encima del Inicio.
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
```

- [ ] **Step 4: Correr y verificar que pasan**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` y `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login lib/screens/raiz_app.dart test/screens/login/bienvenida_screen_test.dart test/widget_test.dart
git commit -m "Add welcome screen with restore option and keep backups running"
```

---

### Task 9: Proyecto Supabase, documentación y prueba real

**Requiere al usuario:** crear el proyecto en su cuenta de Supabase y entregar la URL y la *anon key*. El ejecutor se detiene en el Step 1 y pide esos datos.

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-05-app-ventas-fase2bc-respaldo-design.md` (`**Estado:**`)

- [ ] **Step 1: El usuario configura Supabase (en el navegador)**

1. Crear un proyecto en https://supabase.com (plan gratuito).
2. **Authentication → Sign In / Providers → Phone**: habilitarlo. Si el panel exige un proveedor de SMS, elegir Twilio y llenar valores de relleno (con números de prueba no se envía ningún SMS). En **Phone numbers for testing** agregar `573000000001=123456`.
3. **Storage → New bucket**: nombre `respaldos`, **privado** (Public desactivado).
4. **SQL Editor**: ejecutar

```sql
create policy "respaldo propio: leer" on storage.objects for select to authenticated
  using (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "respaldo propio: crear" on storage.objects for insert to authenticated
  with check (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "respaldo propio: actualizar" on storage.objects for update to authenticated
  using (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
```

5. **Project Settings → API**: copiar *Project URL* y *anon public key* y entregarlas al ejecutor (no se guardan en el repo).

- [ ] **Step 2: Documentar**

En `README.md`, reemplazar la sección `## Riesgo conocido: pérdida de datos` completa por:

```markdown
## Respaldo en la nube (opcional)

Sin configuración la app funciona 100% local. Para habilitar el respaldo:

1. Configurar un proyecto Supabase como describe la Task 9 de
   `docs/superpowers/plans/2026-10-05-app-ventas-fase2bc-respaldo.md`
   (login por teléfono, bucket privado `respaldos` y sus políticas RLS).
2. Compilar pasando las claves (nunca se guardan en el repo):

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Con el respaldo activo (Ajustes → Respaldo) la base se sube sola 30 s
después de cada cambio y al abrir la app. En un celular nuevo, la pantalla
de Bienvenida permite restaurarla verificando el mismo número.

**Riesgo restante:** sin respaldo activo, perder el celular es perder los
datos. Los PIN se guardan como SHA-256 sin sal: quien obtenga el archivo de
respaldo podría deducirlos; el acceso al respaldo está limitado al número
de la tienda (RLS).
```

y en la lista de `## Fase 2`, cambiar el ítem de 2B/2C a `(hecho)`. En el spec, cambiar `**Estado:** Borrador para revisión` por `**Estado:** Implementado`.

- [ ] **Step 3: Suite completa**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y `All tests passed!`.

- [ ] **Step 4: Prueba real en el emulador**

```bash
flutter build apk --debug --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

1. Entrar como admin → Ajustes → Respaldo → Activar → celular `3000000001`, código `123456` → "Respaldo activado". En Supabase Storage aparece `respaldos/<uid>/app_ventas.sqlite`.
2. Registrar una venta; esperar 30 s; "Último respaldo" se actualiza (y la fecha del objeto en Storage).
3. `adb shell pm clear com.appventas.app_ventas` → abrir → Bienvenida → "Ya tengo una tienda: restaurar respaldo" → mismo número y código → "Respaldo restaurado" → "¿Quién eres?" con los usuarios → entrar con el PIN → la venta está.
4. Ajustes → Respaldo → Desconectar → vuelve a "Activar respaldo"; el objeto sigue en Storage.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-05-app-ventas-fase2bc-respaldo-design.md
git commit -m "Document cloud backup setup and mark Fase 2B+2C done"
```
