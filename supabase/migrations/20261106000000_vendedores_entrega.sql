-- Arreglos de la revisión de E3: la entrega de un celular revocado ocurre una
-- sola vez y solo con filas coherentes, y los usuarios y la configuración de
-- la tienda solo los escribe el admin.

-- Un vendedor (de confianza para vender) no cambia usuarios ni la
-- configuración: la fila se omite sin error para no frenar el resto de su
-- subida. Sin sesión (migraciones, panel) no aplica.
create or replace function public.asignar_version_fila()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tabla in ('usuarios', 'configuracion_tienda')
     and auth.uid() is not null
     and not public.es_admin_de(new.tienda_id) then
    return null;
  end if;
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

alter table public.miembros add column entregado_en timestamptz;

-- Cada revocación abre una entrega nueva.
create or replace function public.revocar_celular(p_tienda uuid, p_usuario uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  update public.miembros
  set estado = 'revocado', revocado_en = now(), entregado_en = null
  where tienda_id = p_tienda and usuario_id = p_usuario
    and rol = 'vendedor' and estado in ('pendiente', 'aprobado');
end;
$$;

create or replace function public.desactivar_vendedor(p_tienda uuid, p_id_global text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._exigir_admin(p_tienda);
  update public.miembros
  set estado = 'revocado', revocado_en = now(), entregado_en = null
  where tienda_id = p_tienda and usuario_id_global = p_id_global
    and rol = 'vendedor' and estado in ('pendiente', 'aprobado');
  update public.pines set activo = false
  where tienda_id = p_tienda and usuario_id_global = p_id_global;
end;
$$;

-- Un celular revocado entrega UNA vez, hasta 30 días después, lo que hizo
-- antes de perder el acceso (spec §7, llamada 9). Solo filas nuevas:
--   * clientes, productos y proveedores que creó sin internet;
--   * movimientos con fecha anterior a la revocación;
--   * líneas y correcciones solo de un movimiento entregado en esta misma
--     llamada (las de movimientos que ya estaban describirían cambios que no
--     se aplican);
-- y cada referencia (cliente, producto, proveedor, usuario, entrada) debe
-- existir en la tienda, para que ningún celular reciba una fila huérfana.
create or replace function public.entregar_pendientes(p_filas jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_tienda uuid;
  v_revocado timestamptz;
  v_fila jsonb;
  v_tabla text;
  v_id text;
  v_datos jsonb;
  v_fecha text;
  v_padre text;
  v_referencia record;
  v_valida boolean;
  v_entregadas text[] := '{}';
  v_aceptadas int := 0;
begin
  select tienda_id, revocado_en into v_tienda, v_revocado from public.miembros
  where usuario_id = v_usuario and rol = 'vendedor' and estado = 'revocado'
    and revocado_en is not null and entregado_en is null
  order by revocado_en desc
  limit 1
  for update;
  if not found or v_revocado < now() - interval '30 days' then
    raise exception 'este celular no puede entregar movimientos'
      using errcode = 'insufficient_privilege';
  end if;
  update public.miembros set entregado_en = now()
  where tienda_id = v_tienda and usuario_id = v_usuario;
  if jsonb_typeof(p_filas) <> 'array' then
    return 0;
  end if;
  for v_fila in select value from jsonb_array_elements(p_filas) loop
    v_tabla := v_fila ->> 'tabla';
    v_id := v_fila ->> 'id_global';
    v_datos := v_fila -> 'datos';
    continue when v_tabla is null or v_id is null or v_datos is null
      or jsonb_typeof(v_datos) <> 'object';
    continue when v_tabla not in ('clientes', 'productos', 'proveedores', 'ventas',
      'lineas_venta', 'pagos_fiado', 'gastos', 'conteos_inventario',
      'entradas_mercancia', 'lineas_entrada', 'correcciones');
    continue when exists (select 1 from public.filas
      where tienda_id = v_tienda and tabla = v_tabla and id_global = v_id);
    if v_tabla in ('lineas_venta', 'lineas_entrada', 'correcciones') then
      v_padre := case v_tabla
        when 'lineas_venta' then 'ventas/' || coalesce(v_datos ->> 'venta_id', '')
        when 'lineas_entrada' then
          'entradas_mercancia/' || coalesce(v_datos ->> 'entrada_id', '')
        else case v_datos ->> 'tipo_movimiento'
          when 'venta' then 'ventas/'
          when 'abono' then 'pagos_fiado/'
          when 'gasto' then 'gastos/'
          else '?/' end || coalesce(v_datos ->> 'movimiento_id', '')
      end;
      continue when not (v_padre = any (v_entregadas));
    end if;
    if v_tabla not in ('clientes', 'productos', 'proveedores',
                       'lineas_venta', 'lineas_entrada') then
      v_fecha := v_datos ->> 'fecha';
      continue when v_fecha is null or v_fecha !~ '^[0-9]{1,12}$'
        or v_fecha::bigint >= extract(epoch from v_revocado);
    end if;
    v_valida := true;
    for v_referencia in
      select * from (values
        ('cliente_id', 'clientes'), ('producto_id', 'productos'),
        ('proveedor_id', 'proveedores'), ('usuario_id', 'usuarios'),
        ('entrada_id', 'entradas_mercancia')) as r(columna, apuntada)
    loop
      if v_datos ->> v_referencia.columna is not null
         and not exists (select 1 from public.filas
           where tienda_id = v_tienda and tabla = v_referencia.apuntada
             and id_global = v_datos ->> v_referencia.columna and not borrado) then
        v_valida := false;
      end if;
    end loop;
    continue when not v_valida;
    insert into public.filas (tienda_id, tabla, id_global, datos)
    values (v_tienda, v_tabla, v_id, v_datos);
    v_entregadas := v_entregadas || (v_tabla || '/' || v_id);
    v_aceptadas := v_aceptadas + 1;
  end loop;
  return v_aceptadas;
end;
$$;
