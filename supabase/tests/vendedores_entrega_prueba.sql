-- Verificación de la entrega de un celular revocado y de las filas que solo el
-- admin puede escribir (arreglos de la revisión de E3). Corre en una
-- transacción que termina en ROLLBACK: no deja nada en la base.
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

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
insert into resultado (tienda) select public.crear_tienda('Prueba');
do $$
declare
  t uuid := (select tienda from resultado);
begin
  update resultado set codigo = public.codigo_tienda(t);
  insert into public.filas (tienda_id, tabla, id_global, datos) values
    (t, 'usuarios', 'u-admin', '{"nombre":"Ana","rol":"admin","activo":1}'),
    (t, 'usuarios', 'u-vend',
     '{"nombre":"Beto","rol":"vendedor","activo":1,"numero_vendedor":1}'),
    (t, 'ventas', 'v-admin', '{"fecha":1000}');
  perform public.guardar_pin(t, 'u-vend', '1234', 1);
end $$;

-- V entra y queda aprobado.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
begin
  perform public.solicitar_ingreso((select codigo from resultado), 1, '1234', 'Redmi');
end $$;
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
do $$
begin
  perform public.responder_solicitud((select tienda from resultado),
    '00000000-0000-4000-8000-00000000000c', true);
end $$;

-- Un vendedor aprobado no puede tocar usuarios ni la configuración (se
-- omiten sin error, para no frenar el resto de su subida).
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
declare
  t uuid := (select tienda from resultado);
begin
  insert into public.filas (tienda_id, tabla, id_global, datos)
  values (t, 'usuarios', 'u-admin', '{"nombre":"Ana","rol":"admin","activo":0}')
  on conflict (tienda_id, tabla, id_global) do update set datos = excluded.datos;
  insert into public.filas (tienda_id, tabla, id_global, datos)
  values (t, 'configuracion_tienda', 'unica', '{"nombre_tienda":"Otra"}')
  on conflict (tienda_id, tabla, id_global) do update set datos = excluded.datos;
  insert into public.filas (tienda_id, tabla, id_global, datos)
  values (t, 'ventas', 'v-normal', '{"fecha":2000}');
  if (select datos ->> 'activo' from public.filas
      where tienda_id = t and id_global = 'u-admin') <> '1' then
    raise exception 'un vendedor desactivó al admin';
  end if;
  if exists (select 1 from public.filas where tienda_id = t and tabla = 'configuracion_tienda') then
    raise exception 'un vendedor cambió la configuración';
  end if;
  if not exists (select 1 from public.filas where tienda_id = t and id_global = 'v-normal') then
    raise exception 'un vendedor aprobado no pudo subir una venta';
  end if;
end $$;

-- El admin le quita el acceso.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';
do $$
begin
  perform public.revocar_celular((select tienda from resultado),
    '00000000-0000-4000-8000-00000000000c');
end $$;

-- V entrega una sola vez: cliente nuevo con su venta fiada; nada que apunte a
-- filas ajenas o que no existen.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated","is_anonymous":true}';
do $$
declare
  antes bigint := extract(epoch from now())::bigint - 3600;
  n int;
begin
  n := public.entregar_pendientes(jsonb_build_array(
    jsonb_build_object('tabla', 'clientes', 'id_global', 'c-nuevo',
      'datos', jsonb_build_object('nombre', 'Don Pedro')),
    jsonb_build_object('tabla', 'ventas', 'id_global', 'v-fiada',
      'datos', jsonb_build_object('fecha', antes, 'cliente_id', 'c-nuevo',
        'usuario_id', 'u-vend')),
    jsonb_build_object('tabla', 'ventas', 'id_global', 'v-huerfana',
      'datos', jsonb_build_object('fecha', antes, 'cliente_id', 'c-no-existe')),
    jsonb_build_object('tabla', 'lineas_venta', 'id_global', 'lv-ajena',
      'datos', jsonb_build_object('venta_id', 'v-admin')),
    jsonb_build_object('tabla', 'lineas_venta', 'id_global', 'lv-vieja',
      'datos', jsonb_build_object('venta_id', 'v-normal')),
    jsonb_build_object('tabla', 'lineas_venta', 'id_global', 'lv-propia',
      'datos', jsonb_build_object('venta_id', 'v-fiada')),
    jsonb_build_object('tabla', 'correcciones', 'id_global', 'co-vieja',
      'datos', jsonb_build_object('fecha', antes, 'tipo_movimiento', 'venta',
        'movimiento_id', 'v-normal')),
    jsonb_build_object('tabla', 'correcciones', 'id_global', 'co-propia',
      'datos', jsonb_build_object('fecha', antes, 'tipo_movimiento', 'venta',
        'movimiento_id', 'v-fiada')),
    jsonb_build_object('tabla', 'clientes', 'id_global', 'c-sin-uso',
      'datos', jsonb_build_object('nombre', 'Suelto'))
  ));
  -- c-nuevo, v-fiada, lv-propia, co-propia y c-sin-uso.
  if n <> 5 then
    raise exception 'entregar_pendientes aceptó % filas (esperaba 5)', n;
  end if;
  begin
    perform public.entregar_pendientes(jsonb_build_array(
      jsonb_build_object('tabla', 'ventas', 'id_global', 'v-otra',
        'datos', jsonb_build_object('fecha', antes))));
    raise exception 'un celular revocado entregó dos veces';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
do $$
declare
  t uuid := (select tienda from resultado);
begin
  if exists (select 1 from public.filas where tienda_id = t
             and id_global in ('v-huerfana', 'lv-ajena', 'lv-vieja', 'co-vieja', 'v-otra')) then
    raise exception 'la entrega aceptó filas que no debía';
  end if;
end $$;

select 'todas las comprobaciones pasaron' as resultado;
rollback;
