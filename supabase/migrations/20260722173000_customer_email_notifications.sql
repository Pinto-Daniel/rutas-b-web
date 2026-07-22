alter table public.bookings
  add column if not exists customer_notification_sent_at timestamptz;

create or replace function public.claim_booking_notification(p_reference text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  update public.bookings b
  set notification_claimed_at = now()
  from public.customers c, public.routes r
  where b.public_reference = upper(trim(p_reference))
    and b.customer_id = c.id
    and b.route_id = r.id
    and (b.notification_sent_at is null or b.customer_notification_sent_at is null)
    and (b.notification_claimed_at is null or b.notification_claimed_at < now() - interval '10 minutes')
  returning jsonb_build_object(
    'reference', b.public_reference,
    'route_title', r.title,
    'preferred_date', b.preferred_date,
    'preferred_time', b.preferred_time,
    'language', b.language,
    'participant_count', b.participant_count,
    'modality', b.modality,
    'special_requests', b.special_requests,
    'customer_name', c.full_name,
    'customer_email', c.email,
    'customer_phone', c.phone,
    'admin_notification_pending', b.notification_sent_at is null,
    'customer_notification_pending', b.customer_notification_sent_at is null
  ) into v_result;
  return v_result;
end;
$$;

drop function if exists public.complete_booking_notification(text);

create function public.complete_booking_notification(
  p_reference text,
  p_admin_sent boolean,
  p_customer_sent boolean
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.bookings
  set notification_sent_at = case
        when p_admin_sent then coalesce(notification_sent_at, now())
        else notification_sent_at
      end,
      customer_notification_sent_at = case
        when p_customer_sent then coalesce(customer_notification_sent_at, now())
        else customer_notification_sent_at
      end,
      notification_claimed_at = null
  where public_reference = upper(trim(p_reference));
$$;

revoke all on function public.complete_booking_notification(text, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.complete_booking_notification(text, boolean, boolean)
  to service_role;
