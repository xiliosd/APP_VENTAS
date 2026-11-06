-- Verificación de los celulares de vendedores y los PIN en el servidor (E3).
-- Corre en una transacción que termina en ROLLBACK: no deja nada en la base.
-- Cualquier comprobación que falle lanza una excepción con el motivo.
begin;

insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data,
  raw_user_meta_data, is_anonymous, created_at, updated_at)
values
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'prueba-a@vecitienda.test', '{}', '{}', false,
   now(), now()),
  ('00000000-0000-4000-8000-00000000000c', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', null, '{}', '{}', true, now(), now());

create temporary table resultado (tienda uuid, codigo text) on commit drop;
grant all on resultado to authenticated;

-- A (admin con correo) crea la tienda, sus usuarios y el PIN de un vendedor.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';

insert into resultado (tienda) select public.crear_tienda('Prueba');
do $$
declare
  t uuid := (select tienda from resultado);
  c text;
begin
  c := public.codigo_tienda(t);
  if c is null or c !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$' then
    raise exception 'código de tienda inválido: %', c;
  end if;
  update resultado set codigo = c;
  insert into public.filas (tienda_id, tabla, id_global, datos) values
    (t, 'usuarios', 'u-admin', '{"nombre":"Ana","rol":"admin","activo":1}'),
    (t, 'usuarios', 'u-vend',
     '{"nombre":"Beto","rol":"vendedor","activo":1,"numero_vendedor":1}'),
    (t, 'usuarios', 'u-legado',
     '{"nombre":"Caro","rol":"vendedor","activo":1,"numero_vendedor":2,"pin_hash":"x"}'),
    (t, 'ventas', 'v-vieja', '{"fecha":1000}');
  if exists (select 1 from public.filas where tabla = 'usuarios' and datos ? 'pin_hash') then
    raise exception 'el PIN viaja en filas';
  end if;
  perform public.guardar_pin(t, 'u-vend', '1234', 1);
  if array(select x from public.pines_faltantes(t) x order by 1)
     <> array['u-admin', 'u-legado'] then
    raise exception 'pines_faltantes no devuelve los usuarios sin PIN';
  end if;
  perform public.guardar_pin_legado(t, 'u-legado',
    encode(extensions.digest('4321', 'sha256'), 'hex'), 0);
  -- Un segundo legado no pisa el que ya está.
  perform public.guardar_pin_legado(t, 'u-legado',
    encode(extensions.digest('9999', 'sha256'), 'hex'), 0);
  if public.verificar_pin(t, 'u-legado', '4321') <> 'ok' then
    raise exception 'el PIN legado no se acepta';
  end if;
  if public.verificar_pin(t, 'u-legado', '4321') <> 'ok' then
    raise exception 'el PIN legado no quedó en bcrypt';
  end if;
end $$;

-- V (celular anónimo) pide entrar.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
declare
  t uuid := (select tienda from resultado);
  c text := (select codigo from resultado);
  r_pin jsonb;
  r_codigo jsonb;
  r_numero jsonb;
  r jsonb;
begin
  r_pin := public.solicitar_ingreso(c, 1, '0000', 'Redmi');
  r_codigo := public.solicitar_ingreso('000000', 1, '1234', 'Redmi');
  r_numero := public.solicitar_ingreso(c, 9, '1234', 'Redmi');
  if r_pin <> '{"resultado":"incorrecto"}'::jsonb
     or r_codigo <> r_pin or r_numero <> r_pin then
    raise exception 'las respuestas de error revelan qué parte falló: % % %',
      r_pin, r_codigo, r_numero;
  end if;
  if public.mi_membresia() is not null then
    raise exception 'un intento fallido creó membresía';
  end if;
  r := public.solicitar_ingreso(lower(c), 1, '1234', 'Redmi');
  if r ->> 'resultado' <> 'ok' or r ->> 'nombre_vendedor' <> 'Beto'
     or (r ->> 'tienda')::uuid <> t or r ->> 'nombre_tienda' <> 'Prueba' then
    raise exception 'solicitar_ingreso con datos buenos devolvió %', r;
  end if;
  if public.mi_membresia() ->> 'estado' <> 'pendiente'
     or public.mi_membresia() ->> 'usuario_id_global' <> 'u-vend' then
    raise exception 'la membresía no quedó pendiente: %', public.mi_membresia();
  end if;
  if (select count(*) from public.filas) <> 0 then
    raise exception 'un celular pendiente ve filas';
  end if;
  begin
    perform public.guardar_pin(t, 'u-vend', '9999', 2);
    raise exception 'V pudo guardar un PIN';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.responder_solicitud(t, '00000000-0000-4000-8000-00000000000c', true);
    raise exception 'V pudo aprobarse';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.desactivar_vendedor(t, 'u-vend');
    raise exception 'V pudo desactivar un vendedor';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.revocar_celular(t, '00000000-0000-4000-8000-00000000000c');
    raise exception 'V pudo revocar un celular';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.entregar_pendientes('[]'::jsonb);
    raise exception 'un celular no revocado pudo entregar';
  exception when insufficient_privilege then null;
  end;
  -- Bloqueo: cinco PIN malos y luego el bueno sigue bloqueado.
  for i in 1..5 loop
    r := public.solicitar_ingreso(c, 2, '0000', 'Redmi');
  end loop;
  r := public.solicitar_ingreso(c, 2, '4321', 'Redmi');
  if r ->> 'resultado' <> 'bloqueado' then
    raise exception 'tras cinco intentos no bloquea: %', r;
  end if;
  if public.mi_membresia() ->> 'usuario_id_global' <> 'u-vend' then
    raise exception 'un intento bloqueado cambió la membresía';
  end if;
end $$;

-- A ve la solicitud y la aprueba.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
do $$
declare
  t uuid := (select tienda from resultado);
begin
  if (select count(*) from public.miembros where tienda_id = t) <> 2 then
    raise exception 'el admin no ve los celulares de su tienda';
  end if;
  perform public.responder_solicitud(t, '00000000-0000-4000-8000-00000000000c', true);
end $$;

set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
begin
  if public.mi_membresia() ->> 'estado' <> 'aprobado' then
    raise exception 'la aprobación no llegó';
  end if;
  if (select count(*) from public.filas) <> 4 then
    raise exception 'el celular aprobado no ve las filas';
  end if;
  if (select count(*) from public.miembros) <> 1 then
    raise exception 'un vendedor ve otras membresías';
  end if;
end $$;

-- A le quita el acceso; V entrega lo que tenía antes de la revocación.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
do $$
declare
  t uuid := (select tienda from resultado);
begin
  perform public.revocar_celular(t, '00000000-0000-4000-8000-00000000000a');
  perform public.revocar_celular(t, '00000000-0000-4000-8000-00000000000c');
  if public.mi_membresia() ->> 'estado' <> 'aprobado' then
    raise exception 'el admin se revocó a sí mismo';
  end if;
end $$;

set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
declare
  antes bigint := extract(epoch from now())::bigint - 3600;
  despues bigint := extract(epoch from now())::bigint + 3600;
  n int;
begin
  if public.mi_membresia() ->> 'estado' <> 'revocado'
     or public.mi_membresia() ->> 'revocado_en' is null then
    raise exception 'la revocación no llegó';
  end if;
  if (select count(*) from public.filas) <> 0 then
    raise exception 'un celular revocado ve filas';
  end if;
  n := public.entregar_pendientes(jsonb_build_array(
    jsonb_build_object('tabla', 'ventas', 'id_global', 'v-antes',
      'datos', jsonb_build_object('fecha', antes, 'total', 1000)),
    jsonb_build_object('tabla', 'lineas_venta', 'id_global', 'lv-1',
      'datos', jsonb_build_object('venta_id', 'v-antes')),
    jsonb_build_object('tabla', 'ventas', 'id_global', 'v-despues',
      'datos', jsonb_build_object('fecha', despues)),
    jsonb_build_object('tabla', 'lineas_venta', 'id_global', 'lv-2',
      'datos', jsonb_build_object('venta_id', 'v-despues')),
    jsonb_build_object('tabla', 'ventas', 'id_global', 'v-vieja',
      'datos', jsonb_build_object('fecha', antes, 'total', 1)),
    jsonb_build_object('tabla', 'usuarios', 'id_global', 'u-nuevo',
      'datos', '{"nombre":"Intruso","rol":"admin"}'::jsonb)
  ));
  if n <> 2 then
    raise exception 'entregar_pendientes aceptó % filas (esperaba 2)', n;
  end if;
end $$;

-- A desactiva al vendedor: su PIN deja de servir.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
do $$
declare
  t uuid := (select tienda from resultado);
begin
  perform public.desactivar_vendedor(t, 'u-vend');
  if public.verificar_pin(t, 'u-vend', '1234') <> 'inactivo' then
    raise exception 'un vendedor desactivado sigue entrando';
  end if;
  perform public.guardar_pin(t, 'u-vend', '5678', 2);
  if public.verificar_pin(t, 'u-vend', '5678') <> 'ok' then
    raise exception 'reactivar con PIN nuevo no funciona';
  end if;
end $$;

-- Comprobaciones directas sobre las tablas, como dueño.
reset role;
do $$
declare
  t uuid := (select tienda from resultado);
begin
  if (select datos ->> 'total' from public.filas where tienda_id = t and id_global = 'v-vieja')
     is not null then
    raise exception 'la entrega pisó una fila que ya existía';
  end if;
  if not exists (select 1 from public.filas where tienda_id = t and id_global = 'lv-1')
     or exists (select 1 from public.filas where tienda_id = t
                and id_global in ('v-despues', 'lv-2', 'u-nuevo')) then
    raise exception 'la entrega no filtró bien';
  end if;
  if (select hash_legado from public.pines
      where tienda_id = t and usuario_id_global = 'u-legado') is not null
     or (select hash from public.pines
      where tienda_id = t and usuario_id_global = 'u-legado') not like '$2%' then
    raise exception 'el PIN legado no pasó a bcrypt';
  end if;
  if (select valor from public.configuracion_app
      where clave = 'version_protocolo_minima') <> '2' then
    raise exception 'la versión mínima del protocolo no es 2';
  end if;
end $$;

select 'todas las comprobaciones pasaron' as resultado;
rollback;
