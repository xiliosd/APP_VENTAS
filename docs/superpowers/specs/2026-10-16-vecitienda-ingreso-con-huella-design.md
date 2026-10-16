# VeciTienda — Ingreso rápido con huella

Fecha: 2026-10-16. Mejora 3 de las cuatro pedidas el 2026-10-16 (ver `docs/hoja-de-ruta.md`).
Rama: `feature/ingreso-con-huella`. Aplica los lineamientos UNIMINUTO v1.2.

## Intención

Entrar a la app pide elegir el usuario en "¿Quién eres?" y escribir el PIN. El usuario quiere un
**método de ingreso más corto**, sin quitar el PIN: "el PIN es necesario, pero debería tener un
método de autenticación más rápido".

## Decisiones del usuario

- El PIN se mantiene como forma normal y de respaldo.
- Se agrega la huella (biometría del celular) como atajo.
- Al tocar el usuario sale **el teclado del PIN con un botón de huella** (no se lanza la huella
  sola).

## Metas

- Botón "Entrar con huella" en la pantalla del PIN para quien lo activó.
- Activarlo y desactivarlo por usuario en Ajustes.
- Volver al PIN sin trabas cuando la huella no está disponible o falla.

## No metas

- Quitar o cambiar el PIN, o entrar sin elegir usuario.
- Usar el patrón/PIN del celular como atajo (no prueba que sea el usuario de la app).
- Guardar datos biométricos: la app nunca los ve; solo recuerda qué usuarios activaron la huella.
- iOS (la app es Android).

## Anti-metas

- Que alguien quede sin poder entrar: el PIN funciona siempre.
- Que un botón de huella aparezca y no sirva (sin huellas registradas, sensor ausente).

## Cómo funciona

### Activar (Ajustes)

- En Ajustes, una fila "Entrar con huella" con interruptor para el **usuario con sesión**. Solo
  aparece si el celular tiene biometría disponible y registrada.
- Al encenderlo: aviso "Cualquier huella o rostro registrado en este celular podrá abrir tu usuario.
  Actívalo solo si el celular es tuyo." con "Activar" / "Cancelar"; luego se pide la huella una vez
  para confirmar. Solo si la huella se confirma queda activado. (Ajustado tras la revisión: en muchos
  celulares el desbloqueo facial cuenta como biometría.)
- Apagarlo no pide nada.
- Se guarda en las preferencias del celular (`SharedPreferences`, clave `usuarios_con_huella`, lista
  de ids). No va en la base de datos: la huella es de este celular, y un respaldo restaurado en otro
  celular no debe traerla activada.

### Entrar (pantalla del PIN)

- Si el usuario elegido tiene la huella activada y el celular tiene biometría registrada, bajo el
  teclado aparece el botón "Entrar con huella" (ícono de huella, `tooltip`/`Semantics`).
- Tocarlo abre el diálogo del sistema con el motivo "Confirma que eres <nombre>", solo biometría
  (`biometricOnly: true`).
- Huella correcta → abre sesión como si el PIN fuera correcto (misma navegación).
- Cancelar → no pasa nada, sigue el teclado.
- Bloqueo por intentos (temporal o permanente) → mensaje "Demasiados intentos con la huella: usa tu
  PIN".
- Sin huellas registradas o sin sensor → el botón no se muestra; si se descubre al tocarlo, mensaje
  "Este celular ya no tiene huellas registradas: usa tu PIN".
- El PIN se puede escribir en cualquier momento, con o sin huella.

### Limpieza y seguridad (*decisiones mías*)

- La app hoy no permite eliminar ni desactivar usuarios, así que no hay ese evento: al leer la lista
  se ignoran (y se quitan) los ids que ya no existen en la base.
- Al **restaurar un respaldo** (Ajustes → Respaldo) se borra `usuarios_con_huella`: la base nueva
  puede traer otras personas con los mismos ids, y la huella abriría a otra persona. Cada quien la
  vuelve a activar.
- La copia automática de Android (Auto Backup) puede devolver las preferencias al reinstalar o al
  pasar a otro celular de la misma cuenta de Google; se acepta, porque es la misma persona y el
  celular nuevo solo abre con sus propias huellas. No se cambian las reglas de copia de la app.
- Si alguien registra una huella nueva en el celular, la activación sigue valiendo: detectarlo
  exige código nativo que `local_auth` no ofrece. Lo cubre el aviso al activar.

## Técnica

- Paquetes verificados en pub.dev el 2026-10-16, versiones fijas:
  - `local_auth: 3.0.2` (flutter.dev verificado, publicado hace 3 meses, Dart ≥ 3.10).
  - `local_auth_android: 2.2.0` fijado a propósito (29 días; la 2.3.0 tiene 2 días), como ya se
    hizo con `image_picker_android`.
- Android: `MainActivity` pasa a `FlutterFragmentActivity`; permiso
  `android.permission.USE_BIOMETRIC` en el manifiesto; el `LaunchTheme` (en `values`,
  `values-night`, `values-v31` y `values-night-v31`) hereda de un tema `Theme.AppCompat` (requisito
  del paquete para no fallar en Android 8 o anterior), conservando el fondo y los atributos de la
  pantalla de carga de la mejora 2. Si hace falta la librería `androidx.appcompat`, se agrega con
  versión fija.
- El acceso a `local_auth` va detrás de una interfaz propia en `lib/servicios/` con su provider,
  para que las pruebas usen un doble (como `consultaProductoProvider`).

## Pruebas

- Servicio: disponible solo con biometría registrada; traducción de errores (cancelado, bloqueo,
  sin huellas).
- Preferencia: activar, desactivar, ignorar ids que ya no existen, borrar todo al restaurar un
  respaldo.
- Ajustes: la fila solo con biometría; aviso y confirmación con huella; cancelar no activa.
- PIN: botón solo si el usuario la activó y hay biometría; huella correcta abre sesión; cancelar no
  hace nada; bloqueo muestra el mensaje; el PIN sigue funcionando.
- Modo oscuro y letra 2,0× en la pantalla del PIN y en Ajustes; `Semantics` en el botón.
- Recursos de Android: `FlutterFragmentActivity`, permiso y temas AppCompat.

## Queda al criterio de quien lo construya

- Ícono exacto y ubicación fina del botón bajo el teclado.
- Nombres del servicio y del provider.
