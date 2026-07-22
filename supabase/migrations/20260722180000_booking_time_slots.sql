alter table public.bookings
  drop constraint if exists bookings_preferred_time_check;

alter table public.bookings
  add constraint bookings_preferred_time_check check (
    preferred_time = any (array[
      'morning'::text,
      'midday'::text,
      'afternoon'::text,
      'flexible'::text,
      '10:00'::text,
      '12:00'::text,
      '18:00'::text,
      '22:00'::text
    ])
  );

create or replace function public.validate_new_booking_time_slot()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_is_weekend boolean := extract(isodow from new.preferred_date) in (6, 7);
begin
  if new.preferred_time in ('18:00', '22:00') then
    return new;
  end if;
  if v_is_weekend and new.preferred_time in ('10:00', '12:00') then
    return new;
  end if;
  raise exception 'invalid_time_slot';
end;
$$;

drop trigger if exists validate_new_booking_time_slot on public.bookings;
create trigger validate_new_booking_time_slot
before insert on public.bookings
for each row execute function public.validate_new_booking_time_slot();
