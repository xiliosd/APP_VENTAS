-- Celulares de vendedores y PIN revisados en el servidor (E3). Ver
-- docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md (§5, §6)
-- y docs/superpowers/plans/2026-11-03-vecitienda-e3-entrada-y-salida-del-vendedor.md.

-- Código de la tienda: lo que el admin le dicta al vendedor. Sin 0/O/1/I/L
-- para que no se confundan al escribirlo.
create function public._codigo_tienda_nuevo()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alfabeto constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_codigo text;
begin
  loop
    v_bytes := extensions.gen_random_bytes(6);
    v_codigo := '';
    for i in 0..5 loop
      v_codigo := v_codigo || substr(v_alfabeto, 1 + get_byte(v_bytes, i) % 31, 1);
    end loop;
    exit when not exists (select 1 from public.tiendas where codigo = v_codigo);
  end loop;
  return v_codigo;
end;
$$;
revoke execute on function public._codigo_tienda_nuevo() from public, anon, authenticated;

alter table public.tiendas add column codigo text;
update public.tiendas set codigo = public._codigo_tienda_nuevo() where codigo is null;
alter table public.tiendas
  alter column codigo set not null,
  alter column codigo set default public._codigo_tienda_nuevo(),
  add constraint tiendas_codigo_unico unique (codigo);

alter table public.miembros
  add column usuario_id_global text,
  add column nombre_celular text,
  add column solicitado_en timestamptz not null default now();

create function public.es_admin_de(p_tienda uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.miembros
    where tienda_id = p_tienda
      and usuario_id = (select auth.uid())
      and rol = 'admin'
      and estado = 'aprobado'
  );
$$;
revoke execute on function public.es_admin_de(uuid) from public, anon;
grant execute on function public.es_admin_de(uuid) to authenticated;

create policy "miembros: el admin ve los de su tienda" on public.miembros
  for select to authenticated using ((select public.es_admin_de(tienda_id)));

-- El PIN de cada usuario de la tienda. Nadie la lee directamente: solo las
-- funciones de abajo, que limitan los intentos.
create table public.pines (
  tienda_id uuid not null references public.tiendas (id) on delete cascade,
  usuario_id_global text not null,
  hash text,
  hash_legado text,
  version int not null default 0,
  intentos int not null default 0,
  bloqueado_hasta timestamptz,
  activo boolean not null default true,
  primary key (tienda_id, usuario_id_global)
);
alter table public.pines enable row level security;
revoke all on public.pines from public, anon, authenticated;

-- El PIN ya no viaja en las filas; esto también lo quita si un celular viejo
-- lo intenta subir.
create or replace function public.asignar_version_fila()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.tienda_id::text, 0));
  if new.tabla = 'usuarios' and new.datos ? 'pin_hash' then
    new.datos := new.datos - 'pin_hash';
  end if;
  new.version := nextval('public.filas_version_seq');
  new.actualizado_en := now();
  new.actualizado_por := auth.uid();
  return new;
end;
$$;

-- 'ok' | 'incorrecto' | 'bloqueado' | 'inactivo'. Cinco fallos seguidos
-- bloquean 15 minutos; 'inactivo' solo se dice con el PIN correcto para no
-- revelar nada a quien adivina.
create function public._pin_valido(p_tienda uuid, p_id_global text, p_pin text)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v public.pines%rowtype;
  v_correcto boolean := false;
begin
  select * into v from public.pines
  where tienda_id = p_tienda and usuario_id_global = p_id_global
  for update;
  if not found then
    return 'incorrecto';
  end if;
  if v.bloqueado_hasta is not null and v.bloqueado_hasta > now() then
    return 'bloqueado';
  end if;
  if v.hash is not null and v.hash = extensions.crypt(coalesce(p_pin, ''), v.hash) then
    v_correcto := true;
  elsif v.hash_legado is not null
     and v.hash_legado = encode(extensions.digest(coalesce(p_pin, ''), 'sha256'), 'hex') then
    v_correcto := true;
    update public.pines
    set hash = extensions.crypt(p_pin, extensions.gen_salt('bf')), hash_legado = null
    where tienda_id = p_tienda and usuario_id_global = p_id_global;
  end if;
  if not v_correcto then
    if v.intentos + 1 >= 5 then
      update public.pines
      set intentos = 0, bloqueado_hasta = now() + interval '15 minutes'
      where tienda_id = p_tienda and usuario_id_global = p_id_global;
    else
      update public.pines set intentos = v.intentos + 1
      where tienda_id = p_tienda and usuario_id_global = p_id_global;
    end if;
    return 'incorrecto';
  end if;
  update public.pines set intentos = 0, bloqueado_hasta = null
  where tienda_id = p_tienda and usuario_id_global = p_id_global;
  if not v.activo then
    return 'inactivo';
  end if;
  return 'ok';
end;
$$;
revoke execute on function public._pin_valido(uuid, text, text) from public, anon, authenticated;

create function public._exigir_admin(p_tienda uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.es_admin_de(p_tienda) then
    raise exception 'solo el administrador de la tienda puede hacer esto'
      using errcode = 'insufficient_privilege';
  end if;
end;
$$;
revoke execute on function public._exigir_admin(uuid) from public, anon, authenticated;

create function public.codigo_tienda(p_tienda uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.es_miembro_aprobado(p_tienda) then
    raise exception 'sin acceso a la tienda' using errcode = 'insufficient_privilege';
  end if;
  return (select codigo from public.tiendas where id = p_tienda);
end;
$$;

create function public.guardar_pin(
  p_tienda uuid, p_id_global text, p_pin text, p_version int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    raise exception 'PIN inválido' using errcode = 'invalid_parameter_value';
  end if;
  insert into public.pines (tienda_id, usuario_id_global, hash, version)
  values (p_tienda, p_id_global, extensions.crypt(p_pin, extensions.gen_salt('bf')),
    coalesce(p_version, 0))
  on conflict (tienda_id, usuario_id_global) do update
  set hash = excluded.hash, hash_legado = null, version = excluded.version,
    intentos = 0, bloqueado_hasta = null, activo = true;
end;
$$;

create function public.guardar_pin_legado(
  p_tienda uuid, p_id_global text, p_hash text, p_version int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'hash inválido' using errcode = 'invalid_parameter_value';
  end if;
  insert into public.pines (tienda_id, usuario_id_global, hash_legado, version)
  values (p_tienda, p_id_global, p_hash, coalesce(p_version, 0))
  on conflict (tienda_id, usuario_id_global) do nothing;
end;
$$;

create function public.pines_faltantes(p_tienda uuid)
returns setof text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  return query
    select f.id_global from public.filas f
    where f.tienda_id = p_tienda and f.tabla = 'usuarios' and not f.borrado
      and not exists (
        select 1 from public.pines p
        where p.tienda_id = p_tienda and p.usuario_id_global = f.id_global);
end;
$$;

create function public.verificar_pin(p_tienda uuid, p_id_global text, p_pin text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.es_miembro_aprobado(p_tienda) then
    raise exception 'sin acceso a la tienda' using errcode = 'insufficient_privilege';
  end if;
  return public._pin_valido(p_tienda, p_id_global, p_pin);
end;
$$;

-- Un celular (sesión anónima) pide entrar como el vendedor número p_numero.
-- Código, número o PIN malos dan la misma respuesta.
create function public.solicitar_ingreso(
  p_codigo text, p_numero int, p_pin text, p_celular text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_tienda uuid;
  v_nombre_tienda text;
  v_id_global text;
  v_nombre_vendedor text;
  v_resultado text;
  v_incorrecto constant jsonb := '{"resultado":"incorrecto"}';
begin
  if v_usuario is null then
    raise exception 'sin sesión' using errcode = 'insufficient_privilege';
  end if;
  select id, nombre into v_tienda, v_nombre_tienda from public.tiendas
  where codigo = upper(trim(coalesce(p_codigo, '')));
  if not found then
    return v_incorrecto;
  end if;
  select id_global, datos ->> 'nombre' into v_id_global, v_nombre_vendedor
  from public.filas
  where tienda_id = v_tienda and tabla = 'usuarios' and not borrado
    and datos ->> 'rol' = 'vendedor'
    and datos ->> 'numero_vendedor' = p_numero::text
    and coalesce(datos ->> 'activo', '1') in ('1', 'true')
  limit 1;
  if not found then
    return v_incorrecto;
  end if;
  -- Quien ya es admin de esta tienda no se convierte en vendedor.
  if exists (select 1 from public.miembros
             where tienda_id = v_tienda and usuario_id = v_usuario and rol = 'admin') then
    return v_incorrecto;
  end if;
  v_resultado := public._pin_valido(v_tienda, v_id_global, p_pin);
  if v_resultado <> 'ok' then
    return jsonb_build_object('resultado', v_resultado);
  end if;
  insert into public.miembros (tienda_id, usuario_id, rol, estado, usuario_id_global,
    nombre_celular, solicitado_en)
  values (v_tienda, v_usuario, 'vendedor', 'pendiente', v_id_global,
    left(coalesce(nullif(trim(p_celular), ''), 'Celular'), 60), now())
  on conflict (tienda_id, usuario_id) do update
  set estado = case when public.miembros.estado = 'aprobado'
                      and public.miembros.usuario_id_global = excluded.usuario_id_global
                    then 'aprobado' else 'pendiente' end,
      usuario_id_global = excluded.usuario_id_global,
      nombre_celular = excluded.nombre_celular,
      solicitado_en = now(),
      revocado_en = null;
  return jsonb_build_object('resultado', 'ok', 'tienda', v_tienda,
    'nombre_tienda', v_nombre_tienda, 'nombre_vendedor', v_nombre_vendedor);
end;
$$;

create function public.mi_membresia()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('tienda', tienda_id, 'rol', rol, 'estado', estado,
    'revocado_en', revocado_en, 'usuario_id_global', usuario_id_global)
  from public.miembros
  where usuario_id = (select auth.uid())
  order by (rol = 'admin') desc, solicitado_en desc
  limit 1;
$$;

create function public.responder_solicitud(p_tienda uuid, p_usuario uuid, p_aprobar boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  update public.miembros
  set estado = case when p_aprobar then 'aprobado' else 'rechazado' end
  where tienda_id = p_tienda and usuario_id = p_usuario
    and rol = 'vendedor' and estado = 'pendiente';
end;
$$;

create function public.revocar_celular(p_tienda uuid, p_usuario uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  update public.miembros
  set estado = 'revocado', revocado_en = now()
  where tienda_id = p_tienda and usuario_id = p_usuario
    and rol = 'vendedor' and estado in ('pendiente', 'aprobado');
end;
$$;

create function public.desactivar_vendedor(p_tienda uuid, p_id_global text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  update public.miembros
  set estado = 'revocado', revocado_en = now()
  where tienda_id = p_tienda and usuario_id_global = p_id_global
    and rol = 'vendedor' and estado in ('pendiente', 'aprobado');
  update public.pines set activo = false
  where tienda_id = p_tienda and usuario_id_global = p_id_global;
end;
$$;

-- Un celular revocado entrega, una sola vez y hasta 30 días después, los
-- movimientos que hizo antes de perder el acceso (spec §7, llamada 9). Solo
-- filas nuevas; nada que pise lo que ya está en la tienda.
create function public.entregar_pendientes(p_filas jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tienda uuid;
  v_revocado timestamptz;
  v_fila jsonb;
  v_tabla text;
  v_id text;
  v_datos jsonb;
  v_fecha text;
  v_aceptadas int := 0;
begin
  select tienda_id, revocado_en into v_tienda, v_revocado from public.miembros
  where usuario_id = (select auth.uid()) and rol = 'vendedor' and estado = 'revocado'
    and revocado_en is not null
  order by revocado_en desc
  limit 1;
  if not found or v_revocado < now() - interval '30 days' then
    raise exception 'este celular no puede entregar movimientos'
      using errcode = 'insufficient_privilege';
  end if;
  if jsonb_typeof(p_filas) <> 'array' then
    return 0;
  end if;
  for v_fila in select value from jsonb_array_elements(p_filas) loop
    v_tabla := v_fila ->> 'tabla';
    v_id := v_fila ->> 'id_global';
    v_datos := v_fila -> 'datos';
    continue when v_tabla is null or v_id is null or v_datos is null
      or jsonb_typeof(v_datos) <> 'object';
    continue when v_tabla not in ('ventas', 'lineas_venta', 'pagos_fiado', 'gastos',
      'conteos_inventario', 'entradas_mercancia', 'lineas_entrada', 'correcciones');
    continue when exists (select 1 from public.filas
      where tienda_id = v_tienda and tabla = v_tabla and id_global = v_id);
    if v_tabla in ('lineas_venta', 'lineas_entrada') then
      continue when not exists (select 1 from public.filas
        where tienda_id = v_tienda and not borrado
          and tabla = case v_tabla when 'lineas_venta' then 'ventas'
                                   else 'entradas_mercancia' end
          and id_global = v_datos ->> case v_tabla when 'lineas_venta' then 'venta_id'
                                                   else 'entrada_id' end);
    else
      v_fecha := v_datos ->> 'fecha';
      continue when v_fecha is null or v_fecha !~ '^[0-9]{1,12}$'
        or v_fecha::bigint >= extract(epoch from v_revocado);
    end if;
    insert into public.filas (tienda_id, tabla, id_global, datos)
    values (v_tienda, v_tabla, v_id, v_datos);
    v_aceptadas := v_aceptadas + 1;
  end loop;
  return v_aceptadas;
end;
$$;

revoke execute on function public.codigo_tienda(uuid) from public, anon;
revoke execute on function public.guardar_pin(uuid, text, text, int) from public, anon;
revoke execute on function public.guardar_pin_legado(uuid, text, text, int) from public, anon;
revoke execute on function public.pines_faltantes(uuid) from public, anon;
revoke execute on function public.verificar_pin(uuid, text, text) from public, anon;
revoke execute on function public.solicitar_ingreso(text, int, text, text) from public, anon;
revoke execute on function public.mi_membresia() from public, anon;
revoke execute on function public.responder_solicitud(uuid, uuid, boolean) from public, anon;
revoke execute on function public.revocar_celular(uuid, uuid) from public, anon;
revoke execute on function public.desactivar_vendedor(uuid, text) from public, anon;
revoke execute on function public.entregar_pendientes(jsonb) from public, anon;
grant execute on function public.codigo_tienda(uuid) to authenticated;
grant execute on function public.guardar_pin(uuid, text, text, int) to authenticated;
grant execute on function public.guardar_pin_legado(uuid, text, text, int) to authenticated;
grant execute on function public.pines_faltantes(uuid) to authenticated;
grant execute on function public.verificar_pin(uuid, text, text) to authenticated;
grant execute on function public.solicitar_ingreso(text, int, text, text) to authenticated;
grant execute on function public.mi_membresia() to authenticated;
grant execute on function public.responder_solicitud(uuid, uuid, boolean) to authenticated;
grant execute on function public.revocar_celular(uuid, uuid) to authenticated;
grant execute on function public.desactivar_vendedor(uuid, text) to authenticated;
grant execute on function public.entregar_pendientes(jsonb) to authenticated;

-- Datos: el PIN sale de las filas que ya estaban; los celulares de E2 dejan de
-- sincronizar para no volver a subirlo.
update public.filas set datos = datos - 'pin_hash'
where tabla = 'usuarios' and datos ? 'pin_hash';
update public.configuracion_app set valor = '2' where clave = 'version_protocolo_minima';
