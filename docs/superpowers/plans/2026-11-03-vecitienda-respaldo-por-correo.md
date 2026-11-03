# Respaldo en la nube por correo — plan

**Decisión del usuario (2026-11-03):** el ingreso al respaldo pasa de código por SMS a código por
correo, porque el SMS exige un proveedor pago (Twilio) y el proyecto de Supabase solo tiene el
correo activo. Se reemplaza el teléfono por completo; no se conservan las dos opciones.

**Supabase:** `signInWithOtp(email: ..., shouldCreateUser: true)` y
`verifyOTP(email: ..., token: ..., type: OtpType.email)`. La plantilla "Magic Link" del proyecto
debe incluir `{{ .Token }}` para que llegue el código (lo configura el usuario). La longitud del
código es configurable en Supabase (6 por defecto, puede ser 8): la pantalla acepta de 6 a 8
dígitos.

## Tarea 1 — interfaz, implementación y estado

- `lib/respaldo/nube_respaldo.dart`: `telefonoConectado` → `correoConectado`;
  `enviarCodigo(String correo)`; `verificarCodigo(String correo, String codigo)`.
- `lib/respaldo/supabase_nube_respaldo.dart`: usar `email` y `OtpType.email`; `correoConectado`
  desde `currentUser?.email`. Mantener el manejo de `AuthRetryableFetchException`.
- `lib/respaldo/telefono.dart` → `lib/respaldo/correo.dart`: `correoNormalizado(String)` (recorta,
  minúsculas, valida forma básica `algo@dominio.tld` sin espacios; null si no es válido) y
  `correoEnmascarado(String)` (`os***@gmail.com`: dos primeras letras del usuario, o una si es
  corto). Borrar `telefono.dart` y su prueba si ya nada los usa.
- `lib/respaldo/respaldo_provider.dart`: campo `telefono` → `correo` en el estado y en
  `enviarCodigo` / `verificar`.
- `test/support/respaldo_prueba.dart` y `test/respaldo/*`: actualizar el doble de prueba y las
  pruebas; pruebas nuevas para `correoNormalizado` y `correoEnmascarado` (casos límite:
  mayúsculas, espacios, sin arroba, sin dominio, usuario de una letra).

## Tarea 2 — pantallas y textos

- `lib/screens/respaldo/verificar_telefono_screen.dart` → `verificar_correo_screen.dart`
  (`VerificarCorreoScreen`): campo de correo con teclado de correo, `autofillHints` de correo,
  "Enviarme el código", aviso "Revisa tu correo (también la carpeta de spam)", campo del código
  de 6 a 8 dígitos, mismos estados de error, reenvío y modos que hoy. Accesibilidad igual que la
  pantalla actual (etiquetas, `Semantics`, foco).
- `respaldo_screen.dart`: "Correo: os***@gmail.com" en vez del celular; mensaje de sesión vencida
  "Verifica de nuevo tu correo".
- `bienvenida_screen.dart`: abrir la pantalla nueva.
- `lib/screens/ayuda/preguntas_frecuentes.dart`: las respuestas del respaldo y del cambio de
  celular hablan del correo y del código que llega al correo (no SMS).
- Pruebas de pantalla renombradas y actualizadas.

## Cierre

- `flutter analyze` limpio, `dart format` solo en archivos tocados, suite completa verde.
- README: la sección de APIs dice "inicio de sesión por correo con código" y los pasos de
  Supabase (Email activo, plantilla con `{{ .Token }}`, bucket privado `respaldos`, políticas RLS).
- Hoja de ruta: claves de Supabase hechas; pendiente probar con el proyecto real y SMTP propio
  para uso real (el correo por defecto de Supabase tiene límite bajo de envíos por hora).
