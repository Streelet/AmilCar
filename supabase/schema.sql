-- ============================================================================
--  AmilCar · Esquema de base de datos para Supabase
-- ============================================================================
--  Ejecuta este script en el SQL Editor de tu proyecto Supabase ANTES de
--  cambiar AppConfig.useMockData a false.
--
--  Tablas:
--   1. perfiles         — usuarios + rol (ligada a auth.users)
--   2. clientes         — directorio normalizado
--   3. ordenes_trabajo  — modelo principal (FK -> clientes)
--   4. pagos            — pagos / anticipos (FK -> ordenes_trabajo)
--
--  Soft delete: clientes, ordenes_trabajo y pagos llevan `deleted_at`.
--  Las políticas SELECT lo filtran, así que las filas soft-deleted son
--  invisibles para el cliente vía API y realtime. La recuperación se hace
--  por SQL (set deleted_at = null).
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
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- Compat: agrega deleted_at si la tabla existía sin él.
alter table public.clientes
  add column if not exists deleted_at timestamptz;

comment on table public.clientes is
  'Directorio de clientes del taller. Un mismo cliente puede tener varias '
  'órdenes de trabajo a lo largo del tiempo (relación 1 -> N hacia '
  'ordenes_trabajo.cliente_id). El vehículo NO vive aquí: cada orden '
  'registra el auto sobre el que se trabajó en esa ocasión.';

create index if not exists clientes_nombre_idx on public.clientes (nombre);
create index if not exists clientes_activos_idx
  on public.clientes (id) where deleted_at is null;

-- ----------------------------------------------------------------------------
-- 3) TABLA: ordenes_trabajo
-- ----------------------------------------------------------------------------
-- Migración del nombre viejo: si existe `estimados`, renómbrala.
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
  created_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

-- Compat para tablas existentes.
alter table public.ordenes_trabajo
  add column if not exists cliente_id uuid references public.clientes (id) on delete restrict;
alter table public.ordenes_trabajo
  add column if not exists notas jsonb not null default '[]'::jsonb;
alter table public.ordenes_trabajo
  add column if not exists deleted_at timestamptz;

-- Marca el momento en que el estado cambió por última vez.
-- La llena el trigger `trg_ordenes_estado_updated_at` (ver sección 8).
-- Útil para saber cuándo una orden entró a "Pendiente de Pago", etc.
alter table public.ordenes_trabajo
  add column if not exists estado_updated_at timestamptz;

comment on table public.ordenes_trabajo is
  'Órdenes de trabajo del taller. Atraviesan todas las fases del flujo '
  '(desde "Por Hacer" en el Kanban hasta "Pendiente de Pago"). El '
  'contacto del cliente se resuelve por cliente_id; el vehículo y los '
  'entregables (fotos, PDFs, notas) son por-orden.';

create index if not exists ordenes_trabajo_estado_idx
  on public.ordenes_trabajo (estado_kanban);
create index if not exists ordenes_trabajo_archivado_idx
  on public.ordenes_trabajo (archivado);
create index if not exists ordenes_trabajo_cliente_idx
  on public.ordenes_trabajo (cliente_id);
create index if not exists ordenes_trabajo_activas_idx
  on public.ordenes_trabajo (id) where deleted_at is null;

-- ----------------------------------------------------------------------------
-- 4) TABLA: pagos
-- ----------------------------------------------------------------------------
create table if not exists public.pagos (
  id               uuid primary key default gen_random_uuid(),
  orden_id         uuid not null references public.ordenes_trabajo (id) on delete cascade,
  monto            numeric not null check (monto > 0),
  fecha            timestamptz not null default now(),
  metodo_pago      text not null default 'efectivo'
                   check (metodo_pago in (
                     'efectivo','cheque','tarjeta_credito',
                     'tarjeta_debito','zelle','otro'
                   )),
  metodo_pago_otro text,  -- descripción libre cuando metodo_pago = 'otro'
  notas            jsonb not null default '[]'::jsonb,
  created_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

comment on table public.pagos is
  'Pagos / anticipos registrados contra una orden de trabajo. La suma de '
  'pagos.monto vs ordenes_trabajo.monto_aprobado da el restante a cobrar. '
  'Cada pago lleva fecha, monto, método (enum) y notas (JSON array).';

-- Compatibilidad: agrega las columnas de método si la tabla existía antes.
alter table public.pagos
  add column if not exists metodo_pago text not null default 'efectivo';
alter table public.pagos
  add column if not exists metodo_pago_otro text;

-- Re-aplica el check constraint (idempotente).
alter table public.pagos drop constraint if exists pagos_metodo_pago_check;
alter table public.pagos add constraint pagos_metodo_pago_check
  check (metodo_pago in (
    'efectivo','cheque','tarjeta_credito',
    'tarjeta_debito','zelle','otro'
  ));

-- Columnas para CANCELAR un pago: la fila se conserva visible en la UI
-- (tachada) pero deja de contar para el saldo. Distinto de `deleted_at`
-- que oculta totalmente.
alter table public.pagos
  add column if not exists cancelado_at timestamptz;
alter table public.pagos
  add column if not exists motivo_cancelacion text;

create index if not exists pagos_orden_idx on public.pagos (orden_id);
create index if not exists pagos_fecha_idx on public.pagos (fecha desc);
create index if not exists pagos_activos_idx
  on public.pagos (id) where deleted_at is null;

-- ----------------------------------------------------------------------------
-- 5) ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.perfiles        enable row level security;
alter table public.clientes        enable row level security;
alter table public.ordenes_trabajo enable row level security;
alter table public.pagos           enable row level security;

-- Perfiles: cada usuario ve/edita su propio perfil.
drop policy if exists "perfil_propio_select" on public.perfiles;
create policy "perfil_propio_select"
  on public.perfiles for select using (auth.uid() = id);

drop policy if exists "perfil_propio_update" on public.perfiles;
create policy "perfil_propio_update"
  on public.perfiles for update using (auth.uid() = id);

-- ── Clientes ──────────────────────────────────────────────────────────────
-- SELECT esconde soft-deleted.
drop policy if exists "clientes_select" on public.clientes;
create policy "clientes_select"
  on public.clientes for select
  using (auth.role() = 'authenticated' and deleted_at is null);

drop policy if exists "clientes_insert" on public.clientes;
create policy "clientes_insert"
  on public.clientes for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "clientes_update" on public.clientes;
create policy "clientes_update"
  on public.clientes for update
  using (auth.role() = 'authenticated');

-- (Sin política DELETE: el borrado es soft via UPDATE deleted_at.)

-- ── Órdenes de trabajo ────────────────────────────────────────────────────
drop policy if exists "ordenes_trabajo_select" on public.ordenes_trabajo;
create policy "ordenes_trabajo_select"
  on public.ordenes_trabajo for select
  using (auth.role() = 'authenticated' and deleted_at is null);

drop policy if exists "ordenes_trabajo_insert" on public.ordenes_trabajo;
create policy "ordenes_trabajo_insert"
  on public.ordenes_trabajo for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "ordenes_trabajo_update" on public.ordenes_trabajo;
create policy "ordenes_trabajo_update"
  on public.ordenes_trabajo for update
  using (auth.role() = 'authenticated');

-- Limpieza de políticas legacy.
drop policy if exists "estimados_select" on public.ordenes_trabajo;
drop policy if exists "estimados_insert" on public.ordenes_trabajo;
drop policy if exists "estimados_update" on public.ordenes_trabajo;
drop policy if exists "estimados_delete" on public.ordenes_trabajo;
drop policy if exists "ordenes_trabajo_delete" on public.ordenes_trabajo;

-- ── Pagos ─────────────────────────────────────────────────────────────────
drop policy if exists "pagos_select" on public.pagos;
create policy "pagos_select"
  on public.pagos for select
  using (auth.role() = 'authenticated' and deleted_at is null);

drop policy if exists "pagos_insert" on public.pagos;
create policy "pagos_insert"
  on public.pagos for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "pagos_update" on public.pagos;
create policy "pagos_update"
  on public.pagos for update
  using (auth.role() = 'authenticated');

-- ----------------------------------------------------------------------------
-- 6) TRIGGER: crear perfil automáticamente al registrarse un usuario
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
-- 7) STORAGE: buckets para fotos de órdenes y PDFs de cotizaciones
-- ----------------------------------------------------------------------------
-- Buckets públicos: las URLs son opacas (incluyen uuid aleatorio + path con
-- el id de orden), así que no se enumeran. Los archivos quedan accesibles
-- por quien tenga el link. Si en el futuro hace falta restringir, se
-- pueden migrar a buckets privados con `signed URLs`.
insert into storage.buckets (id, name, public)
values ('fotos-ordenes', 'fotos-ordenes', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('cotizaciones-pdf', 'cotizaciones-pdf', true)
on conflict (id) do nothing;

-- Políticas RLS sobre `storage.objects`. Solo usuarios autenticados pueden
-- subir/leer; lectura pública adicional para que las URLs cargue cualquier
-- visor (PDF/Image) sin token.
drop policy if exists "amilcar_storage_select" on storage.objects;
create policy "amilcar_storage_select"
  on storage.objects for select
  using (bucket_id in ('fotos-ordenes','cotizaciones-pdf'));

drop policy if exists "amilcar_storage_insert" on storage.objects;
create policy "amilcar_storage_insert"
  on storage.objects for insert
  with check (
    bucket_id in ('fotos-ordenes','cotizaciones-pdf')
    and auth.role() = 'authenticated'
  );

drop policy if exists "amilcar_storage_update" on storage.objects;
create policy "amilcar_storage_update"
  on storage.objects for update
  using (
    bucket_id in ('fotos-ordenes','cotizaciones-pdf')
    and auth.role() = 'authenticated'
  );

drop policy if exists "amilcar_storage_delete" on storage.objects;
create policy "amilcar_storage_delete"
  on storage.objects for delete
  using (
    bucket_id in ('fotos-ordenes','cotizaciones-pdf')
    and auth.role() = 'authenticated'
  );

-- ----------------------------------------------------------------------------
-- 8) TRIGGER: estado_updated_at
-- ----------------------------------------------------------------------------
-- Cada vez que `estado_kanban` cambia, Postgres rellena `estado_updated_at`
-- automáticamente. La app no necesita enviarlo: el trigger lo gestiona.
-- Funciona tanto desde la app como desde el SQL Editor (útil en migraciones).
-- ----------------------------------------------------------------------------
create or replace function public.set_estado_updated_at()
returns trigger language plpgsql as $$
begin
  -- Solo actualiza si el estado realmente cambió.
  if new.estado_kanban is distinct from old.estado_kanban then
    new.estado_updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ordenes_estado_updated_at on public.ordenes_trabajo;
create trigger trg_ordenes_estado_updated_at
  before update on public.ordenes_trabajo
  for each row execute function public.set_estado_updated_at();

-- ----------------------------------------------------------------------------
-- 9) TABLA: audit_log  (registro de actividad por usuario)
-- ----------------------------------------------------------------------------
-- Guarda las acciones relevantes: login, cambios de estado, pagos, archivos…
-- El campo `datos` es JSONB libre para contexto adicional (vehículo, montos…).
--
-- Política SELECT:  solo admin puede leer todos los registros.
-- Política INSERT:  cualquier usuario autenticado puede insertar el suyo.
--                   `usuario_id` debe ser nulo o coincidir con auth.uid().
-- No hay UPDATE ni DELETE desde la app; el historial es inmutable.
-- ----------------------------------------------------------------------------
create table if not exists public.audit_log (
  id             uuid        primary key default gen_random_uuid(),
  created_at     timestamptz not null    default now(),
  usuario_id     uuid        references auth.users(id) on delete set null,
  usuario_email  text,
  accion         text        not null,
  entidad        text,
  entidad_id     text,
  datos          jsonb,
  plataforma     text
);

-- Índices para las consultas habituales del dashboard de actividad.
create index if not exists audit_log_created_at_idx
  on public.audit_log (created_at desc);
create index if not exists audit_log_usuario_id_idx
  on public.audit_log (usuario_id);
create index if not exists audit_log_accion_idx
  on public.audit_log (accion);

comment on table public.audit_log is
  'Registro inmutable de acciones de usuario. Solo admin puede leer; '
  'cualquier usuario autenticado puede insertar sus propias entradas. '
  'No se permite UPDATE ni DELETE desde la app.';

-- RLS
alter table public.audit_log enable row level security;

-- Admin lee todos los registros
drop policy if exists "admin lee audit_log" on public.audit_log;
create policy "admin lee audit_log"
  on public.audit_log for select
  to authenticated
  using (
    exists (
      select 1 from public.perfiles
      where id = auth.uid() and rol = 'admin'
    )
  );

-- Cualquier usuario autenticado puede insertar su propio registro
drop policy if exists "authenticated inserta audit_log" on public.audit_log;
create policy "authenticated inserta audit_log"
  on public.audit_log for insert
  to authenticated
  with check (
    usuario_id = auth.uid() or usuario_id is null
  );

-- Realtime para el panel de actividad (admin lo observa en tiempo real)
-- Se agrega en el bloque DO de abajo junto con las demás tablas.

-- ----------------------------------------------------------------------------
-- 10) REALTIME: emitir cambios por WebSocket
-- ----------------------------------------------------------------------------
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
  begin
    alter publication supabase_realtime add table public.pagos;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.audit_log;
  exception when duplicate_object then null;
  end;
end $$;

-- ============================================================================
--  RECUPERACIÓN DE FILAS SOFT-DELETED (sólo admin, vía SQL Editor)
-- ----------------------------------------------------------------------------
--  Las políticas SELECT filtran `deleted_at is null`, así que las filas
--  borradas suaves son invisibles desde la app. Para recuperar:
--
--    update public.clientes        set deleted_at = null where id = '...';
--    update public.ordenes_trabajo set deleted_at = null where id = '...';
--    update public.pagos           set deleted_at = null where id = '...';
--
--  Para ver lo borrado (bypass RLS desde el SQL Editor, que usa
--  service_role):
--
--    select * from public.clientes where deleted_at is not null;
-- ============================================================================
