-- ============================================================================
--  AmilCar · Esquema de base de datos para Supabase
-- ============================================================================
--  Ejecuta este script en el SQL Editor de tu proyecto Supabase ANTES de
--  cambiar AppConfig.useMockData a false.
--
--  Crea:
--   1. Tabla `perfiles`        (id, rol, nombre, foto_url) ligada a auth.users
--   2. Tabla `clientes`        (directorio normalizado de clientes)
--   3. Tabla `ordenes_trabajo` (modelo relacional del Kanban) con FK -> clientes
--   4. Políticas RLS
--   5. Trigger que crea el perfil automáticamente al registrarse un usuario
--   6. Realtime habilitado sobre `clientes` y `ordenes_trabajo`
--
--  MIGRACIÓN: si tu BD ya tenía una tabla `estimados` (nombre viejo), el
--  bloque al final de la sección 3 la renombra a `ordenes_trabajo` de forma
--  idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) TABLA: perfiles
-- ----------------------------------------------------------------------------
create table if not exists public.perfiles (
  id        uuid primary key references auth.users (id) on delete cascade,
  rol       text not null default 'asesor' check (rol in ('admin', 'asesor')),
  nombre    text not null default 'Sin nombre',
  email     text,
  foto_url  text,
  created_at timestamptz not null default now()
);

comment on table public.perfiles is
  'Perfil de cada usuario. El rol modula accesos: admin gestiona finanzas, '
  'asesor es el técnico en campo.';

-- ----------------------------------------------------------------------------
-- 2) TABLA: clientes  (directorio normalizado)
-- ----------------------------------------------------------------------------
create table if not exists public.clientes (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  telefono    text,
  direccion   text,
  email       text,
  created_at  timestamptz not null default now()
);

comment on table public.clientes is
  'Directorio de clientes del taller. Un mismo cliente puede tener varias '
  'órdenes de trabajo a lo largo del tiempo (relación 1 -> N hacia '
  'ordenes_trabajo.cliente_id). El vehículo NO vive aquí: cada orden '
  'registra el auto sobre el que se trabajó en esa ocasión.';

create index if not exists clientes_nombre_idx on public.clientes (nombre);

-- ----------------------------------------------------------------------------
-- 3) TABLA: ordenes_trabajo
-- ----------------------------------------------------------------------------
-- Migración del nombre viejo: si existe `estimados` (esquema anterior),
-- renómbrala a `ordenes_trabajo` antes de crearla. Es idempotente.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'estimados'
  ) and not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'ordenes_trabajo'
  ) then
    alter table public.estimados rename to ordenes_trabajo;
  end if;
end $$;

create table if not exists public.ordenes_trabajo (
  id              uuid primary key default gen_random_uuid(),
  cliente_id      uuid not null references public.clientes (id) on delete restrict,
  vehiculo_marca  text,
  vehiculo_modelo text,
  vehiculo_anio   integer,
  vehiculo_vin    text,
  fotos_urls      jsonb not null default '[]'::jsonb,
  pdfs_urls       jsonb not null default '[]'::jsonb,
  notas           jsonb not null default '[]'::jsonb,
  monto_aprobado  numeric,
  estado_kanban   text not null default 'por_hacer'
                  check (estado_kanban in (
                    'por_hacer',
                    'listos_para_enviar',
                    'esperando_aprobacion',
                    'pendiente_trabajo',
                    'en_proceso',
                    'pendiente_pago'
                  )),
  archivado       boolean not null default false,
  created_at      timestamptz not null default now()
);

comment on table public.ordenes_trabajo is
  'Órdenes de trabajo del taller. Atraviesan todas las fases del flujo '
  '(desde "Por Hacer" en el Kanban de "Pendientes de Estimado" hasta '
  '"Pendiente de Pago"). El contacto del cliente se resuelve por '
  'cliente_id; el vehículo y todos los entregables (fotos, PDFs de '
  'cotización, notas, monto) son por-orden.';

create index if not exists ordenes_trabajo_estado_idx
  on public.ordenes_trabajo (estado_kanban);
create index if not exists ordenes_trabajo_archivado_idx
  on public.ordenes_trabajo (archivado);
create index if not exists ordenes_trabajo_cliente_idx
  on public.ordenes_trabajo (cliente_id);

-- Compatibilidad hacia adelante: si la tabla `ordenes_trabajo` existía con
-- el esquema viejo (denormalizado), agrega las columnas faltantes. Bloques
-- idempotentes — seguros de re-ejecutar.
alter table public.ordenes_trabajo
  add column if not exists cliente_id uuid references public.clientes (id) on delete restrict;
alter table public.ordenes_trabajo
  add column if not exists notas jsonb not null default '[]'::jsonb;

-- Si quedan columnas denormalizadas viejas, deja constancia para migración
-- manual de datos. Una vez que `cliente_id` esté poblado para todas las
-- filas, ejecuta a mano:
--   alter table public.ordenes_trabajo drop column if exists cliente_nombre;
--   alter table public.ordenes_trabajo drop column if exists telefono;
--   alter table public.ordenes_trabajo drop column if exists direccion;
-- (No las dropeamos automáticamente para no perder datos accidentalmente.)

-- ----------------------------------------------------------------------------
-- 4) ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.perfiles        enable row level security;
alter table public.clientes        enable row level security;
alter table public.ordenes_trabajo enable row level security;

-- Perfiles: cada usuario lee su propio perfil (el login lo necesita).
drop policy if exists "perfil_propio_select" on public.perfiles;
create policy "perfil_propio_select"
  on public.perfiles for select
  using (auth.uid() = id);

-- Perfiles: cada usuario puede actualizar su propio perfil (nombre, foto).
drop policy if exists "perfil_propio_update" on public.perfiles;
create policy "perfil_propio_update"
  on public.perfiles for update
  using (auth.uid() = id);

-- Clientes: cualquier usuario autenticado puede leer y escribir.
drop policy if exists "clientes_select" on public.clientes;
create policy "clientes_select"
  on public.clientes for select
  using (auth.role() = 'authenticated');

drop policy if exists "clientes_insert" on public.clientes;
create policy "clientes_insert"
  on public.clientes for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "clientes_update" on public.clientes;
create policy "clientes_update"
  on public.clientes for update
  using (auth.role() = 'authenticated');

-- Órdenes de trabajo: cualquier usuario autenticado puede leer y escribir.
-- Las restricciones por rol (asesor no ve "Pendiente de Pago", solo admin
-- archiva) se aplican en la interfaz. Para endurecer la seguridad a nivel
-- de base de datos, reemplaza estas políticas por reglas que comparen el
-- rol del usuario en `perfiles`.
drop policy if exists "ordenes_trabajo_select" on public.ordenes_trabajo;
create policy "ordenes_trabajo_select"
  on public.ordenes_trabajo for select
  using (auth.role() = 'authenticated');

drop policy if exists "ordenes_trabajo_insert" on public.ordenes_trabajo;
create policy "ordenes_trabajo_insert"
  on public.ordenes_trabajo for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "ordenes_trabajo_update" on public.ordenes_trabajo;
create policy "ordenes_trabajo_update"
  on public.ordenes_trabajo for update
  using (auth.role() = 'authenticated');

drop policy if exists "ordenes_trabajo_delete" on public.ordenes_trabajo;
create policy "ordenes_trabajo_delete"
  on public.ordenes_trabajo for delete
  using (auth.role() = 'authenticated');

-- Si quedaban políticas con el nombre viejo (de cuando la tabla se llamaba
-- `estimados`), límpialas para no acumular duplicadas.
drop policy if exists "estimados_select" on public.ordenes_trabajo;
drop policy if exists "estimados_insert" on public.ordenes_trabajo;
drop policy if exists "estimados_update" on public.ordenes_trabajo;
drop policy if exists "estimados_delete" on public.ordenes_trabajo;

-- ----------------------------------------------------------------------------
-- 5) TRIGGER: crear perfil automáticamente al registrarse un usuario
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, rol, nombre, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'rol', 'asesor'),
    coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)),
    new.email
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 6) REALTIME: emitir cambios por WebSocket
-- ----------------------------------------------------------------------------
-- Idempotente: si la tabla ya está en la publicación, ignora el error.
-- También quita la entrada vieja `estimados` si quedó remanente.
do $$
begin
  begin
    alter publication supabase_realtime drop table public.estimados;
  exception when undefined_table then null;
           when undefined_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.clientes;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.ordenes_trabajo;
  exception when duplicate_object then null;
  end;
end $$;

-- ============================================================================
--  DATOS INICIALES (opcional)
-- ----------------------------------------------------------------------------
--  Crea dos usuarios desde Authentication > Users en el panel de Supabase
--  (p. ej. admin@amilcar.com y asesor@amilcar.com). El trigger anterior les
--  creará un perfil con rol 'asesor'. Luego ajusta el rol del administrador:
--
--    update public.perfiles set rol = 'admin'
--      where email = 'admin@amilcar.com';
--
--  Ejemplo de cliente + orden de prueba (ya normalizada):
--
--    with nuevo_cliente as (
--      insert into public.clientes (nombre, telefono, direccion, email)
--      values ('Cliente Demo', '+502 0000 0000', 'Zona 10', 'demo@correo.com')
--      returning id
--    )
--    insert into public.ordenes_trabajo
--      (cliente_id, vehiculo_marca, vehiculo_modelo, vehiculo_anio,
--       estado_kanban, pdfs_urls)
--    select id, 'Toyota', 'Hilux', 2021, 'esperando_aprobacion',
--           '[{"titulo":"OEM","url":"demo.pdf","monto_sugerido":5000},
--             {"titulo":"Aftermarket","url":"demo2.pdf","monto_sugerido":3500}]'::jsonb
--    from nuevo_cliente;
-- ============================================================================
