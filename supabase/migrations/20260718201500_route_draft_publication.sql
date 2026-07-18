-- Fase 5: separación entre borrador editorial y ruta pública.
-- No elimina rutas, reservas ni historial.

create table if not exists public.route_drafts (
  route_id uuid primary key references public.routes(id) on delete cascade,
  content jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.route_drafts enable row level security;
create policy "admin_route_drafts" on public.route_drafts
  using (public.is_active_admin()) with check (public.is_active_admin());

create trigger route_drafts_updated before update on public.route_drafts
  for each row execute function public.set_updated_at();

create or replace function public.save_route_draft(p_route_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.routes;
  v_content jsonb;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_payload->>'title', ''))) not between 2 and 160 then raise exception 'invalid_route_title' using errcode = '22023'; end if;
  select * into v_route from public.routes where id = p_route_id for update;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;
  v_content := jsonb_build_object(
    'title', trim(p_payload->>'title'),
    'eyebrow', nullif(trim(p_payload->>'eyebrow'), ''),
    'promise', nullif(trim(p_payload->>'promise'), ''),
    'full_description', nullif(trim(p_payload->>'full_description'), ''),
    'display_price_individual', nullif(trim(p_payload->>'display_price_individual'), '')
  );
  if v_route.status = 'draft' then
    update public.routes set title=v_content->>'title', eyebrow=v_content->>'eyebrow', promise=v_content->>'promise', full_description=v_content->>'full_description', display_price_individual=v_content->>'display_price_individual' where id=p_route_id;
  else
    insert into public.route_drafts(route_id, content) values (p_route_id, v_content)
    on conflict(route_id) do update set content=excluded.content;
  end if;
  insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
    values(auth.uid(), 'route_draft_saved', 'route', p_route_id::text, jsonb_build_object('is_new_route', v_route.status='draft'));
  return v_content;
end;
$$;

create or replace function public.publish_route_draft(p_route_id uuid)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.routes;
  v_draft public.route_drafts;
  v_result public.routes;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  select * into v_route from public.routes where id=p_route_id for update;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;
  select * into v_draft from public.route_drafts where route_id=p_route_id for update;
  if v_route.status <> 'draft' and not found then raise exception 'route_draft_required' using errcode = 'P0002'; end if;
  update public.routes set
    title = coalesce(v_draft.content->>'title', v_route.title),
    eyebrow = coalesce(v_draft.content->>'eyebrow', v_route.eyebrow),
    promise = coalesce(v_draft.content->>'promise', v_route.promise),
    full_description = coalesce(v_draft.content->>'full_description', v_route.full_description),
    display_price_individual = coalesce(v_draft.content->>'display_price_individual', v_route.display_price_individual),
    status = 'published'
  where id=p_route_id returning * into v_result;
  delete from public.route_drafts where route_id=p_route_id;
  insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
    values(auth.uid(), 'route_published', 'route', p_route_id::text, jsonb_build_object('had_draft', found));
  return v_result;
end;
$$;

revoke all on function public.save_route_draft(uuid, jsonb) from public, anon;
revoke all on function public.publish_route_draft(uuid) from public, anon;
grant execute on function public.save_route_draft(uuid, jsonb) to authenticated;
grant execute on function public.publish_route_draft(uuid) to authenticated;
