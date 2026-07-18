


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."booking_status" AS ENUM (
    'received',
    'reviewing',
    'confirmed',
    'rejected',
    'cancelled',
    'completed'
);


ALTER TYPE "public"."booking_status" OWNER TO "postgres";


CREATE TYPE "public"."review_status" AS ENUM (
    'pending',
    'published',
    'rejected'
);


ALTER TYPE "public"."review_status" OWNER TO "postgres";


CREATE TYPE "public"."route_status" AS ENUM (
    'draft',
    'published',
    'inactive'
);


ALTER TYPE "public"."route_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_active_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$ select exists(select 1 from public.admin_profiles where id = auth.uid() and active); $$;


ALTER FUNCTION "public"."is_active_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ begin new.updated_at = now(); return new; end; $$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_booking_request"("payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
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
  select * into v_route from public.routes where slug = payload->>'route' and status = 'published';
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
end; $_$;


ALTER FUNCTION "public"."submit_booking_request"("payload" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admin_profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."admin_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_log" (
    "id" bigint NOT NULL,
    "admin_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "text",
    "details" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_log" OWNER TO "postgres";


ALTER TABLE "public"."audit_log" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."audit_log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "public_reference" "text" DEFAULT "upper"("substr"("encode"("extensions"."gen_random_bytes"(8), 'hex'::"text"), 1, 10)) NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "route_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "schedule_id" "uuid",
    "preferred_date" "date" NOT NULL,
    "preferred_time" "text" NOT NULL,
    "language" "text" NOT NULL,
    "participant_count" integer NOT NULL,
    "modality" "text" NOT NULL,
    "special_requests" "text",
    "privacy_accepted_at" timestamp with time zone NOT NULL,
    "status" "public"."booking_status" DEFAULT 'received'::"public"."booking_status" NOT NULL,
    "internal_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "bookings_language_check" CHECK (("language" = ANY (ARRAY['es'::"text", 'en'::"text"]))),
    CONSTRAINT "bookings_modality_check" CHECK (("modality" = ANY (ARRAY['shared'::"text", 'private'::"text", 'partner'::"text"]))),
    CONSTRAINT "bookings_participant_count_check" CHECK ((("participant_count" >= 1) AND ("participant_count" <= 50))),
    CONSTRAINT "bookings_preferred_time_check" CHECK (("preferred_time" = ANY (ARRAY['morning'::"text", 'midday'::"text", 'afternoon'::"text", 'flexible'::"text"]))),
    CONSTRAINT "bookings_special_requests_check" CHECK (("char_length"("special_requests") <= 1000))
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "full_name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "phone" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid",
    "booking_id" "uuid",
    "subject" "text",
    "body" "text" NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "messages_body_check" CHECK ((("char_length"("body") >= 1) AND ("char_length"("body") <= 3000)))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "display_name" "text",
    "accessibility_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "amount_cents" integer,
    "currency" character(3) DEFAULT 'EUR'::"bpchar" NOT NULL,
    "unit" "text" NOT NULL,
    "label" "text",
    "valid_from" "date",
    "valid_until" "date",
    "public" boolean DEFAULT false NOT NULL,
    CONSTRAINT "prices_amount_cents_check" CHECK (("amount_cents" >= 0)),
    CONSTRAINT "prices_check" CHECK ((("valid_until" IS NULL) OR ("valid_from" IS NULL) OR ("valid_until" >= "valid_from"))),
    CONSTRAINT "prices_unit_check" CHECK (("unit" = ANY (ARRAY['person'::"text", 'group'::"text", 'custom'::"text"])))
);


ALTER TABLE "public"."prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "route_id" "uuid" NOT NULL,
    "display_name" "text" NOT NULL,
    "rating" integer NOT NULL,
    "body" "text" NOT NULL,
    "status" "public"."review_status" DEFAULT 'pending'::"public"."review_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "published_at" timestamp with time zone,
    CONSTRAINT "reviews_body_check" CHECK ((("char_length"("body") >= 10) AND ("char_length"("body") <= 1500))),
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."route_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "route_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "alt_text" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "public" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."route_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."route_variants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "route_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "route_variants_mode_check" CHECK (("mode" = ANY (ARRAY['shared'::"text", 'private'::"text", 'partner'::"text", 'custom'::"text"])))
);


ALTER TABLE "public"."route_variants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."routes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "short_description" "text",
    "full_description" "text",
    "duration_minutes_min" integer,
    "duration_minutes_max" integer,
    "offered_languages" "text"[] DEFAULT ARRAY['es'::"text"] NOT NULL,
    "meeting_point_public" "text",
    "meeting_point_private" "text",
    "accessibility" "text",
    "includes" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "excludes" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "min_participants" integer,
    "max_participants" integer,
    "status" "public"."route_status" DEFAULT 'draft'::"public"."route_status" NOT NULL,
    "featured" boolean DEFAULT false NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "routes_check" CHECK (("duration_minutes_max" >= "duration_minutes_min")),
    CONSTRAINT "routes_check1" CHECK (("max_participants" >= "min_participants")),
    CONSTRAINT "routes_duration_minutes_min_check" CHECK (("duration_minutes_min" > 0)),
    CONSTRAINT "routes_min_participants_check" CHECK (("min_participants" > 0)),
    CONSTRAINT "routes_slug_check" CHECK (("slug" ~ '^[a-z0-9-]+$'::"text"))
);


ALTER TABLE "public"."routes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."schedules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "capacity" integer NOT NULL,
    "reserved_places" integer DEFAULT 0 NOT NULL,
    "available" boolean DEFAULT true NOT NULL,
    "notes_private" "text",
    CONSTRAINT "schedules_capacity_check" CHECK (("capacity" > 0)),
    CONSTRAINT "schedules_check" CHECK ((("reserved_places" >= 0) AND ("reserved_places" <= "capacity"))),
    CONSTRAINT "schedules_check1" CHECK (("ends_at" > "starts_at"))
);


ALTER TABLE "public"."schedules" OWNER TO "postgres";


ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_public_reference_key" UNIQUE ("public_reference");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."participants"
    ADD CONSTRAINT "participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prices"
    ADD CONSTRAINT "prices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."route_images"
    ADD CONSTRAINT "route_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."route_variants"
    ADD CONSTRAINT "route_variants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."routes"
    ADD CONSTRAINT "routes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."routes"
    ADD CONSTRAINT "routes_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."schedules"
    ADD CONSTRAINT "schedules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."schedules"
    ADD CONSTRAINT "schedules_variant_id_starts_at_key" UNIQUE ("variant_id", "starts_at");



CREATE INDEX "bookings_date_idx" ON "public"."bookings" USING "btree" ("preferred_date");



CREATE INDEX "bookings_status_created_idx" ON "public"."bookings" USING "btree" ("status", "created_at" DESC);



CREATE OR REPLACE TRIGGER "bookings_updated" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "customers_updated" BEFORE UPDATE ON "public"."customers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "routes_updated" BEFORE UPDATE ON "public"."routes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "public"."routes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_schedule_id_fkey" FOREIGN KEY ("schedule_id") REFERENCES "public"."schedules"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."route_variants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."participants"
    ADD CONSTRAINT "participants_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prices"
    ADD CONSTRAINT "prices_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."route_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "public"."routes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."route_images"
    ADD CONSTRAINT "route_images_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "public"."routes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."route_variants"
    ADD CONSTRAINT "route_variants_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "public"."routes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."schedules"
    ADD CONSTRAINT "schedules_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."route_variants"("id") ON DELETE CASCADE;



CREATE POLICY "admin_audit" ON "public"."audit_log" FOR SELECT USING ("public"."is_active_admin"());



CREATE POLICY "admin_bookings" ON "public"."bookings" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_customers" ON "public"."customers" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_images" ON "public"."route_images" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_messages" ON "public"."messages" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_participants" ON "public"."participants" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_prices" ON "public"."prices" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



ALTER TABLE "public"."admin_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_reviews" ON "public"."reviews" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_routes" ON "public"."routes" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_schedules" ON "public"."schedules" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



CREATE POLICY "admin_variants" ON "public"."route_variants" USING ("public"."is_active_admin"()) WITH CHECK ("public"."is_active_admin"());



ALTER TABLE "public"."audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "own_admin_profile" ON "public"."admin_profiles" FOR SELECT USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "public_images" ON "public"."route_images" FOR SELECT USING ("public");



CREATE POLICY "public_prices" ON "public"."prices" FOR SELECT USING ("public");



CREATE POLICY "public_reviews" ON "public"."reviews" FOR SELECT USING (("status" = 'published'::"public"."review_status"));



CREATE POLICY "public_routes" ON "public"."routes" FOR SELECT USING (("status" = 'published'::"public"."route_status"));



CREATE POLICY "public_schedules" ON "public"."schedules" FOR SELECT USING ("available");



CREATE POLICY "public_variants" ON "public"."route_variants" FOR SELECT USING (("active" AND (EXISTS ( SELECT 1
   FROM "public"."routes" "r"
  WHERE (("r"."id" = "route_variants"."route_id") AND ("r"."status" = 'published'::"public"."route_status"))))));



ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."route_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."route_variants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."routes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."schedules" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."is_active_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_active_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_active_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_booking_request"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_booking_request"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_booking_request"("payload" "jsonb") TO "service_role";



GRANT ALL ON TABLE "public"."admin_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."audit_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."audit_log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."participants" TO "authenticated";
GRANT ALL ON TABLE "public"."participants" TO "service_role";



GRANT ALL ON TABLE "public"."prices" TO "anon";
GRANT ALL ON TABLE "public"."prices" TO "authenticated";
GRANT ALL ON TABLE "public"."prices" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."route_images" TO "anon";
GRANT ALL ON TABLE "public"."route_images" TO "authenticated";
GRANT ALL ON TABLE "public"."route_images" TO "service_role";



GRANT ALL ON TABLE "public"."route_variants" TO "anon";
GRANT ALL ON TABLE "public"."route_variants" TO "authenticated";
GRANT ALL ON TABLE "public"."route_variants" TO "service_role";



GRANT ALL ON TABLE "public"."routes" TO "anon";
GRANT ALL ON TABLE "public"."routes" TO "authenticated";
GRANT ALL ON TABLE "public"."routes" TO "service_role";



GRANT ALL ON TABLE "public"."schedules" TO "anon";
GRANT ALL ON TABLE "public"."schedules" TO "authenticated";
GRANT ALL ON TABLE "public"."schedules" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







