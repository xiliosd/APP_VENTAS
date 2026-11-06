-- Verificación del esquema de tienda compartida. Corre en una transacción que
-- termina en ROLLBACK: no deja nada en la base. Cualquier comprobación que
-- falle lanza una excepción con el motivo.
begin;

insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data,
  raw_user_meta_data, is_anonymous, created_at, updated_at)
values
  ('00000000-0000-4000-8000-00000000000a', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'prueba-a@vecitienda.test', '{}', '{}', false,
   now(), now()),
  ('00000000-0000-4000-8000-00000000000b', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'prueba-b@vecitienda.test', '{}', '{}', false,
   now(), now());

create temporary table resultado (tienda uuid) on commit drop;
grant all on resultado to authenticated;

-- Usuario A crea su tienda (dos veces: debe ser la misma).
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated","is_anonymous":false}';

insert into resultado select public.crear_tienda('Prueba');
do $$
declare
  t uuid := (select tienda from resultado);
  v1 bigint;
  v2 bigint;
begin
  if public.crear_tienda('Otra') <> t then
    raise exception 'crear_tienda no es idempotente';
  end if;
  if public.mi_tienda() <> t then
    raise exception 'mi_tienda no devuelve la tienda del admin';
  end if;
  insert into public.filas (tienda_id, tabla, id_global, datos)
    values (t, 'clientes', 'c1', '{"nombre":"Don Pedro"}');
  insert into public.filas (tienda_id, tabla, id_global, datos)
    values (t, 'clientes', 'c2', '{"nombre":"Juan"}');
  select version into v1 from public.filas where id_global = 'c1';
  select version into v2 from public.filas where id_global = 'c2';
  if not v2 > v1 then
    raise exception 'las versiones no crecen';
  end if;
  update public.filas set datos = '{"nombre":"Don Pedro P"}' where id_global = 'c1';
  if (select version from public.filas where id_global = 'c1') <= v2 then
    raise exception 'editar no sube la versión';
  end if;
  if (select valor from public.configuracion_app
      where clave = 'version_protocolo_minima') is null then
    raise exception 'falta la versión mínima del protocolo';
  end if;
end $$;

-- Usuario B no ve ni puede escribir en la tienda de A.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated","is_anonymous":false}';
do $$
declare
  t uuid := (select tienda from resultado);
begin
  if (select count(*) from public.filas) <> 0 then
    raise exception 'B ve filas de A';
  end if;
  if (select count(*) from public.tiendas) <> 0 then
    raise exception 'B ve la tienda de A';
  end if;
  if public.mi_tienda() is not null then
    raise exception 'B tiene tienda sin crearla';
  end if;
  begin
    insert into public.filas (tienda_id, tabla, id_global, datos)
      values (t, 'clientes', 'intruso', '{}');
    raise exception 'B pudo escribir en la tienda de A';
  exception when insufficient_privilege then
    null; -- esperado: lo bloquea RLS
  end;
end $$;

-- Un usuario anónimo no puede crear tiendas.
set local request.jwt.claims =
  '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated","is_anonymous":true}';
do $$
begin
  begin
    perform public.crear_tienda('Anónima');
    raise exception 'un anónimo pudo crear tienda';
  exception when insufficient_privilege then
    null;
  end;
end $$;

select 'todas las comprobaciones pasaron' as resultado;
rollback;
