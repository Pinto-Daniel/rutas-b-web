-- Fase 4A: base editorial para rutas. No elimina ni reemplaza rutas existentes.
-- Se aplicará solo después de revisión explícita.

alter table public.routes
  add column if not exists eyebrow text,
  add column if not exists promise text,
  add column if not exists status_label text,
  add column if not exists display_duration text,
  add column if not exists display_format text,
  add column if not exists display_area text,
  add column if not exists display_starting_point text,
  add column if not exists display_ending_point text,
  add column if not exists audience text[] not null default '{}',
  add column if not exists display_price_individual text,
  add column if not exists display_price_group text,
  add column if not exists primary_image_path text,
  add column if not exists primary_image_alt text;

create table if not exists public.route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 300),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (route_id, sort_order)
);

create index if not exists route_stops_route_sort_idx
  on public.route_stops(route_id, sort_order);

alter table public.route_stops enable row level security;
create policy "admin_route_stops" on public.route_stops
  using (public.is_active_admin()) with check (public.is_active_admin());
create policy "public_route_stops" on public.route_stops for select
  using (exists (
    select 1 from public.routes r
    where r.id = route_stops.route_id and r.status = 'published'
  ));

grant select, insert, update, delete on public.route_stops to authenticated;
grant select on public.route_stops to anon;

create or replace function public.duplicate_route(p_route_id uuid, p_new_title text)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source public.routes;
  v_copy public.routes;
  v_slug text;
begin
  if not public.is_active_admin() then
    raise exception 'admin_access_required' using errcode = '42501';
  end if;
  if char_length(trim(p_new_title)) not between 2 and 160 then
    raise exception 'invalid_route_title' using errcode = '22023';
  end if;
  select * into v_source from public.routes where id = p_route_id;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;
  v_slug := regexp_replace(lower(trim(p_new_title)), '[^a-z0-9]+', '-', 'g');
  v_slug := trim(both '-' from v_slug) || '-' || substr(encode(extensions.gen_random_bytes(3), 'hex'), 1, 6);
  insert into public.routes (
    slug, title, short_description, full_description, duration_minutes_min, duration_minutes_max,
    offered_languages, meeting_point_public, meeting_point_private, accessibility, includes, excludes,
    min_participants, max_participants, status, featured, sort_order, eyebrow, promise, status_label,
    display_duration, display_format, display_area, display_starting_point, display_ending_point,
    audience, display_price_individual, display_price_group, primary_image_path, primary_image_alt
  )
  select v_slug, trim(p_new_title), short_description, full_description, duration_minutes_min, duration_minutes_max,
    offered_languages, meeting_point_public, meeting_point_private, accessibility, includes, excludes,
    min_participants, max_participants, 'draft', false, sort_order + 1, eyebrow, promise, 'Borrador',
    display_duration, display_format, display_area, display_starting_point, display_ending_point,
    audience, display_price_individual, display_price_group, primary_image_path, primary_image_alt
  from public.routes where id = p_route_id returning * into v_copy;
  insert into public.route_stops(route_id, title, sort_order)
    select v_copy.id, title, sort_order from public.route_stops where route_id = p_route_id;
  insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
    values(auth.uid(), 'route_duplicated', 'route', v_copy.id::text, jsonb_build_object('source_route_id', p_route_id));
  return v_copy;
end;
$$;

revoke all on function public.duplicate_route(uuid, text) from public, anon;
grant execute on function public.duplicate_route(uuid, text) to authenticated;
