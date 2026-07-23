update public.routes
set status_label = 'Disponible',
    display_duration = '75 minutos aprox.',
    duration_minutes_min = 75,
    duration_minutes_max = 75
where slug = 'sagrada-familia';

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
    and status_label in ('Ruta inicial', 'Disponible');
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
