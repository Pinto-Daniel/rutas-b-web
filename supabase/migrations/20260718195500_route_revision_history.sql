-- Fase 4B: historial reversible de campos editoriales de rutas.
-- No elimina rutas ni reservas.

create or replace function public.manage_route(p_route_id uuid, p_payload jsonb)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.routes;
  v_after public.routes;
  v_before_snapshot jsonb;
  v_after_snapshot jsonb;
begin
  if not public.is_active_admin() then
    raise exception 'admin_access_required' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_payload->>'title', ''))) not between 2 and 160 then
    raise exception 'invalid_route_title' using errcode = '22023';
  end if;
  if coalesce(p_payload->>'status', '') not in ('draft', 'published', 'inactive') then
    raise exception 'invalid_route_status' using errcode = '22023';
  end if;

  select * into v_before from public.routes where id = p_route_id for update;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;

  v_before_snapshot := jsonb_build_object(
    'title', v_before.title,
    'eyebrow', v_before.eyebrow,
    'promise', v_before.promise,
    'full_description', v_before.full_description,
    'display_price_individual', v_before.display_price_individual,
    'status', v_before.status
  );

  update public.routes
  set title = trim(p_payload->>'title'),
      eyebrow = nullif(trim(p_payload->>'eyebrow'), ''),
      promise = nullif(trim(p_payload->>'promise'), ''),
      full_description = nullif(trim(p_payload->>'full_description'), ''),
      display_price_individual = nullif(trim(p_payload->>'display_price_individual'), ''),
      status = (p_payload->>'status')::public.route_status
  where id = p_route_id
  returning * into v_after;

  v_after_snapshot := jsonb_build_object(
    'title', v_after.title,
    'eyebrow', v_after.eyebrow,
    'promise', v_after.promise,
    'full_description', v_after.full_description,
    'display_price_individual', v_after.display_price_individual,
    'status', v_after.status
  );

  if v_before_snapshot is distinct from v_after_snapshot then
    insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'route_updated', 'route', p_route_id::text,
      jsonb_build_object('before', v_before_snapshot, 'after', v_after_snapshot));
  end if;
  return v_after;
end;
$$;

create or replace function public.revert_route_revision(p_audit_id bigint)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revision public.audit_log;
  v_target public.routes;
  v_before jsonb;
begin
  if not public.is_active_admin() then
    raise exception 'admin_access_required' using errcode = '42501';
  end if;
  select * into v_revision from public.audit_log
  where id = p_audit_id and action = 'route_updated' and entity_type = 'route'
  for update;
  if not found then raise exception 'route_revision_not_found' using errcode = 'P0002'; end if;
  v_before := v_revision.details->'before';
  update public.routes
  set title = v_before->>'title',
      eyebrow = nullif(v_before->>'eyebrow', ''),
      promise = nullif(v_before->>'promise', ''),
      full_description = nullif(v_before->>'full_description', ''),
      display_price_individual = nullif(v_before->>'display_price_individual', ''),
      status = (v_before->>'status')::public.route_status
  where id = v_revision.entity_id::uuid
  returning * into v_target;
  insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'route_revision_reverted', 'route', v_target.id::text,
    jsonb_build_object('reverted_audit_id', p_audit_id));
  return v_target;
end;
$$;

revoke all on function public.manage_route(uuid, jsonb) from public, anon;
revoke all on function public.revert_route_revision(bigint) from public, anon;
grant execute on function public.manage_route(uuid, jsonb) to authenticated;
grant execute on function public.revert_route_revision(bigint) to authenticated;
