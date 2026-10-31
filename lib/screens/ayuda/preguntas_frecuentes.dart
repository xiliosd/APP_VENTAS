/// Una pregunta con su respuesta corta, en pasos.
class PreguntaFrecuente {
  const PreguntaFrecuente(this.pregunta, this.respuesta);

  final String pregunta;
  final String respuesta;
}

/// Un tema de la ayuda con sus preguntas.
class TemaAyuda {
  const TemaAyuda(this.titulo, this.preguntas);

  final String titulo;
  final List<PreguntaFrecuente> preguntas;
}

/// Prefijo de las respuestas que solo aplican a quien administra la tienda.
const _soloAdmin = 'Solo el administrador: ';

/// Ayuda sin internet sobre toda la app. Cada respuesta describe lo que la
/// app hace hoy, con los nombres de botones tal como se ven en pantalla: si
/// cambia una pantalla, hay que revisar aquí también.
const temasAyuda = <TemaAyuda>[
  TemaAyuda('Ventas', [
    PreguntaFrecuente(
      '¿Cómo registro una venta?',
      '1. En el Inicio toca "+ Venta".\n'
          '2. Toca cada producto una vez por cada unidad que lleva. Para algo '
          'que no está en la lista usa "+ Otro" o los "MONTOS RÁPIDOS".\n'
          '3. Toca "Cobrar" y elige "Efectivo", "Transferencia (mostrar QR)" '
          'o "Fiado".',
    ),
    PreguntaFrecuente(
      '¿Cómo quito algo que agregué por error?',
      '1. En el producto toca el botón − que aparece arriba a la izquierda '
          '(cuando queda uno, es una caneca).\n'
          '2. O toca "Ver ticket" y usa los botones para quitar uno, agregar '
          'uno o quitarlo del ticket.\n'
          '3. "Vaciar" borra todo el ticket.',
    ),
    PreguntaFrecuente(
      '¿Cómo vendo con el código de barras?',
      '1. En "Nueva venta" toca "Escanear código" y apunta la cámara al '
          'código.\n'
          '2. Si el producto ya está, se suma al ticket.\n'
          '3. Si no está, se abre "Nuevo producto": escribe el nombre y el '
          'precio y toca "Guardar y agregar".\n'
          'Si la cámara no lo lee, toca "Escribir código".',
    ),
    PreguntaFrecuente(
      '¿Cómo vendo por voz?',
      '1. Toca el micrófono del Inicio o el de "Nueva venta".\n'
          '2. Di lo que lleva, por ejemplo: "dos gaseosas y un pan", y toca '
          '"Listo".\n'
          '3. Revisa la hoja "¿Agrego esto?" y toca "Agregar al ticket".\n'
          'El dictado funciona sin internet: si la app te lo pide, descarga '
          'el español sin conexión en los ajustes de voz de Google del '
          'celular. En algunos celulares no se puede dictar sin internet y la '
          'app te avisa.',
    ),
    PreguntaFrecuente(
      '¿Cómo cobro por transferencia con mi QR?',
      '1. Al cobrar, elige "Transferencia (mostrar QR)".\n'
          '2. El cliente escanea tu QR y digita el valor que sale en '
          'pantalla.\n'
          '3. Cuando veas que te llegó la plata, toca "Recibido".\n'
          'El QR lo carga el administrador en Ajustes → "Cobro por QR".',
    ),
    PreguntaFrecuente(
      'Me equivoqué en una venta, ¿cómo la arreglo?',
      '1. Justo después de cobrar, toca "Deshacer" en el aviso de abajo.\n'
          '2. Después, ve a "Historial", toca la venta y elige "Corregir" o '
          '"Anular".\n'
          'El vendedor solo corrige sus propias ventas del mismo día; el '
          'administrador puede corregir cualquiera.',
    ),
    PreguntaFrecuente(
      '¿Puedo practicar una venta sin que cuente?',
      '${_soloAdmin}en "Ajustes" toca "Ver el recorrido otra vez". Haces una '
          'venta de práctica que no se guarda en tus cuentas y luego ves la '
          'guía del Inicio.',
    ),
  ]),
  TemaAyuda('Fiado y clientes', [
    PreguntaFrecuente(
      '¿Cómo fío una venta?',
      '1. Arma la venta como siempre y toca "Cobrar".\n'
          '2. Toca "Fiado".\n'
          '3. Escribe el nombre del cliente y tócalo en la lista. Si es '
          'nuevo, toca "Nuevo: …" (con el nombre que escribiste), llena sus '
          'datos y toca "Continuar".\n'
          '4. Toca "Fiar".',
    ),
    PreguntaFrecuente(
      '¿Cómo registro un abono?',
      '1. Ve a la pestaña "Fiado" y toca el cliente.\n'
          '2. Toca "Registrar abono".\n'
          '3. Elige "Efectivo" o "Transferencia" y escribe el valor, o toca '
          '"Todo" o "Mitad".\n'
          '4. Toca "Registrar abono".\n'
          'El abono no puede ser mayor que lo que debe.',
    ),
    PreguntaFrecuente(
      '¿Cómo sé quién me debe y desde cuándo?',
      'En la pestaña "Fiado" ves cuánto te deben en total y cada cliente con '
          'su deuda y desde cuándo debe. Ordénalos con "Mayor deuda" o "Más '
          'antigua". Quienes ya pagaron quedan en "Al día".',
    ),
    PreguntaFrecuente(
      '¿Cómo le muestro a un cliente su cuenta?',
      '1. Pestaña "Fiado" → toca el cliente.\n'
          '2. Toca "Ver extracto".\n'
          'Ahí salen sus compras fiadas con detalle, sus abonos y el saldo '
          'actual, para que se lo muestres en la pantalla.',
    ),
    PreguntaFrecuente(
      '¿Cómo corrijo un abono o una venta fiada?',
      '1. Pestaña "Fiado" → toca el cliente (si ya pagó, está en "Al '
          'día").\n'
          '2. Toca el movimiento en la lista.\n'
          '3. Elige "Corregir" o "Anular".\n'
          'El vendedor solo corrige lo suyo del mismo día.',
    ),
    PreguntaFrecuente(
      '¿Cómo agrego o cambio los datos de un cliente?',
      '1. Pestaña "Fiado" → "Todos los clientes".\n'
          '2. Toca "Agregar" para uno nuevo.\n'
          '3. Para cambiar su nombre, apellido o teléfono, toca el cliente, '
          'luego el lápiz, y toca "Guardar".',
    ),
    PreguntaFrecuente(
      '¿Cómo anoto quién me compra de contado?',
      'Al tocar "Cobrar", en "¿Quién compra?" toca "Elegir cliente" y '
          'escógelo antes de elegir cómo paga. Así el administrador ve a sus '
          'mejores clientes en Reportes.',
    ),
  ]),
  TemaAyuda('Gastos', [
    PreguntaFrecuente(
      '¿Cómo registro un gasto?',
      '1. En el Inicio toca "− Gasto".\n'
          '2. Escribe el valor.\n'
          '3. Elige "Mercancía", "Servicios", "Arriendo", "Transporte" u '
          '"Otro", y escribe una descripción si quieres.\n'
          '4. Toca "Registrar gasto".',
    ),
    PreguntaFrecuente(
      'Me equivoqué en un gasto, ¿cómo lo arreglo?',
      '1. Ve a "Historial" y toca el filtro "Gastos".\n'
          '2. Toca el gasto y elige "Corregir" o "Anular".\n'
          'El vendedor solo corrige sus propios gastos del mismo día. '
          'Si el gasto salió de la mercancía recibida, se arregla anulando la '
          'entrada en "Inventario".',
    ),
    PreguntaFrecuente(
      '¿Tengo que anotar como gasto la mercancía que recibo?',
      'No, si la recibes en "Inventario" → "Recibir mercancía" con "Lo pagué '
          'de la caja (efectivo)" encendido: la app anota sola el gasto '
          '"Mercancía" con el proveedor. Si no la pagaste de la caja, '
          'apágalo.',
    ),
    PreguntaFrecuente(
      '¿Dónde veo cuánto gasté hoy?',
      'En el Inicio, en la tarjeta "Gastos". "Ganancia" es lo vendido menos '
          'lo gastado. En "Historial", el filtro "Gastos" muestra cada uno.',
    ),
  ]),
  TemaAyuda('Inventario y pedidos', [
    PreguntaFrecuente(
      '¿Cómo empiezo a llevar las existencias de un producto?',
      '${_soloAdmin}en "Ajustes" → "Productos" toca el producto, enciende '
          '"Controlar existencias", escribe "Hay ahora", el "Mínimo" y, si '
          'quieres, "Pedir hasta". Toca "Guardar".',
    ),
    PreguntaFrecuente(
      '¿Cómo registro la mercancía que llegó?',
      '1. Pestaña "Inventario" → "Recibir mercancía".\n'
          '2. Elige el proveedor y agrega cada producto con "Agregar '
          'producto", su cantidad y su "Precio de compra".\n'
          '3. Toca "Guardar".\n'
          'Si es un pedido que guardaste, mejor toca "Llegó este pedido" en '
          '"POR LLEGAR" y revisa lo que llegó.',
    ),
    PreguntaFrecuente(
      'La app dice que hay más o menos de lo que tengo, ¿qué hago?',
      '1. Pestaña "Inventario" → "Todos" → toca el producto.\n'
          '2. Toca "Ajustar conteo", escribe cuántas hay y toca "Guardar".',
    ),
    PreguntaFrecuente(
      '¿Cómo sé qué tengo que pedir?',
      '1. En "Inventario", "Por pedir" muestra lo que llegó a su mínimo, '
          'por proveedor. En el Inicio también sale el aviso "por pedir".\n'
          '2. Toca "Ver pedido sugerido", ajusta las cantidades y toca '
          '"Guardar pedido".\n'
          'La app no le envía el pedido al proveedor: pídeselo como siempre. '
          'El pedido queda en "POR LLEGAR".',
    ),
    PreguntaFrecuente(
      '¿Cómo cambio o anulo un pedido que no ha llegado?',
      'En "Inventario" → "POR LLEGAR" toca el pedido. Cambia lo que necesites '
          'y toca "Guardar cambios", o toca "Anular pedido". Solo lo puede '
          'cambiar quien hizo el pedido o el administrador.',
    ),
    PreguntaFrecuente(
      'Me equivoqué al recibir mercancía, ¿cómo lo arreglo?',
      'En "Inventario" → "ENTRADAS RECIBIDAS" toca la entrada y luego "Anular '
          'entrada". Se descuentan las existencias y, si se pagó de la caja, '
          'también se anula ese gasto. En ese caso la puede anular el '
          'administrador, o quien la recibió si es el mismo día.',
    ),
    PreguntaFrecuente(
      '¿Cómo agrego un proveedor?',
      '${_soloAdmin}en "Ajustes" → "Proveedores" toca "Agregar", escribe el '
          'nombre y, si quieres, el teléfono, y toca "Guardar". Para ponerle '
          'precio de compra a un producto, ábrelo en "Productos" y toca '
          '"Agregar proveedor".',
    ),
  ]),
  TemaAyuda('Reportes', [
    PreguntaFrecuente(
      '¿Dónde veo cómo le va a mi tienda?',
      '${_soloAdmin}en el Inicio toca "Ver reportes ›" o la gráfica de la '
          'semana. Elige "Semana" o "Mes" y muévete con las flechas. Ves '
          'ventas, gastos, ganancia, efectivo y transferencias, y el fiado.',
    ),
    PreguntaFrecuente(
      '¿Qué productos se venden más?',
      '${_soloAdmin}en Reportes, mira "Productos más vendidos". Solo cuenta '
          'los productos de tu lista, no los montos sueltos. Para ver cuánto '
          'ganas en cada uno, el producto debe tener precio de compra.',
    ),
    PreguntaFrecuente(
      '¿A qué horas vendo más?',
      '${_soloAdmin}en Reportes, mira "Horas de más venta": ahí sale la hora '
          'pico del periodo.',
    ),
    PreguntaFrecuente(
      '¿Quiénes son mis mejores clientes?',
      '${_soloAdmin}en Reportes, mira "Mejores clientes". Solo aparecen los '
          'clientes que se marcan al cobrar, con "Elegir cliente" o al fiar.',
    ),
    PreguntaFrecuente(
      '¿Cómo veo las ventas de otro día o de un vendedor?',
      '1. Ve a la pestaña "Historial".\n'
          '2. Cambia el día con las flechas o tocando la fecha.\n'
          '3. Filtra por "Contado", "Fiado" o "Gastos" y por el nombre de '
          'quien vendió.',
    ),
  ]),
  TemaAyuda('Productos y escáner', [
    PreguntaFrecuente(
      '¿Cómo veo el precio de algo sin venderlo?',
      '1. En el Inicio toca "Consultar precio".\n'
          '2. Escanea el código de barras.\n'
          '3. Verás el nombre y el precio; no se agrega a ninguna venta.\n'
          'Toca "Consultar otro" para ver otro o "Listo" para volver. Si el '
          'código no está, toca "Agregar producto" para crearlo.',
    ),
    PreguntaFrecuente(
      '¿Cómo agrego un producto?',
      '${_soloAdmin}en "Ajustes" → "Productos" toca "Agregar". Escribe el '
          'nombre y el "Precio de venta" y toca "Guardar". Con "Escanear '
          'código" la app intenta llenar el nombre si hay internet. Cualquier '
          'usuario puede crear un producto al escanear un código que no '
          'existe.',
    ),
    PreguntaFrecuente(
      '¿Cómo cambio el precio de un producto?',
      '${_soloAdmin}en "Ajustes" → "Productos" toca el producto, cambia el '
          '"Precio de venta" y toca "Guardar". También puedes mantener '
          'presionado el producto en "Nueva venta" y tocar "Editar producto". '
          'Lo que ya está en el ticket conserva su precio.',
    ),
    PreguntaFrecuente(
      '¿Cómo dejo de vender un producto?',
      '${_soloAdmin}en "Ajustes" → "Productos" toca el botón "Desactivar" del '
          'producto (el ojo tachado). Pasa a "INACTIVOS", donde lo puedes '
          'recuperar con "Reactivar".',
    ),
    PreguntaFrecuente(
      '¿Cómo ordeno los productos de la venta?',
      'En "Nueva venta" toca el botón "Ordenar" de arriba y elige "A–Z", '
          '"Como los creé" o "Más vendidos". La app recuerda el orden que '
          'elijas.',
    ),
    PreguntaFrecuente(
      'El escáner no lee el código, ¿qué hago?',
      'Acerca o aleja el celular hasta que el código quede dentro del cuadro. '
          'Si hay poca luz, toca la linterna. Si aun así no lo lee, toca '
          '"Escribir código", escribe los números y toca "Usar".',
    ),
  ]),
  TemaAyuda('Cuenta y seguridad', [
    PreguntaFrecuente(
      '¿Cómo entro a la app?',
      'En "¿Quién eres?" toca tu nombre y escribe tu PIN de 4 dígitos.',
    ),
    PreguntaFrecuente(
      'Se me olvidó el PIN, ¿qué hago?',
      'Pídele al administrador que te ponga uno nuevo: en "Ajustes" → '
          '"Usuarios" toca tu nombre, escribe el nuevo PIN y toca "Guardar". '
          'La app no puede mostrar el PIN anterior.',
    ),
    PreguntaFrecuente(
      '¿Cómo agrego a un vendedor?',
      '${_soloAdmin}en "Ajustes" → "Usuarios" toca "Agregar". Escribe el '
          'nombre y un PIN de 4 dígitos, elige "Vendedor" o "Administrador" y '
          'toca "Agregar usuario".',
    ),
    PreguntaFrecuente(
      '¿Qué puede hacer un vendedor?',
      'Vender, fiar, recibir abonos, registrar gastos, consultar precios, '
          'usar el Inventario y ver el Historial. Solo corrige o anula lo suyo '
          'del mismo día. No ve "Ajustes" ni los reportes.',
    ),
    PreguntaFrecuente(
      '¿Cómo entro con la huella?',
      '${_soloAdmin}si el celular tiene lector de huella, en "Ajustes" '
          'enciende "Entrar con huella", toca '
          '"Activar" y confirma con tu huella. Después, en la pantalla del PIN '
          'toca "Entrar con huella". El PIN sigue sirviendo. Actívalo solo si '
          'el celular es tuyo.',
    ),
    PreguntaFrecuente(
      '¿Cómo cierro la sesión?',
      'Toca tu inicial, arriba a la derecha, y elige "Cerrar sesión".',
    ),
    PreguntaFrecuente(
      '¿Cómo cambio el nombre de la tienda?',
      '${_soloAdmin}en "Ajustes" toca la tarjeta de arriba, donde sale el '
          'nombre, escribe el nuevo y toca "Guardar".',
    ),
  ]),
  TemaAyuda('Respaldo', [
    PreguntaFrecuente(
      '¿La app necesita internet?',
      'No. Todo se guarda en este celular y funciona sin internet. Solo el '
          'respaldo en la nube y llenar el nombre de un producto al escanearlo '
          'necesitan conexión.',
    ),
    PreguntaFrecuente(
      '¿Cómo activo el respaldo en la nube?',
      '${_soloAdmin}en "Ajustes" → "Respaldo" toca "Activar respaldo". '
          'Escribe el celular de la tienda, toca "Enviarme el código" y '
          'escribe el código de 6 dígitos que llega por SMS; luego toca '
          '"Verificar". Si ya hay un respaldo de esta tienda, la app te '
          'pregunta si quieres "Restaurarlo en este celular" o '
          '"Reemplazarlo con los datos de este celular". Si sale '
          '"Respaldo no configurado", esta versión de la app no tiene '
          'conexión a la nube y no se puede activar.',
    ),
    PreguntaFrecuente(
      '¿Cada cuánto se guarda la copia?',
      'Con el respaldo activo, la app guarda una copia sola al abrirla y '
          'poco después de cada cambio, siempre que haya internet. El '
          'administrador ve el último respaldo en "Ajustes" → "Respaldo" y '
          'puede tocar "Respaldar ahora".',
    ),
    PreguntaFrecuente(
      'Cambié de celular, ¿cómo recupero mis datos?',
      '1. Instala la app en el celular nuevo.\n'
          '2. Toca "Ya tengo una tienda: restaurar respaldo".\n'
          '3. Escribe el mismo celular de la tienda, toca "Enviarme el '
          'código", escribe el código que llega por SMS y toca "Verificar".\n'
          '4. Cuando salga "Respaldo restaurado", entra con tu PIN.\n'
          'Solo funciona si antes activaste el respaldo. La huella hay que '
          'activarla otra vez.',
    ),
    PreguntaFrecuente(
      '¿Puedo usar la tienda en dos celulares?',
      'Todavía no: cada tienda funciona en un solo celular. Restaurar el '
          'respaldo en otro celular reemplaza los datos de ese celular.',
    ),
  ]),
  TemaAyuda('Apariencia', [
    PreguntaFrecuente(
      '¿Cómo pongo el modo oscuro?',
      'Toca tu inicial, arriba a la derecha, luego "Apariencia" y elige '
          '"Oscuro". "Automático" sigue lo que tenga el celular.',
    ),
    PreguntaFrecuente(
      '¿Cómo agrando la letra?',
      'Toca tu inicial, luego "Apariencia", y en "Tamaño de letra" elige '
          '"Normal", "Grande" o "Muy grande". Se guarda en este celular.',
    ),
    PreguntaFrecuente(
      'No siento la vibración al tocar, ¿por qué?',
      'La app vibra solo si el celular tiene encendida la vibración al tocar '
          '(a veces se llama "respuesta háptica"). Búscala en los ajustes de '
          'sonido y vibración del celular.',
    ),
  ]),
];
