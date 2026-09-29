-- ============================================================================
-- NaviSante Migration: Fix Facility Contribution Update & Dedup Logic
-- ============================================================================
-- Aligned 1:1 with initial RPCs, signatures, types, and admin cheat sheet.
--
-- Fixes:
-- 1. admin_approve_suggestion:
--    - Detects whether suggestion is an update to an existing facility.
--    - If UPDATE: modifies the existing row in public.facility in-place
--      (no duplicate created).
--    - Updates ONLY fields that were modified/non-empty, keeping untouched
--      data unchanged.
--    - Preserves existing photos if no new photos were submitted. If new photos
--      are present, appends them to facility_images without removing old ones.
--    - If NEW: preserves original INSERT logic into public.facility.
--    - Keeps exact return type: uuid.
-- 2. submit_facility_suggestion & resubmit_facility_suggestion:
--    - Detects target facility from metadata and stores created_facility_id.
--    - Keeps exact signature and return type: facility_suggestions.
-- 3. admin_pending_facility_suggestions:
--    - Adds ONLY target_facility_name (no extra id columns).
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ADMIN APPROVE SUGGESTION RPC
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_approve_suggestion(p_ticket_id uuid, p_folder_url text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ticket public.facility_suggestions;
  v_existing_facility_id uuid;
  v_facility_id uuid;
  v_folder_url text;
  v_existing_folder text;
  v_final_images text[];
  v_service text;
  v_tag text;
  v_service_id int;
  v_tag_id int;
  v_contrib_type text;
  v_clean_description text;
  v_max_order int;
  v_has_primary boolean;
begin
  select * into v_ticket
  from public.facility_suggestions
  where id = p_ticket_id and status = 'pending'
  for update;
 
  if v_ticket.id is null then
    raise exception 'Ticket not found or not pending';
  end if;

  -- 1. Identify if this ticket is an update to an existing facility
  v_existing_facility_id := v_ticket.created_facility_id;
  if v_existing_facility_id is null and v_ticket.description ~ '\[NAVISANTE_CONTRIBUTION\]' then
    v_existing_facility_id := (regexp_match(v_ticket.description, 'facility_id=([0-9a-fA-F-]{36})'))[1]::uuid;
  end if;

  -- 2. Extract contribution type & clean description (stripping metadata marker)
  if v_ticket.description ~ '\[NAVISANTE_CONTRIBUTION\]' then
    v_contrib_type := (regexp_match(v_ticket.description, 'type=([a-zA-Z0-9_]+)'))[1];
    v_clean_description := nullif(btrim(regexp_replace(v_ticket.description, '^\[NAVISANTE_CONTRIBUTION\][^\n]*(\n|$)', '')), '');
  else
    v_clean_description := v_ticket.description;
  end if;

  if v_contrib_type is null then
    if v_existing_facility_id is not null then
      v_contrib_type := 'update_facility';
    else
      v_contrib_type := 'suggest_facility';
    end if;
  end if;

  -- ───────────────────────────────────────────────────────────────────────────
  -- BRANCH A: UPDATE EXISTING FACILITY (In-place update, NO duplicates)
  -- ───────────────────────────────────────────────────────────────────────────
  if v_existing_facility_id is not null and exists (select 1 from public.facility where facility_id = v_existing_facility_id) then
    v_facility_id := v_existing_facility_id;

    -- Update only if contribution is an update_facility
    if v_contrib_type = 'update_facility' then
      update public.facility
      set
        name = coalesce(nullif(btrim(v_ticket.facility_name), ''), name),
        type = coalesce(nullif(btrim(v_ticket.facility_type), ''), type),
        description = coalesce(v_clean_description, description),
        city = coalesce(nullif(btrim(v_ticket.city), ''), city),
        address = coalesce(nullif(btrim(v_ticket.address), ''), address),
        coordinates = coalesce(v_ticket.coordinates, coordinates),
        phone = coalesce(nullif(btrim(v_ticket.phone), ''), phone),
        work_hours = coalesce(nullif(btrim(v_ticket.work_days), ''), work_hours),
        rating = coalesce(v_ticket.rating, rating),
        price_range = coalesce(nullif(btrim(v_ticket.price_range), ''), price_range)
      where facility_id = v_facility_id;

      -- Update services only if provided (keeps untouched if empty)
      if v_ticket.services is not null and cardinality(v_ticket.services) > 0 then
        delete from public.facility_services where facility_id = v_facility_id;
        foreach v_service in array v_ticket.services loop
          insert into public.services (name) values (btrim(v_service))
            on conflict (name) do nothing;
          select service_id into v_service_id from public.services where name = btrim(v_service);
          insert into public.facility_services (facility_id, service_id)
            values (v_facility_id, v_service_id) on conflict do nothing;
        end loop;
      end if;

      -- Update tags only if provided (keeps untouched if empty)
      if v_ticket.infrastructure is not null and cardinality(v_ticket.infrastructure) > 0 then
        delete from public.facility_tags where facility_id = v_facility_id;
        foreach v_tag in array v_ticket.infrastructure loop
          insert into public.tags (name) values (btrim(v_tag))
            on conflict (name) do nothing;
          select tag_id into v_tag_id from public.tags where name = btrim(v_tag);
          insert into public.facility_tags (facility_id, tag_id)
            values (v_facility_id, v_tag_id) on conflict do nothing;
        end loop;
      end if;
    end if;

    -- Photos in UPDATE:
    -- If user did NOT submit new photos, existing photos remain 100% UNTOUCHED!
    select image_folder into v_existing_folder from public.facility where facility_id = v_facility_id;
    v_folder_url := coalesce(p_folder_url, v_ticket.target_folder_url, v_existing_folder);

    if v_ticket.photo_urls is not null and array_length(v_ticket.photo_urls, 1) > 0 then
      if v_folder_url is not null then
        v_folder_url := regexp_replace(v_folder_url, '/+$', '') || '/';
        v_final_images := array(
          select v_folder_url || regexp_replace(url, '^.*/', '')
          from unnest(v_ticket.photo_urls) as url
        );
        update public.facility set image_folder = v_folder_url where facility_id = v_facility_id;
      else
        v_final_images := v_ticket.photo_urls;
      end if;

      -- Check existing primary image & max display order
      select exists(select 1 from public.facility_images where facility_id = v_facility_id and is_primary = true)
        into v_has_primary;
      select coalesce(max(display_order), 0) into v_max_order from public.facility_images where facility_id = v_facility_id;

      insert into public.facility_images (facility_id, storage_url, is_primary, display_order, source)
      select v_facility_id, url, (not v_has_primary and ord = 1), v_max_order + ord, 'user'
      from unnest(v_final_images) with ordinality as t(url, ord);
    end if;

  -- ───────────────────────────────────────────────────────────────────────────
  -- BRANCH B: NEW FACILITY (Preserves original insert flow)
  -- ───────────────────────────────────────────────────────────────────────────
  else
    insert into public.facility (
      name, type, description, city, address, coordinates, phone,
      work_hours, rating, price_range
    ) values (
      v_ticket.facility_name, v_ticket.facility_type, v_clean_description,
      v_ticket.city, v_ticket.address, v_ticket.coordinates, v_ticket.phone,
      v_ticket.work_days, v_ticket.rating, v_ticket.price_range
    )
    returning facility_id into v_facility_id;
   
    foreach v_service in array v_ticket.services loop
      insert into public.services (name) values (btrim(v_service))
        on conflict (name) do nothing;
      select service_id into v_service_id from public.services where name = btrim(v_service);
      insert into public.facility_services (facility_id, service_id)
        values (v_facility_id, v_service_id) on conflict do nothing;
    end loop;
   
    foreach v_tag in array v_ticket.infrastructure loop
      insert into public.tags (name) values (btrim(v_tag))
        on conflict (name) do nothing;
      select tag_id into v_tag_id from public.tags where name = btrim(v_tag);
      insert into public.facility_tags (facility_id, tag_id)
        values (v_facility_id, v_tag_id) on conflict do nothing;
    end loop;
   
    v_folder_url := coalesce(p_folder_url, v_ticket.target_folder_url);
   
    if v_folder_url is not null then
      v_folder_url := regexp_replace(v_folder_url, '/+$', '') || '/';
      v_final_images := array(
        select v_folder_url || regexp_replace(url, '^.*/', '')
        from unnest(v_ticket.photo_urls) as url
      );
      update public.facility set image_folder = v_folder_url where facility_id = v_facility_id;
    else
      v_final_images := v_ticket.photo_urls;
    end if;
   
    if array_length(v_final_images, 1) > 0 then
      insert into public.facility_images (facility_id, storage_url, is_primary, display_order, source)
      select v_facility_id, url, (ord = 1), ord, 'user'
      from unnest(v_final_images) with ordinality as t(url, ord);
    end if;
  end if;

  -- ───────────────────────────────────────────────────────────────────────────
  -- Update ticket status & credit contributor
  -- ───────────────────────────────────────────────────────────────────────────
  update public.facility_suggestions
  set status = 'approved',
      reviewed_at = now(),
      rejection_reason = null,
      created_facility_id = v_facility_id,
      target_folder_url = v_folder_url
  where id = p_ticket_id;
 
  insert into public.facility_contributors (facility_id, user_id, contribution_type, suggestion_id)
  values (v_facility_id, v_ticket.user_id, v_contrib_type, v_ticket.id)
  on conflict (suggestion_id) do nothing;
 
  return v_facility_id;
end;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. SUBMIT FACILITY SUGGESTION RPC
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_facility_suggestion(p_facility_name text, p_facility_type text, p_city text, p_address text, p_phone text, p_description text, p_work_days text, p_latitude double precision, p_longitude double precision, p_price_range text, p_rating numeric, p_services text[], p_infrastructure text[], p_photo_urls text[])
 RETURNS facility_suggestions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.facility_suggestions;
  v_target_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_latitude is null or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid coordinates';
  end if;

  if p_description ~ '\[NAVISANTE_CONTRIBUTION\]' then
    v_target_id := (regexp_match(p_description, 'facility_id=([0-9a-fA-F-]{36})'))[1]::uuid;
  end if;

  insert into public.facility_suggestions (
    user_id, created_facility_id, facility_name, facility_type, city, address, phone,
    description, work_days, coordinates, price_range, rating,
    services, infrastructure, photo_urls
  ) values (
    auth.uid(), v_target_id, p_facility_name, lower(p_facility_type), p_city, p_address, p_phone,
    nullif(btrim(coalesce(p_description, '')), ''), p_work_days,
    geography(st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)),
    lower(p_price_range), p_rating, p_services, p_infrastructure, p_photo_urls
  )
  returning * into v_row;

  return v_row;
end;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RESUBMIT FACILITY SUGGESTION RPC
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resubmit_facility_suggestion(p_ticket_id uuid, p_facility_name text, p_facility_type text, p_city text, p_address text, p_phone text, p_description text, p_work_days text, p_latitude double precision, p_longitude double precision, p_price_range text, p_rating numeric, p_services text[], p_infrastructure text[], p_photo_urls text[])
 RETURNS facility_suggestions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.facility_suggestions;
  v_target_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_description ~ '\[NAVISANTE_CONTRIBUTION\]' then
    v_target_id := (regexp_match(p_description, 'facility_id=([0-9a-fA-F-]{36})'))[1]::uuid;
  end if;

  update public.facility_suggestions
  set facility_name = p_facility_name,
      facility_type = lower(p_facility_type),
      city = p_city,
      address = p_address,
      phone = p_phone,
      description = nullif(btrim(coalesce(p_description, '')), ''),
      work_days = p_work_days,
      coordinates = geography(st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)),
      price_range = lower(p_price_range),
      rating = p_rating,
      services = p_services,
      infrastructure = p_infrastructure,
      photo_urls = p_photo_urls,
      created_facility_id = coalesce(v_target_id, created_facility_id),
      status = 'pending',
      rejection_reason = null,
      reviewed_at = null,
      revision_count = revision_count + 1
  where id = p_ticket_id
    and user_id = auth.uid()
    and status = 'rejected'
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Ticket not found, not yours, or not currently rejected';
  end if;

  return v_row;
end;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ADMIN PENDING FACILITY SUGGESTIONS VIEW
-- (Exposes target_facility_name only, perfectly matching cheat sheet A1)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.admin_pending_facility_suggestions
WITH (security_invoker = on) AS
SELECT
  s.id,
  s.created_at,
  u.email AS submitted_by,
  s.facility_name,
  s.facility_type,
  s.city,
  s.address,
  s.phone,
  s.description,
  s.work_days,
  st_y(s.coordinates::geometry) AS latitude,
  st_x(s.coordinates::geometry) AS longitude,
  s.price_range,
  s.rating,
  s.services,
  s.infrastructure,
  s.photo_urls,
  s.target_folder_url,
  s.revision_count,
  f.name AS target_facility_name
FROM
  public.facility_suggestions s
  JOIN auth.users u ON u.id = s.user_id
  LEFT JOIN public.facility f ON f.facility_id = COALESCE(
    s.created_facility_id,
    (regexp_match(s.description, 'facility_id=([0-9a-fA-F-]{36})'))[1]::uuid
  )
WHERE
  s.status = 'pending'::text
ORDER BY
  s.created_at DESC;
