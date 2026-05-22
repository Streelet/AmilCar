-- ============================================================================
--  AmilCar · Esquema de base de datos para Supabase
-- ============================================================================
--  Ejecuta este script en el SQL Editor de tu proyecto Supabase ANTES de
--  cambiar AppConfig.useMockData a false.
--
--  Crea:
--   1. Tabla `perfiles`  (id, rol, nombre, foto_url) ligada a auth.users
--   2. Tabla `estimados` (modelo relacional del Kanban)
--   3. Políticas RLS
--   4. Trigger que crea el perfil automáticamente al registrarse un usuario
--   5. Realtime habilitado sobre `estimados`
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
-- 2) TABLA: estimados
-- ----------------------------------------------------------------------------
create table if not exists public.estimados (
  id              uuid primary key default gen_random_uuid(),
  cliente_nombre  text not null,
  telefono        text,
  direccion       text,
  vehiculo_marca  text,
  vehiculo_modelo text,
  vehiculo_anio   integer,
  vehiculo_vin    text,
  fotos_urls      jsonb not null default '[]'::jsonb,
  pdfs_urls       jsonb not null default '[]'::jsonb,
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

comment on table public.estimados is
  'Órdenes de servicio / estimados. fotos_urls = arreglo de rutas; '
  'pdfs_urls = arreglo de objetos {titulo, url, monto_sugerido}.';

create index if not exists estimados_estado_idx
  on public.estimados (estado_kanban);
create index if not exists estimados_archivado_idx
  on public.estimados (archivado);

-- ----------------------------------------------------------------------------
-- 3) ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.perfiles  enable row level security;
alter table public.estimados enable row level security;

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

-- Estimados: cualquier usuario autenticado puede leer y escribir.
-- Las restricciones por rol (asesor no ve "Pendiente de Pago", solo admin
-- archiva) se aplican en la interfaz. Para endurecer la seguridad a nivel
-- de base de datos, reemplaza estas políticas por reglas que comparen el
-- rol del usuario en `perfiles`.
drop policy if exists "estimados_select" on public.estimados;
create policy "estimados_select"
  on public.estimados for select
  using (auth.role() = 'authenticated');

drop policy if exists "estimados_insert" on public.estimados;
create policy "estimados_insert"
  on public.estimados for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "estimados_update" on public.estimados;
create policy "estimados_update"
  on public.estimados for update
  using (auth.role() = 'authenticated');

drop policy if exists "estimados_delete" on public.estimados;
create policy "estimados_delete"
  on public.estimados for delete
  using (auth.role() = 'authenticated');

-- ----------------------------------------------------------------------------
-- 4) TRIGGER: crear perfil automáticamente al registrarse un usuario
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
-- 5) REALTIME: emitir cambios de `estimados` por WebSocket
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table public.estimados;

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
--  Ejemplo de estimado de prueba:
--
--    insert into public.estimados
--      (cliente_nombre, telefono, direccion, vehiculo_marca, vehiculo_modelo,
--       vehiculo_anio, estado_kanban, pdfs_urls)
--    values
--      ('Cliente Demo', '+502 0000 0000', 'Zona 10', 'Toyota', 'Hilux', 2021,
--       'esperando_aprobacion',
--       '[{"titulo":"OEM","url":"demo.pdf","monto_sugerido":5000},
--         {"titulo":"Aftermarket","url":"demo2.pdf","monto_sugerido":3500}]'
--       ::jsonb);
-- ============================================================================
