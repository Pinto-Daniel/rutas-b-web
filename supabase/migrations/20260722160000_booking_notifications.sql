alter table public.bookings
  add column if not exists notification_claimed_at timestamptz,
  add column if not exists notification_sent_at timestamptz;

create or replace function public.submit_booking_request(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.routes;
  v_customer public.customers;
  v_existing public.bookings;
  v_booking public.bookings;
  v_email text := lower(trim(payload->>'email'));
  v_name text := trim(payload->>'name');
  v_date date;
begin
  if coalesce(payload->>'website', '') <> '' then raise exception 'invalid_request'; end if;
  if char_length(v_name) not between 2 and 120 then raise exception 'invalid_name'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid_email'; end if;
  v_date := (payload->>'date')::date;
  if v_date <= current_date then raise exception 'invalid_date'; end if;
  select * into v_route
  from public.routes
  where slug = payload->>'route'
    and status = 'published'
    and status_label = 'Ruta inicial';
  if not found then raise exception 'route_unavailable'; end if;

  insert into public.customers(full_name,email,phone)
  values(v_name,v_email,nullif(trim(payload->>'phone'),''))
  on conflict(email) do update set full_name=excluded.full_name, phone=coalesce(excluded.phone,customers.phone)
  returning * into v_customer;

  select * into v_existing from public.bookings
  where customer_id=v_customer.id and route_id=v_route.id and preferred_date=v_date
    and status in ('received','reviewing','confirmed') and created_at > now()-interval '15 minutes'
  order by created_at desc limit 1;
  if found then return jsonb_build_object('reference',v_existing.public_reference,'duplicate',true); end if;

  insert into public.bookings(customer_id,route_id,preferred_date,preferred_time,language,participant_count,modality,special_requests,privacy_accepted_at)
  values(v_customer.id,v_route.id,v_date,payload->>'time',payload->>'language',(payload->>'people')::integer,payload->>'modality',nullif(trim(payload->>'notes'),''),now())
  returning * into v_booking;
  return jsonb_build_object('reference',v_booking.public_reference,'duplicate',false);
end;
$$;

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
    and b.notification_sent_at is null
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
    'customer_phone', c.phone
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.release_booking_notification(p_reference text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.bookings
  set notification_claimed_at = null
  where public_reference = upper(trim(p_reference))
    and notification_sent_at is null;
$$;

create or replace function public.complete_booking_notification(p_reference text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.bookings
  set notification_sent_at = now()
  where public_reference = upper(trim(p_reference))
    and notification_sent_at is null;
$$;

revoke all on function public.claim_booking_notification(text) from public, anon, authenticated;
revoke all on function public.release_booking_notification(text) from public, anon, authenticated;
revoke all on function public.complete_booking_notification(text) from public, anon, authenticated;
grant execute on function public.claim_booking_notification(text) to service_role;
grant execute on function public.release_booking_notification(text) to service_role;
grant execute on function public.complete_booking_notification(text) to service_role;
