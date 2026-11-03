-- Tienda compartida (E2): los datos de una tienda en la nube para que varios
-- celulares los mantengan al día. Ver
-- docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md.

create table public.tiendas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null default '',
  creada_en timestamptz not null default now()
);

-- Quién puede usar cada tienda. En E2 solo existe la fila del admin; E3 suma
-- los celulares de los vendedores con su aprobación.
create table public.miembros (
  tienda_id uuid not null references public.tiendas (id) on delete cascade,
  usuario_id uuid not null references auth.users (id) on delete cascade,
  rol text not null check (rol in ('admin', 'vendedor')),
  estado text not null check (estado in ('pendiente', 'aprobado', 'rechazado', 'revocado')),
  revocado_en timestamptz,
  creado_en timestamptz not null default now(),
  primary key (tienda_id, usuario_id)
);
create index miembros_usuario on public.miembros (usuario_id);

-- Cada registro de la tienda (venta, cliente, producto…) como una fila
-- genérica: `datos` lleva las columnas del celular con las referencias como
-- `id_global`. `version` crece con cada escritura y es el cursor con el que
-- cada celular baja solo lo nuevo.
create table public.filas (
  tienda_id uuid not null references public.tiendas (id) on delete cascade,
  tabla text not null,
  id_global text not null,
  datos jsonb,
  borrado boolean not null default false,
  version bigint not null default 0,
  actualizado_en timestamptz not null default now(),
  actualizado_por uuid default auth.uid(),
  primary key (tienda_id, tabla, id_global)
);
create index filas_tienda_version on public.filas (tienda_id, version);

create sequence public.filas_version_seq;

-- El candado por tienda se mantiene hasta el commit: así las versiones de una
-- tienda se confirman en orden y un celular que ya bajó hasta la versión N
-- nunca se salta una fila que se confirmó después con un número menor.
create function public.asignar_version_fila()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.tienda_id::text, 0));
  new.version := nextval('public.filas_version_seq');
  new.actualizado_en := now();
  new.actualizado_por := auth.uid();
  return new;
end;
$$;

create trigger filas_version
before insert or update on public.filas
for each row execute function public.asignar_version_fila();

create table public.configuracion_app (
  clave text primary key,
  valor text not null
);
insert into public.configuracion_app (clave, valor)
values ('version_protocolo_minima', '1');

create function public.es_miembro_aprobado(p_tienda uuid)
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
      and estado = 'aprobado'
  );
$$;

create function public.mi_tienda()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select tienda_id from public.miembros
  where usuario_id = (select auth.uid()) and rol = 'admin' and estado = 'aprobado'
  limit 1;
$$;

-- Crea la tienda del admin que llama (o devuelve la que ya tiene).
create function public.crear_tienda(p_nombre text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_tienda uuid;
begin
  if v_usuario is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'solo un administrador con correo puede crear una tienda'
      using errcode = 'insufficient_privilege';
  end if;
  select tienda_id into v_tienda from public.miembros
  where usuario_id = v_usuario and rol = 'admin'
  limit 1;
  if v_tienda is not null then
    return v_tienda;
  end if;
  insert into public.tiendas (nombre) values (coalesce(p_nombre, ''))
  returning id into v_tienda;
  insert into public.miembros (tienda_id, usuario_id, rol, estado)
  values (v_tienda, v_usuario, 'admin', 'aprobado');
  return v_tienda;
end;
$$;

revoke execute on function public.es_miembro_aprobado(uuid) from public, anon;
revoke execute on function public.mi_tienda() from public, anon;
revoke execute on function public.crear_tienda(text) from public, anon;
revoke execute on function public.asignar_version_fila() from public, anon, authenticated;
grant execute on function public.es_miembro_aprobado(uuid) to authenticated;
grant execute on function public.mi_tienda() to authenticated;
grant execute on function public.crear_tienda(text) to authenticated;

alter table public.tiendas enable row level security;
alter table public.miembros enable row level security;
alter table public.filas enable row level security;
alter table public.configuracion_app enable row level security;

create policy "tienda: ver la propia" on public.tiendas
  for select to authenticated using ((select public.es_miembro_aprobado(id)));
create policy "tienda: renombrar la propia" on public.tiendas
  for update to authenticated
  using ((select public.es_miembro_aprobado(id)))
  with check ((select public.es_miembro_aprobado(id)));

create policy "miembros: ver los propios" on public.miembros
  for select to authenticated using (usuario_id = (select auth.uid()));

create policy "filas: ver las de mi tienda" on public.filas
  for select to authenticated using ((select public.es_miembro_aprobado(tienda_id)));
create policy "filas: crear en mi tienda" on public.filas
  for insert to authenticated with check ((select public.es_miembro_aprobado(tienda_id)));
create policy "filas: editar en mi tienda" on public.filas
  for update to authenticated
  using ((select public.es_miembro_aprobado(tienda_id)))
  with check ((select public.es_miembro_aprobado(tienda_id)));

create policy "configuración: leer" on public.configuracion_app
  for select to authenticated using (true);

revoke all on public.tiendas, public.miembros, public.filas, public.configuracion_app from anon;
