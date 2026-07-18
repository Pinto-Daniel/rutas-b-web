-- Fase 5B: cada publicación queda registrada como una revisión reversible.
-- No elimina rutas, borradores ni reservas.

create or replace function public.publish_route_draft(p_route_id uuid)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.routes;
  v_draft public.route_drafts;
  v_before_snapshot jsonb;
  v_after_snapshot jsonb;
  v_result public.routes;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  select * into v_route from public.routes where id=p_route_id for update;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;
  select * into v_draft from public.route_drafts where route_id=p_route_id for update;
  if v_route.status <> 'draft' and not found then raise exception 'route_draft_required' using errcode = 'P0002'; end if;

  v_before_snapshot := jsonb_build_object(
    'title', v_route.title,
    'eyebrow', v_route.eyebrow,
    'promise', v_route.promise,
    'full_description', v_route.full_description,
    'display_price_individual', v_route.display_price_individual,
    'status', v_route.status
  );

  update public.routes set
    title = coalesce(v_draft.content->>'title', v_route.title),
    eyebrow = coalesce(v_draft.content->>'eyebrow', v_route.eyebrow),
    promise = coalesce(v_draft.content->>'promise', v_route.promise),
    full_description = coalesce(v_draft.content->>'full_description', v_route.full_description),
    display_price_individual = coalesce(v_draft.content->>'display_price_individual', v_route.display_price_individual),
    status = 'published'
  where id=p_route_id returning * into v_result;

  v_after_snapshot := jsonb_build_object(
    'title', v_result.title,
    'eyebrow', v_result.eyebrow,
    'promise', v_result.promise,
    'full_description', v_result.full_description,
    'display_price_individual', v_result.display_price_individual,
    'status', v_result.status
  );

  if v_before_snapshot is distinct from v_after_snapshot then
    insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'route_updated', 'route', p_route_id::text,
      jsonb_build_object('before', v_before_snapshot, 'after', v_after_snapshot, 'source', 'draft_publication'));
  end if;
  delete from public.route_drafts where route_id=p_route_id;
  return v_result;
end;
$$;
