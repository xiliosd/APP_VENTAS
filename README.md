# VeciTienda

*La tranquilidad de tu tienda, en tu bolsillo.*

App móvil offline (Android) para tenderos y vendedores informales en Colombia:
registro rápido de ventas, fiado (crédito a clientes) con cobro parcial, gastos,
y resumen diario general y por vendedor. Login por PIN de 4 dígitos, sin
cuentas ni servidor — todos los datos viven en un archivo SQLite local en el
dispositivo.

Fase 1 (este repo) es el núcleo funcional descrito en
`docs/superpowers/specs/2026-09-02-app-ventas-fase1-design.md`. El plan de
implementación ejecutado está en
`docs/superpowers/plans/2026-09-02-app-ventas-fase1.md`.

## Arquitectura

```
UI (screens, Material)
   ↓
Riverpod providers (estado)
   ↓
Repositorios (uno por entidad)
   ↓
Drift / SQLite (persistencia local, única fuente de verdad)
```

- **`lib/data/`** — esquema Drift (`AppDatabase`) y tablas.
- **`lib/repositories/`** — una clase por entidad (Usuario, Producto, Cliente,
  Venta, Fiado, Gasto, Resumen), cada una envolviendo consultas Drift.
- **`lib/providers/`** — providers de Riverpod que conectan la base de datos,
  los repositorios y el estado de sesión con la UI.
- **`lib/screens/`** — pantallas Material, organizadas por flujo
  (`login/`, `venta/`, `fiado/`, `gasto/`, `historial/`, `home/`,
  `configuracion/`).
- **`lib/util/`** — formateo de moneda (COP entero, sin decimales), hash de
  PIN (SHA-256) y utilidades de fecha.

No hay llamadas de red en ninguna parte de esta fase: la app funciona 100%
sin conexión.

## Configuración inicial

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

El segundo comando genera `lib/data/database.g.dart` (código Drift), que
está en `.gitignore` porque es derivado del esquema — hay que regenerarlo en
cada clon nuevo antes de compilar o correr los tests.

## Correr los tests

```bash
flutter test
```

Los tests de repositorios/providers/widgets usan una base de datos Drift en
memoria (`NativeDatabase.memory()`), no una base real ni mocks.

## Compilar

```bash
flutter build apk --debug
```

Genera `build/app/outputs/flutter-apk/app-debug.apk` (no está en git — es un
artefacto de build). Para instalarlo en un emulador o dispositivo conectado:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Respaldo en la nube (opcional)

Sin configuración la app funciona 100% local. Para habilitar el respaldo:

1. Configurar un proyecto Supabase como describe la Task 9 de
   `docs/superpowers/plans/2026-10-05-app-ventas-fase2bc-respaldo.md`
   (login por teléfono, bucket privado `respaldos` y sus políticas RLS).
2. Compilar pasando las claves (nunca se guardan en el repo):

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable o anon key>
```

Con el respaldo activo (Ajustes → Respaldo) la base se sube sola 30 s
después de cada cambio y al abrir la app. En un celular nuevo, la pantalla
de Bienvenida permite restaurarla verificando el mismo número.

**Riesgo restante:** sin respaldo activo, perder el celular es perder los
datos. Los PIN se guardan como SHA-256 sin sal: quien obtenga el archivo de
respaldo podría deducirlos; el acceso al respaldo está limitado al número
de la tienda (RLS).

## Fase 2

La Fase 2 se divide en subproyectos, cada uno con su spec y plan en `docs/superpowers/`:

- **2A — Pantallas pendientes de la Fase 1** (hecho): resetear PIN y varios
  administradores, editar/reactivar productos, historial y saldo vivo del
  cliente con fiado, resumen por día, historial por día y usuario con gastos.
- **2E — Experiencia de usuario y diseño visual** (hecho): sistema visual
  "claro y confiable" (`lib/ui/`), venta tipo ticket con "Cobrar" y Deshacer,
  Inicio con tarjetas de ventas/gastos/ganancia/por cobrar, avisos de
  confirmación y estados vacíos en todas las pantallas.
- **2B/2C — Respaldo en la nube (Supabase) e identidad de la tienda por OTP**
  (hecho; requiere configurar Supabase, ver arriba).
- **Marca VeciTienda** (hecho): nombre, isotipo e íconos Android
  (`tool/generar_iconos.py` los regenera desde `docs/marca/`), paleta azul
  cobalto + verde esmeralda con contraste AA, títulos en Nunito.
- **2D — Cobro digital por QR (Bre-B / Nequi / Daviplata)** (pendiente).

Fuera de alcance por ahora: editar o anular ventas, abonos o gastos ya
registrados; eliminar usuarios o cambiar su rol; rangos de fechas
(semana/mes) y reportes exportables.
