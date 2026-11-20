# Agregar un celular fácil (asistente + QR) — diseño

Fecha: 2026-11-20 · Tamaño: proyecto (diseño completo)

## Por qué

Los dueños de tienda no saben cómo empezar a unir más celulares. Hoy el camino exige saber
de memoria que hay que pasar por **Respaldo** (verificar correo con código y "Compartir
tienda"), luego **Usuarios** (crear al vendedor con número y PIN) y luego **Celulares de la
tienda** (ver el código y dictarlo). Ninguna pantalla lleva a la siguiente, y "Celulares de la
tienda" sin tienda compartida solo muestra un error. En el celular del vendedor, el **número
de vendedor** no se distingue y la persona se enreda al escribir los tres datos.

Usuarios objetivo: dueños y vendedores de tienda de barrio que no manejan bien aplicaciones.

## Metas

1. Un botón visible **"Agregar un celular"** que lleve al dueño de principio a fin sin saber
   nada de respaldo, compartir ni códigos.
2. El vendedor se une **escaneando un QR** en el celular del dueño y escribiendo solo su PIN.
3. Si el QR falla, escribir los datos a mano sigue funcionando y es claro cuál es cuál.

## No metas

- No cambia la seguridad: el dueño sigue aprobando cada celular y el PIN sigue validándose en
  la nube (`solicitar_ingreso`, límite de intentos).
- No cambia el servidor de correo (SMTP propio y plantilla en español siguen como pendiente
  aparte de la hoja de ruta).
- Nada por WhatsApp (descartado por el usuario).
- No hay migración Supabase: el QR solo transporta datos que hoy se dictan.

## Anti-metas

- Que el PIN viaje en el QR o quede visible en una foto del QR.
- Que el asistente deje a medias una tienda compartida o un usuario sin PIN en la nube.

## Enfoques considerados

- A. Asistente + tarjeta clara con los tres datos (sin dependencias nuevas). El vendedor sigue
  escribiendo tres datos.
- **B. A + QR — ELEGIDO.** El vendedor escanea y solo escribe el PIN. Leer QR: `mobile_scanner`
  7.4.2 (ya está). Dibujar QR: dependencia nueva `qr_flutter`, verificada en pub.dev y fijada.
- C. Enviar datos por WhatsApp: descartado.

## Diseño

### Celular del dueño: asistente "Agregar un celular"

Entradas: Ajustes (opción visible en la sección TIENDA, arriba de "Celulares de la tienda") y
botón principal dentro de "Celulares de la tienda". "Celulares de la tienda" sin tienda
compartida deja de mostrar error y ofrece el asistente.

Pasos (se salta cada paso ya cumplido):

1. **Confirmar tu correo** — explica en una línea por qué ("para que los celulares compartan
   las ventas"), reutiliza el flujo de `verificar_correo_screen.dart` (correo → código) y al
   terminar comparte la tienda sola (`compartirTienda()`), sin el diálogo aparte de Respaldo.
2. **¿Quién va a usar el celular?** — lista los vendedores activos que aún no tienen celular
   aprobado, más "Otra persona" que crea un vendedor ahí mismo (nombre + PIN, misma lógica que
   `usuarios_screen.dart`, incluido guardar el PIN en la nube antes de crear).
3. **Muéstrale esto al vendedor** — pantalla grande con:
   - el QR (contenido: código de tienda + número de vendedor, nunca el PIN);
   - debajo, "¿No funciona la cámara?" con **Código de la tienda**, **Número de vendedor** y
     un recordatorio "su PIN es el que le diste" (el PIN no se muestra), letra grande y
     etiquetas iguales a las del celular del vendedor;
   - el estado en vivo: "Esperando que <nombre> escanee…" → cuando llega su solicitud, botón
     **Aprobar** ahí mismo (en lugar de solo el aviso global de `AtenderSolicitudes`) →
     "¡Listo! <nombre> ya puede vender desde su celular".

**Cambiar su celular (decisión del usuario):** en el paso 2 también aparecen los vendedores
que ya tienen celular aprobado, con la etiqueta "Cambiar su celular". Al aprobar en el paso 3
el celular nuevo de ese vendedor, el asistente le quita el acceso al celular anterior
(`revocar_celular` sobre la membresía aprobada con el mismo `usuario_id_global`); ese celular
entrega lo pendiente y se vacía como hoy. El aviso lo dice antes de aprobar: "Su celular
anterior dejará de tener los datos de la tienda".

**Soy yo, en otro celular (decisión del usuario):** el paso 2 tiene la opción "Soy yo, en otro
celular". El dueño entra con su correo, no con QR (su cuenta es la del correo y la nube ya lo
reconoce como administrador), así que el asistente muestra en letra grande los pasos para el
celular nuevo: instalar la app → "Ya tengo una tienda" → escribir **este correo** (se muestra) →
código que llega al correo. No hay QR ni aprobación en este camino. En la Bienvenida, el botón
"Ya tengo una tienda: restaurar respaldo" pasa a decir "Ya tengo una tienda (soy el dueño)".

Si el dueño elige un vendedor creado antes de la tienda compartida (sin PIN en la nube), el
asistente lo resuelve como hoy lo hace `pines_faltantes` / `guardar_pin_legado`.

### Celular del vendedor: "Unirme a una tienda"

- Botón principal **"Escanear el código del dueño"** abre la cámara (QR). Al leerlo, muestra
  "Tienda encontrada · Eres el vendedor N.º X" y pide solo el **PIN de 4 dígitos**.
- Enlace secundario "Escribir los datos a mano" con los tres campos de hoy, con las mismas
  etiquetas que la tarjeta del dueño, el número de vendedor destacado y un ejemplo de formato
  en cada campo.
- Un QR que no es de VeciTienda o está mal formado da un mensaje claro ("Ese código no es de
  una tienda VeciTienda") y deja volver a escanear.
- Errores de PIN / intentos: los mensajes actuales.

### Formato del QR

Texto con prefijo propio y versión, p. ej. `vecitienda:unirse:1:<CODIGO>:<NUMERO>`; el lector
valida prefijo, versión, código (6 caracteres del alfabeto de `_codigo_tienda_nuevo`) y número
entero positivo. El formato exacto es decisión del constructor mientras cumpla eso.

## Decisiones mías (corregibles)

- La aprobación sigue siendo obligatoria, pero se hace dentro del asistente, en la misma
  pantalla del QR, para que el dueño no tenga que buscarla.
- El PIN nunca se muestra en el QR ni en la tarjeta; el vendedor lo recibe de palabra.
- Respaldo conserva su botón "Compartir tienda" para quien ya lo conoce.
- Preguntas frecuentes y el recorrido: el tema "unir celulares" pasa a explicar el asistente.
- Paso 1 solo se salta el diálogo de "Compartir tienda" en el caso normal. Si el correo ya
  tiene una tienda compartida (`TiendaCompartidaExistente`) o un respaldo que reemplazaría
  datos, el asistente muestra las mismas confirmaciones de hoy: nunca se borran datos sin
  aviso.
- La hoja `conectarCelularVendedor` de Usuarios se reemplaza: el botón del celular abre el
  asistente directo en el paso 3 con ese vendedor (un solo camino, mismas etiquetas).
- Mientras el paso 3 está abierto se consulta la solicitud más seguido y el aviso global de
  `AtenderSolicitudes` no se muestra encima (la aprobación está en la misma pantalla).

## Para quien construye

Accesibilidad WCAG 2.1 AA: el QR con `Semantics` que diga para qué es, botones con texto,
contraste y letra grande (la app ya soporta escala de texto). Pruebas: parser del QR (casos
límite), widget del asistente (saltar pasos ya cumplidos, sin internet, correo sin código,
vendedor existente vs. nuevo), widget de Unirme (escaneo válido, inválido, a mano). La prueba
con dos celulares reales queda para el paso de prueba en celular de la hoja de ruta.
