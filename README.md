# VeciTienda

*La tranquilidad de tu tienda, en tu bolsillo.*

## Nombre y descripción

VeciTienda es una app Android que funciona sin conexión, para tenderos y vendedores
informales en Colombia. Sirve para:

- registrar ventas rápido, con búsqueda, escáner de código de barras o voz;
- llevar el fiado (crédito a clientes) con abonos y extracto;
- anotar gastos;
- manejar inventario, proveedores y pedidos sugeridos;
- ver reportes por día, semana y mes;
- cobrar por QR (Nequi, Daviplata o banco).

Cada persona entra con un PIN de 4 dígitos o con su huella. Los datos viven en un archivo
SQLite en el celular. El respaldo en la nube con Supabase es opcional.

### Arquitectura

```
UI (screens, Material 3)
   ↓
Riverpod providers (estado)
   ↓
Repositorios (uno por entidad)
   ↓
Drift / SQLite (persistencia local, única fuente de verdad)
```

- `lib/data/` — esquema Drift (`AppDatabase`), tablas y migraciones.
  Cada fila que se sincronizará tiene, además de su `id` local, un `id_global` (UUID v4);
  los `id` locales nunca salen del celular y la tienda compartida usa `id_global`.
- `lib/repositories/` — una clase por entidad que envuelve las consultas Drift
  (patrón Repository).
- `lib/providers/` — providers de Riverpod que conectan la base, los repositorios y la
  sesión con la UI.
- `lib/screens/` — pantallas organizadas por flujo (login, venta, fiado, gasto, historial,
  reportes, inventario, configuración, escáner…).
- `lib/ui/` — componentes visuales reutilizables (tema, colores, mosaicos, avisos,
  recorrido de primer uso, vibración).
- `lib/respaldo/` — respaldo y restauración con Supabase.
- `lib/util/` — moneda (COP entero), hash de PIN y fechas.

### Excepciones a los lineamientos

- **Nombres de Dart:** los archivos van en `snake_case` y las constantes en
  `lowerCamelCase`, como piden la convención oficial de Dart y `flutter analyze`. Los
  lineamientos UNIMINUTO piden kebab-case y SCREAMING_SNAKE_CASE.
- **Proyecto personal:** no lleva contenedor Docker. El trabajo se hace directamente en
  `master`, sin ramas `develop`, `QA` ni `feature/...`.

## Enlaces de documentación

- Hoja de ruta y estado: [`docs/hoja-de-ruta.md`](docs/hoja-de-ruta.md).
- Especificaciones de cada fase: [`docs/superpowers/specs/`](docs/superpowers/specs/).
- Planes de implementación: [`docs/superpowers/plans/`](docs/superpowers/plans/).
- Marca: [`docs/marca/vecitienda-marca.md`](docs/marca/vecitienda-marca.md).

## Referencias de API

No aplica: la app no expone ninguna API. Usa estos servicios externos, ambos opcionales:

- **Supabase** (respaldo): inicio de sesión por correo con código de un solo uso y un bucket
  privado `respaldos` con políticas RLS (cada tienda solo ve su carpeta). En el proyecto:
  proveedor Email activo, plantillas "Confirm signup" (primera vez) y "Magic Link" con
  `{{ .Token }}` para que llegue el código en vez de un enlace,
  bucket `respaldos` privado y las políticas de la Task 9 de
  `docs/superpowers/plans/2026-10-05-app-ventas-fase2bc-respaldo.md`. Para uso real hace falta un
  SMTP propio: el correo por defecto de Supabase envía pocos mensajes por hora.
- **Open Food Facts** (consulta pública, sin clave): al escanear un código desconocido,
  autocompleta el nombre, la marca y el tamaño del producto.

## Autores

- Oscar Dueñas — dueño del producto y desarrollador.
- Desarrollo asistido por Claude (Anthropic). Los commits lo registran con `Co-Authored-By`.

## Distintivos

No aplica: el repositorio todavía no tiene integración continua ni insignias publicadas.

## Ambiente de pruebas

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

El segundo comando genera el código de Drift (`*.g.dart`). Esos archivos están en
`.gitignore`, así que hay que regenerarlos en cada clon nuevo. Las pruebas de
repositorios, providers y widgets usan una base Drift en memoria
(`NativeDatabase.memory()`), no una base real ni mocks. Para revisar a mano, la app trae
una "venta de práctica" en el recorrido de primer uso que no guarda nada.

## Deployment

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

El APK queda en `build/app/outputs/flutter-apk/`. No se guarda en git porque es un
artefacto de compilación. Todavía no se publica en Play Store.

El identificador de la app es `com.vecitienda.app`. El APK release se firma con la llave propia
`android/vecitienda.jks`, configurada en `android/key.properties` (plantilla en
`android/key.properties.example`); los dos archivos están fuera de git y hay que guardar una
copia aparte, porque sin ellos no se puede actualizar la app instalada. Si `key.properties` no
existe, la compilación usa la llave de depuración y lo avisa. Para revisar la firma:
`apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`.

## Environment variables

Se pasan al compilar con `--dart-define` y nunca se guardan en el repositorio. Sin ellas,
la app funciona 100 % local y el respaldo queda deshabilitado.

| Variable | Uso |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase para el respaldo. |
| `SUPABASE_ANON_KEY` | Llave pública (publishable o anon) del proyecto Supabase. |

Lo más cómodo es copiar `dart_defines.example.json` como `dart_defines.json` (ignorado por git),
llenar los valores y compilar con:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

También se pueden pasar sueltas:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=<llave>
```

Con el respaldo activo (Ajustes → Respaldo), la base se sube sola 30 s después de cada
cambio y al abrir la app. En un celular nuevo, la pantalla de Bienvenida permite
restaurarla verificando el mismo número.

**Riesgo restante:** sin respaldo activo, perder el celular es perder los datos. Los PIN se
guardan como SHA-256 sin sal, así que quien obtenga el archivo de respaldo podría
deducirlos. El acceso al respaldo está limitado al número de la tienda por RLS.

## Screenshots

Todavía no hay capturas en el repositorio. El logo y la marca están en
[`docs/marca/`](docs/marca/).

## Tech stack

- Flutter y Dart 3, Material 3, solo Android.
- Estado: Riverpod 2.
- Datos: Drift sobre SQLite (`sqlite3_flutter_libs`).
- Respaldo: `supabase_flutter`.
- Cámara y códigos: `mobile_scanner`.
- Huella: `local_auth`.
- Imágenes del QR: `image_picker`.
- Dictado: reconocimiento de voz nativo de Android (`DictadoLocal.kt`).
- Preferencias por celular: `shared_preferences`.
- Calidad: `flutter_lints`, `dart format`, `flutter analyze` y `flutter test`.

## Usage/examples

- **Vender:** Inicio → "Nueva venta". Se buscan productos, se escanea el código o se dicta
  ("2 cocas y un pan"). Luego "Cobrar", y en "¿Cómo paga?" se elige efectivo,
  transferencia (QR) o fiado.
- **Fiado:** pestaña Fiado → cliente → "Registrar abono". "Ver extracto" muestra cada
  compra y cada abono con el saldo.
- **Inventario:** pestaña Inventario. Tiene "Recibir mercancía", "Ajustar conteo" y "Por
  pedir", que arma el pedido sugerido por proveedor.
- **Consultar precio:** en el Inicio, "Consultar precio" abre el escáner y muestra el precio del
  producto sin tocar la venta. Si el código no está, ofrece "Agregar producto".
- **Preguntas frecuentes:** desde el menú de cuenta del Inicio (todos) o Ajustes → AYUDA.
- **Escáner en el recorrido de primer uso:** en "Tus primeros productos", "Crear
  escaneando" lee un código y crea el producto con la hoja rápida. En la venta de
  práctica, "Vender escaneando" abre el escáner (con "Seguir sin cámara") y la guía sigue
  desde Cobrar.
