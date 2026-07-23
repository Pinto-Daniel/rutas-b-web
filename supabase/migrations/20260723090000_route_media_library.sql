-- Fase 6: biblioteca multimedia editorial para rutas.
-- Añade fotos y documentos con borrador, publicación y retirada reversible.
-- No elimina archivos, rutas ni reservas existentes.

create table if not exists public.route_media (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  kind text not null check (kind in ('image', 'document', 'audio', 'map')),
  role text not null check (role in ('hero', 'gallery', 'attachment')),
  storage_path text not null unique,
  title text,
  alt_text text,
  mime_type text not null,
  file_size_bytes bigint not null check (file_size_bytes > 0 and file_size_bytes <= 26214400),
  status text not null default 'draft' check (status in ('draft', 'published', 'pending_removal', 'archived')),
  sort_order integer not null default 0,
  created_by uuid default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.route_media enable row level security;

drop policy if exists "admin_route_media" on public.route_media;
create policy "admin_route_media" on public.route_media
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists "public_published_route_media" on public.route_media;
create policy "public_published_route_media" on public.route_media
  for select
  using (
    status in ('published', 'pending_removal')
    and exists (
      select 1 from public.routes
      where routes.id = route_media.route_id
        and routes.status = 'published'
    )
  );

drop trigger if exists route_media_updated on public.route_media;
create trigger route_media_updated
before update on public.route_media
for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'route-media',
  'route-media',
  true,
  26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/avif',
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'audio/mpeg', 'audio/mp4'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "admin_upload_route_media" on storage.objects;
create policy "admin_upload_route_media" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'route-media' and public.is_active_admin());

drop policy if exists "admin_update_route_media_files" on storage.objects;
create policy "admin_update_route_media_files" on storage.objects
  for update to authenticated
  using (bucket_id = 'route-media' and public.is_active_admin())
  with check (bucket_id = 'route-media' and public.is_active_admin());

drop policy if exists "admin_delete_route_media_files" on storage.objects;
create policy "admin_delete_route_media_files" on storage.objects
  for delete to authenticated
  using (bucket_id = 'route-media' and public.is_active_admin());

drop policy if exists "public_read_route_media_files" on storage.objects;
create policy "public_read_route_media_files" on storage.objects
  for select
  using (
    bucket_id = 'route-media'
    and exists (
      select 1 from public.route_media
      where route_media.storage_path = storage.objects.name
        and route_media.status in ('published', 'pending_removal')
    )
  );

create or replace function public.register_route_media(
  p_route_id uuid,
  p_kind text,
  p_role text,
  p_storage_path text,
  p_title text,
  p_alt_text text,
  p_mime_type text,
  p_file_size_bytes bigint
)
returns public.route_media
language plpgsql
security definer
set search_path = public
as $$
declare
  v_media public.route_media;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  if p_kind not in ('image', 'document', 'audio', 'map') then raise exception 'invalid_media_kind' using errcode = '22023'; end if;
  if p_role not in ('hero', 'gallery', 'attachment') then raise exception 'invalid_media_role' using errcode = '22023'; end if;
  if p_kind = 'image' and coalesce(trim(p_alt_text), '') = '' then raise exception 'image_alt_required' using errcode = '22023'; end if;
  if p_file_size_bytes <= 0 or p_file_size_bytes > 26214400 then raise exception 'invalid_media_size' using errcode = '22023'; end if;
  if not exists(select 1 from public.routes where id = p_route_id) then raise exception 'route_not_found' using errcode = 'P0002'; end if;

  if p_role = 'hero' then
    update public.route_media
      set status = 'archived'
      where route_id = p_route_id and role = 'hero' and status = 'draft';
  end if;

  insert into public.route_media(route_id, kind, role, storage_path, title, alt_text, mime_type, file_size_bytes)
  values (p_route_id, p_kind, p_role, p_storage_path, nullif(trim(p_title), ''), nullif(trim(p_alt_text), ''), p_mime_type, p_file_size_bytes)
  returning * into v_media;

  insert into public.audit_log(admin_id, action, entity_type, entity_id, details)
  values(auth.uid(), 'route_media_registered', 'route', p_route_id::text,
    jsonb_build_object('media_id', v_media.id, 'kind', v_media.kind, 'role', v_media.role));
  return v_media;
end;
$$;

create or replace function public.stage_route_media_removal(p_media_id uuid)
returns public.route_media
language plpgsql
security definer
set search_path = public
as $$
declare
  v_media public.route_media;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  update public.route_media
  set status = case when status = 'published' then 'pending_removal' else 'archived' end
  where id = p_media_id and status in ('draft', 'published')
  returning * into v_media;
  if not found then raise exception 'route_media_not_found' using errcode = 'P0002'; end if;
  return v_media;
end;
$$;

create or replace function public.cancel_route_media_removal(p_media_id uuid)
returns public.route_media
language plpgsql
security definer
set search_path = public
as $$
declare
  v_media public.route_media;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  update public.route_media set status = 'published'
  where id = p_media_id and status = 'pending_removal'
  returning * into v_media;
  if not found then raise exception 'route_media_not_found' using errcode = 'P0002'; end if;
  return v_media;
end;
$$;

revoke all on function public.register_route_media(uuid, text, text, text, text, text, text, bigint) from public, anon;
revoke all on function public.stage_route_media_removal(uuid) from public, anon;
revoke all on function public.cancel_route_media_removal(uuid) from public, anon;
grant execute on function public.register_route_media(uuid, text, text, text, text, text, text, bigint) to authenticated;
grant execute on function public.stage_route_media_removal(uuid) to authenticated;
grant execute on function public.cancel_route_media_removal(uuid) to authenticated;

create or replace function public.publish_route_draft(p_route_id uuid)
returns public.routes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.routes;
  v_draft public.route_drafts;
  v_has_draft boolean;
  v_has_media_changes boolean;
  v_new_hero public.route_media;
  v_remove_current_hero boolean;
  v_before_snapshot jsonb;
  v_after_snapshot jsonb;
  v_media_before jsonb;
  v_media_after jsonb;
  v_result public.routes;
begin
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  select * into v_route from public.routes where id = p_route_id for update;
  if not found then raise exception 'route_not_found' using errcode = 'P0002'; end if;
  select exists(select 1 from public.route_drafts where route_id = p_route_id) into v_has_draft;
  if v_has_draft then select * into v_draft from public.route_drafts where route_id = p_route_id for update; end if;
  select exists(select 1 from public.route_media where route_id = p_route_id and status in ('draft', 'pending_removal')) into v_has_media_changes;
  if v_route.status <> 'draft' and not v_has_draft and not v_has_media_changes then raise exception 'route_draft_required' using errcode = 'P0002'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'status', status) order by id), '[]'::jsonb)
  into v_media_before from public.route_media where route_id = p_route_id;
  select * into v_new_hero from public.route_media where route_id = p_route_id and role = 'hero' and status = 'draft' order by created_at desc limit 1;
  select exists(select 1 from public.route_media where route_id = p_route_id and role = 'hero' and storage_path = v_route.primary_image_path and status = 'pending_removal') into v_remove_current_hero;

  v_before_snapshot := jsonb_build_object('title',v_route.title,'eyebrow',v_route.eyebrow,'promise',v_route.promise,'full_description',v_route.full_description,'display_price_individual',v_route.display_price_individual,'primary_image_path',v_route.primary_image_path,'primary_image_alt',v_route.primary_image_alt,'status',v_route.status);
  update public.routes set
    title = case when v_has_draft then coalesce(v_draft.content->>'title',v_route.title) else v_route.title end,
    eyebrow = case when v_has_draft then coalesce(v_draft.content->>'eyebrow',v_route.eyebrow) else v_route.eyebrow end,
    promise = case when v_has_draft then coalesce(v_draft.content->>'promise',v_route.promise) else v_route.promise end,
    full_description = case when v_has_draft then coalesce(v_draft.content->>'full_description',v_route.full_description) else v_route.full_description end,
    display_price_individual = case when v_has_draft then coalesce(v_draft.content->>'display_price_individual',v_route.display_price_individual) else v_route.display_price_individual end,
    primary_image_path = case when v_new_hero.id is not null then v_new_hero.storage_path when v_remove_current_hero then null else v_route.primary_image_path end,
    primary_image_alt = case when v_new_hero.id is not null then v_new_hero.alt_text when v_remove_current_hero then null else v_route.primary_image_alt end,
    status = 'published'
  where id = p_route_id returning * into v_result;

  if v_new_hero.id is not null then update public.route_media set status='archived' where route_id=p_route_id and role='hero' and status='published'; end if;
  update public.route_media set status='archived' where route_id=p_route_id and status='pending_removal';
  update public.route_media set status='published' where route_id=p_route_id and status='draft';
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'status', status) order by id), '[]'::jsonb) into v_media_after from public.route_media where route_id=p_route_id;
  v_after_snapshot := jsonb_build_object('title',v_result.title,'eyebrow',v_result.eyebrow,'promise',v_result.promise,'full_description',v_result.full_description,'display_price_individual',v_result.display_price_individual,'primary_image_path',v_result.primary_image_path,'primary_image_alt',v_result.primary_image_alt,'status',v_result.status);
  if v_before_snapshot is distinct from v_after_snapshot or v_media_before is distinct from v_media_after then
    insert into public.audit_log(admin_id,action,entity_type,entity_id,details) values(auth.uid(),'route_updated','route',p_route_id::text,jsonb_build_object('before',v_before_snapshot,'after',v_after_snapshot,'media_before',v_media_before,'media_after',v_media_after,'source','editorial_publication'));
  end if;
  delete from public.route_drafts where route_id=p_route_id;
  return v_result;
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
  if not public.is_active_admin() then raise exception 'admin_access_required' using errcode = '42501'; end if;
  select * into v_revision from public.audit_log where id=p_audit_id and action='route_updated' and entity_type='route' for update;
  if not found then raise exception 'route_revision_not_found' using errcode = 'P0002'; end if;
  v_before := v_revision.details->'before';
  update public.routes set title=v_before->>'title',eyebrow=nullif(v_before->>'eyebrow',''),promise=nullif(v_before->>'promise',''),full_description=nullif(v_before->>'full_description',''),display_price_individual=nullif(v_before->>'display_price_individual',''),primary_image_path=case when v_before ? 'primary_image_path' then nullif(v_before->>'primary_image_path','') else primary_image_path end,primary_image_alt=case when v_before ? 'primary_image_alt' then nullif(v_before->>'primary_image_alt','') else primary_image_alt end,status=(v_before->>'status')::public.route_status where id=v_revision.entity_id::uuid returning * into v_target;
  if jsonb_typeof(v_revision.details->'media_before')='array' then
    update public.route_media media set status=previous.status from jsonb_to_recordset(v_revision.details->'media_before') as previous(id uuid,status text) where media.id=previous.id;
    update public.route_media media set status='draft' where media.route_id=v_target.id and media.id in (select current_media.id from jsonb_to_recordset(v_revision.details->'media_after') as current_media(id uuid,status text)) and media.id not in (select previous_media.id from jsonb_to_recordset(v_revision.details->'media_before') as previous_media(id uuid,status text));
  end if;
  insert into public.audit_log(admin_id,action,entity_type,entity_id,details) values(auth.uid(),'route_revision_reverted','route',v_target.id::text,jsonb_build_object('reverted_audit_id',p_audit_id));
  return v_target;
end;
$$;

revoke all on function public.publish_route_draft(uuid) from public, anon;
revoke all on function public.revert_route_revision(bigint) from public, anon;
grant execute on function public.publish_route_draft(uuid) to authenticated;
grant execute on function public.revert_route_revision(bigint) to authenticated;