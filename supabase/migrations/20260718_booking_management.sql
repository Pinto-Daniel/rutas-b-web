-- Fase 1: gestión administrativa segura de reservas.
-- No elimina ni modifica reservas existentes.

create or replace function public.manage_booking(
  p_booking_id uuid,
  p_status public.booking_status,
  p_internal_notes text
) returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current public.bookings;
  v_result public.bookings;
  v_status_changed boolean;
  v_notes_changed boolean;
begin
  if not public.is_active_admin() then
    raise exception 'admin_access_required' using errcode = '42501';
  end if;
  if char_length(coalesce(p_internal_notes, '')) > 5000 then
    raise exception 'internal_notes_too_long' using errcode = '22001';
  end if;
  select * into v_current from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  if p_status is distinct from v_current.status and not (
    (v_current.status = 'received' and p_status in ('reviewing', 'confirmed', 'cancelled')) or
    (v_current.status = 'reviewing' and p_status in ('received', 'confirmed', 'cancelled')) or
    (v_current.status = 'confirmed' and p_status in ('reviewing', 'cancelled', 'completed'))
  ) then raise exception 'invalid_booking_status_transition' using errcode = '22023'; end if;
  v_status_changed := p_status is distinct from v_current.status;
  v_notes_changed := coalesce(p_internal_notes, '') is distinct from coalesce(v_current.internal_notes, '');
  update public.bookings set status = p_status, internal_notes = nullif(trim(p_internal_notes), '') where id = p_booking_id returning * into v_result;
  if v_status_changed or v_notes_changed then
    insert into public.audit_log (admin_id, action, entity_type, entity_id, details)
    values (auth.uid(), case when v_status_changed then 'booking_updated' else 'booking_notes_updated' end, 'booking', p_booking_id::text,
      jsonb_build_object('previous_status', v_current.status, 'new_status', p_status, 'notes_changed', v_notes_changed));
  end if;
  return v_result;
end;
$$;

revoke all on function public.manage_booking(uuid, public.booking_status, text) from public, anon;
grant execute on function public.manage_booking(uuid, public.booking_status, text) to authenticated;
create index if not exists audit_log_booking_created_idx on public.audit_log (entity_type, entity_id, created_at desc);
