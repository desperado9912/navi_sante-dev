# NaviSante — Healthcare Facilities Feature: Complete Implementation Summary

> **Purpose of this document:** Full context for any LLM assisting with NaviSante development.
> Covers all architectural decisions, database schema, sprint implementations, and code
> produced so far. Read this entirely before writing any code or giving any advice.

---

## 1. App Overview

**NaviSante** is a Flutter mobile health navigation app targeting Cameroon (primarily Yaoundé).
It helps users find nearby hospitals, clinics, and pharmacies — especially critical in
emergency situations where speed matters.

### Tech Stack

| Layer | Technology |
|---|---|
| Mobile framework | Flutter (Dart) |
| State management | BLoC / Cubit (`flutter_bloc`) |
| Backend / Database | Supabase (PostgreSQL + PostGIS) |
| Local cache | Hive (`hive_flutter`) |
| Map engine | `flutter_map` with OpenStreetMap / Carto Light tiles |
| Map tile cache | `HiveCacheStore` (existing, already implemented) |
| Authentication | Supabase Auth (already implemented) |
| Image storage | Supabase Storage |
| Navigation/directions | `url_launcher` (platform-native maps) |

### Existing Codebase Context (Before This Feature)

Before this feature sprint, the following was already implemented and working:

- Supabase auth flow (`features/auth/`)
- Map initialisation with OSM tiles and live user location pulsing indicator
- Map tile caching via `HiveCacheStore` with 500MB eviction
- `MapCubit` for map state management
- `map_service.dart` for map utilities
- `home_screen.dart` with search bar UI (no function yet)
- `map_controls.dart`, `map_info_sheet.dart` (OSM attribution), `header_search.dart`
- Bottom navigation bar: Home, Hospitals, Pharmacy, Profile tabs

---

## 2. Feature Being Built

**Feature name:** Healthcare Facility Discovery

**Scope:**
- Display all hospital, clinic, and pharmacy pins on the map simultaneously (all types, all locations)
- Floating bottom carousel on the map screen showing the 5 closest facilities to the user
- Expandable bottom sheet when a map pin or carousel card is tapped
- Full-screen Hospitals tab with search, filters, and 2-column facility grid
- Facility detail screen with image carousel, services, tags, contact info, directions
- Bookmark system (save facilities, view saved in Settings)
- Offline support via Hive cache

---

## 3. UI Design Decisions

### Map Screen (Home Tab)

- All facility pins rendered simultaneously on map regardless of viewport — same model as Google Maps
- Three distinct marker types:
  - **Hospitals & Clinics:** Red marker with white **H** symbol
  - **Pharmacies:** Red marker with white **⚕** (Rod of Asclepius, Unicode U+2695)
- Marker clustering via `flutter_map_marker_cluster` at low zoom levels to prevent overlap
- **Floating carousel** above the navbar: horizontal scrollable strip of the 5 closest facilities
- Tap a carousel card → expands into a bottom sheet (summarised detail view)
- Tap a map pin → pin animates (scales up), mini bottom card slides up, carousel hides
- Tap expand on bottom sheet → full detail bottom sheet view
- Tap map background or scroll away → returns to idle state (carousel shown again)
- Search result on map → matching pin highlighted, non-matching pins dimmed, single result card shown at bottom, carousel hidden
- No "last synced" badge anywhere — caching is invisible to the user

### Hospitals Screen (Hospitals Tab)

- Header: "Find Sanctuary" title, subtitle "Find health facilities around you"
- Search bar: searches by name (fuzzy, accent-insensitive, French-aware)
- **Recent History:** horizontal scrollable chips of last 10 viewed/searched facilities (Hive only)
- Filter bar: **Health Condition** dropdown (queries services table), **Select City** dropdown, **Price Rating** dropdown
- Results displayed in a **2-column grid** (`GridView.builder`, `crossAxisCount: 2`)
- Each grid card contains: facility image, name (max 2 lines), rating badge overlay, 2–3 service chips + `+N` overflow label, "Details →" button, directions icon button, bookmark icon overlay
- Missing image → graceful placeholder (teal gradient with facility type icon, never a broken image)
- Section header "Top Rated Nearby" above grid

### Facility Detail Screen

- Back button `< Details`
- Full-width image carousel (PageView + dot indicators) at top
- Facility name (large, bold)
- Star rating + bookmark toggle icon (top right of info section)
- Specialty service chips (wrapped, scrollable)
- Description paragraph
- Contact info card: phone icon + number, location pin + address, clock + work hours
- **GET DIRECTIONS** button (teal, filled) → opens native maps app
- **CALL** button (outlined) → `tel:` URI via `url_launcher`
- Bullet list of tags (amenities/equipment): Emergency Response, ICU, MRI Scanner, etc.
- Bottom navigation bar remains visible

### Directions Behaviour

- **No in-app map preference setting** — the device OS decides which maps app opens
- **Android:** `geo:{lat},{lng}?q={lat},{lng}` URI → system resolves to Google Maps (or device default)
- **iOS:** `maps://?daddr={lat},{lng}` → Apple Maps
- Destination pre-set from facility coordinates, origin from user's current location
- Native app handles routing, ETA, real-time navigation — NaviSante hands off completely
- User just taps "Start" in the native maps app

---

## 4. Architecture

### Core Principle: Local-First, Cache-Then-Network

```
App launch
  └── FacilityLocal.init()          opens Hive boxes

Map screen opens
  └── FacilityBloc dispatches LoadFacilities
        └── FacilityRepository.getAllFacilities()  [Stream — emits twice]
              ├── Emit 1: Hive cache → immediate render (zero wait)
              └── Emit 2: Supabase RPC → updates Hive silently, re-renders

User position acquired (LocationCubit)
  └── FacilityRepository.getHighlights(lat, lng)
        └── reads Hive cache → sorts by haversine in Dart → returns top 5
              └── carousel renders (ZERO network calls ever)

User taps pin or card
  └── FacilityRepository.getFacilityDetail(id)
        ├── Hive hit → returns instantly (subsequent taps = always instant)
        └── Hive miss → Supabase RPC → saves to Hive → returns

User types in search (after 300ms debounce)
  └── FacilityRepository.searchFacilities(query, filters)
        └── always Supabase (search is never cached — open-ended input)
```

### Why All Facilities Are Loaded At Once (No Radius/Pagination)

Unlike a paginated radius query model, NaviSante loads **all facilities once** and caches them. This decision was made because:

1. Yaoundé realistic facility count: 50–300 records — a tiny payload (~200KB)
2. All map pins must be visible immediately like Google Maps (not just in viewport)
3. The "5 closest" carousel is computed in Dart by sorting cached coordinates — zero DB calls on location change
4. Emergency use case: user must never wait for pins to load while patient is suffering

The DB function `get_all_facilities()` has **no LIMIT and no radius filter** by design.

### Map State Machine (4 States)

```
[IDLE]
  • All facility pins rendered from Hive
  • Floating carousel: 5 closest facilities
  
  ├── Tap pin ──────────────► [PIN SELECTED]
  │                             • Pin scales up (animation)
  │                             • Mini bottom card slides up
  │                             • Carousel hides
  │                             ├── Tap expand → [DETAIL SHEET]
  │                             └── Tap map/elsewhere → [IDLE]
  │
  ├── Type in search ──────────► [SEARCH ACTIVE]
  │                               • Matching pins highlighted
  │                               • Non-matching pins dimmed
  │                               • Single result card at bottom
  │                               • Carousel hidden
  │                               ├── Tap result card → [DETAIL SHEET]
  │                               └── Clear search → [IDLE]
  │
  └── Tap carousel card ────────► [DETAIL SHEET]
                                    • Bottom sheet expands
                                    • Summarised detail view
                                    • "View Full Details" → detail screen
                                    └── Drag down → [IDLE]
```

### Cache Strategy Per Operation

| Operation | Source | When Network Called | Cached After? |
|---|---|---|---|
| `getAllFacilities()` | Hive first, then Supabase | Every session (stream emit 2) | Yes, overwrites previous |
| `getHighlights()` | Hive only | Never | N/A |
| `getFacilityDetail(id)` | Hive first | Only on cache miss | Yes, per facility_id |
| `searchFacilities()` | Supabase only | Every search | No |
| `getUserBookmarks()` | Supabase only | On bookmarks screen open | No (future sprint) |

---

## 5. Database Schema (Final — Supabase PostgreSQL)

### Extensions Required

```sql
postgis     -- spatial/geographic queries (ST_DWithin, ST_Distance, ST_Point)
pg_trgm     -- trigram similarity for fuzzy search (handles typos, partial input)
unaccent    -- accent-insensitive search (médecin → medecin, critical for French)
```

### Tables

#### `facility` (master table)

| Column | Type | Notes |
|---|---|---|
| `facility_id` | UUID PK | `gen_random_uuid()` |
| `osm_id` | BIGINT UNIQUE NULLABLE | Used only by OSM import script for dedup. Never shown to users. |
| `name` | TEXT NOT NULL | |
| `type` | TEXT NOT NULL | CHECK IN ('hospital', 'clinic', 'pharmacy') |
| `description` | TEXT | |
| `city` | TEXT NOT NULL | DEFAULT 'Yaoundé' |
| `address` | TEXT | |
| `coordinates` | GEOGRAPHY(POINT, 4326) NOT NULL | PostGIS. SRID 4326 = WGS84 = GPS standard |
| `phone` | TEXT | |
| `work_hours` | TEXT | Free text: "Open 24/7", "Mon–Sat 8:00–20:00" |
| `rating` | DECIMAL(2,1) | CHECK 0.0–5.0. Static field for MVP. |
| `price_range` | TEXT | CHECK IN ('free', 'affordable', 'premium') |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | Auto-managed by trigger on every UPDATE |

#### `services` (medical specialties — lookup table)

| Column | Type | Notes |
|---|---|---|
| `service_id` | UUID PK | |
| `name` | TEXT UNIQUE NOT NULL | e.g. Cardiology, Neurology, Dental |

Shown as **chips** on facility cards and detail screen. Used by "Health Condition" filter.

#### `tags` (physical amenities — lookup table)

| Column | Type | Notes |
|---|---|---|
| `tag_id` | UUID PK | |
| `name` | TEXT UNIQUE NOT NULL | e.g. Parking, MRI Scanner, Emergency Response |

Shown as **bullet list** on detail screen. Not used for filtering (MVP).

**Why services and tags are separate tables:** They map to two different UI elements (chips vs bullet list) and serve different purposes (medical specialties for filtering vs physical amenities for information).

#### `facility_services` (junction — many-to-many)

| Column | Type | Notes |
|---|---|---|
| `facility_id` | UUID FK → facility | ON DELETE CASCADE |
| `service_id` | UUID FK → services | ON DELETE RESTRICT |
| Composite PK | (facility_id, service_id) | |

CASCADE on facility: mappings deleted when facility is deleted.
RESTRICT on service: cannot delete a service that is in use by any facility.

#### `facility_tags` (junction — many-to-many)

Same pattern as `facility_services`. CASCADE on facility, RESTRICT on tag.

#### `facility_images`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Needed for individual row targeting (delete specific image) |
| `facility_id` | UUID FK → facility | ON DELETE CASCADE |
| `storage_url` | TEXT NOT NULL | Supabase Storage public URL |
| `is_primary` | BOOLEAN NOT NULL | DEFAULT FALSE. Enforced: only ONE per facility via partial unique index |
| `display_order` | SMALLINT NOT NULL | DEFAULT 0. Controls carousel sequence on detail screen |
| `source` | TEXT NOT NULL | CHECK IN ('admin', 'osm', 'user'). DEFAULT 'admin' |

#### `facility_bookmarks`

| Column | Type | Notes |
|---|---|---|
| `user_id` | UUID FK → auth.users | ON DELETE CASCADE |
| `facility_id` | UUID FK → facility | ON DELETE CASCADE |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| Composite PK | (user_id, facility_id) | Prevents duplicate bookmarks |

Both FK columns CASCADE: user deleted → bookmarks gone. Facility removed → bookmarks for it gone.

### Key Constraints

```sql
-- Type enum enforcement
type CHECK (type IN ('hospital', 'clinic', 'pharmacy'))

-- Rating bounds
rating CHECK (rating >= 0.0 AND rating <= 5.0)

-- Exactly one primary image per facility (partial unique index)
CREATE UNIQUE INDEX one_primary_per_facility
  ON facility_images(facility_id) WHERE is_primary = TRUE;

-- Price range enum
price_range CHECK (price_range IN ('free', 'affordable', 'premium'))
```

### Performance Indexes

```sql
-- Spatial (critical for proximity queries)
CREATE INDEX idx_facility_coordinates ON facility USING GIST(coordinates);

-- Fuzzy name search
CREATE INDEX idx_facility_name_trgm ON facility USING GIN(name gin_trgm_ops);

-- Full-text search (French stemming for Yaoundé context)
CREATE INDEX idx_facility_fts ON facility USING GIN(
  to_tsvector('french', name || ' ' || COALESCE(description,'') || ' ' || COALESCE(address,''))
);

-- Type + rating combo (for filter queries)
CREATE INDEX idx_facility_type_rating ON facility(type, rating DESC);

-- City filter
CREATE INDEX idx_facility_city ON facility(city);

-- Fast primary image lookup (partial — only indexes is_primary = TRUE rows)
CREATE INDEX idx_images_primary ON facility_images(facility_id) WHERE is_primary = TRUE;

-- User bookmarks
CREATE INDEX idx_bookmarks_user ON facility_bookmarks(user_id);

-- Reverse junction indexes (for "facilities that offer Cardiology" queries)
CREATE INDEX idx_fac_services_service ON facility_services(service_id);
CREATE INDEX idx_fac_tags_tag ON facility_tags(tag_id);
```

### Trigger

```sql
-- Auto-updates updated_at on every facility row change
CREATE TRIGGER trg_facility_updated_at
  BEFORE UPDATE ON facility
  FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();
```

### Row Level Security (RLS)

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| facility | ✅ Public (anyone) | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| services | ✅ Public | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| tags | ✅ Public | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| facility_services | ✅ Public | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| facility_tags | ✅ Public | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| facility_images | ✅ Public | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| facility_bookmarks | ✅ Own rows only | ✅ Own rows only | ❌ | ✅ Own rows only |

Write access to facility data is exclusively via `service_role` key (bypasses RLS).
Used only in the OSM import script and Supabase SQL Editor — never in the Flutter app.

### Supabase Storage

- **Bucket name:** `facility-images`
- **Public:** Yes (images served via public URL, no auth required to view)
- **File size limit:** 5MB
- **Allowed types:** `image/jpeg`, `image/png`, `image/webp`
- **Path convention:** `{facility_id}/primary.jpg`, `{facility_id}/gallery_1.jpg`, etc.
- **URL format:** `https://{project-ref}.supabase.co/storage/v1/object/public/facility-images/{path}`

---

## 6. PostGIS RPC Functions

All called from Flutter via `supabase.rpc('function_name', params: {...})`.
All use `SECURITY DEFINER` + `SET search_path = public, pg_temp` for security.

### `get_all_facilities()`

- **No parameters. No LIMIT. No radius filter.**
- Returns every facility in the database
- Fields: `facility_id, name, type, address, phone, work_hours, rating, price_range, latitude, longitude, primary_image, services_list`
- `services_list` is TEXT[] capped at 3 items (enough for card chips)
- Tags NOT included (only needed on detail screen, fetched separately)
- Images: only `primary_image` (single URL for card thumbnail)
- Called once per session, result cached entirely in Hive

### `search_facilities(query_text, type_filter, city_filter, min_rating, result_limit)`

- All parameters except `query_text` are optional (NULL = no filter)
- Three matching strategies combined (row returned if ANY matches):
  1. `ILIKE '%query%'` — simple substring match
  2. `similarity()` via pg_trgm — fuzzy match for typos
  3. `tsvector @@ tsquery` — French full-text search
- `unaccent()` applied to both query and DB values (médecin matches medecin)
- Results ordered by relevance score DESC, then rating DESC
- Returns same shape as `get_all_facilities()` rows + `relevance` field
- Guards against empty query (returns nothing if query is blank)

### `get_facility_detail(p_facility_id UUID)`

- Returns a **single JSON object** (not a table row) — `RETURNS JSON`
- Full payload: all facility fields + full images array (ordered by display_order) + full services list + full tags list
- Images array sorted by `display_order ASC` for correct carousel sequence
- All array fields return `[]` (never null) — SQL uses `COALESCE(..., '[]'::json)`
- Returns NULL if `p_facility_id` does not exist

### `get_user_bookmarks()`

- No parameters — uses `auth.uid()` internally
- Returns full facility cards for all of the calling user's bookmarks
- Ordered by `bookmarked_at DESC` (most recent first)

---

## 7. Seed Data

### `services` table (seeded once)

Cardiology, Neurology, Oncology, Dental, Ophthalmology, Orthopedics, Pediatrics,
Gynecology, Dermatology, General Consultation, Maternity, Psychiatry, Radiology,
Surgery, Physiotherapy, ENT (Ear, Nose, Throat), Urology, Internal Medicine,
Diabetology, Nephrology, Gastroenterology, Rheumatology, Pulmonology, Hematology,
Prosthesis

### `tags` table (seeded once)

Emergency Response, ICU, MRI Scanner, CT Scanner, X-Ray Machine, Laboratory,
Private Ward, In-House Pharmacy, Parking, Restoration Service, Ambulance Service,
Open 24/7, Wheelchair Accessible, Surgery Theater, Blood Bank, Oxygen Supply,
Dialysis Unit, Neonatal Unit

### Manual Facility Seed Query Pattern

```sql
DO $$
DECLARE v_id UUID;
BEGIN
  SELECT facility_id INTO v_id FROM facility
  WHERE name = 'Facility Name' AND city = 'Yaoundé';

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Facility not found';
  END IF;

  UPDATE facility SET name=..., phone=..., rating=... WHERE facility_id = v_id;

  DELETE FROM facility_services WHERE facility_id = v_id;
  INSERT INTO facility_services (facility_id, service_id)
  SELECT v_id, service_id FROM services WHERE name IN ('Cardiology', ...);

  DELETE FROM facility_tags WHERE facility_id = v_id;
  INSERT INTO facility_tags (facility_id, tag_id)
  SELECT v_id, tag_id FROM tags WHERE name IN ('ICU', 'Parking', ...);

  DELETE FROM facility_images WHERE facility_id = v_id;
  INSERT INTO facility_images (facility_id, storage_url, is_primary, display_order, source)
  VALUES
    (v_id, 'https://...primary.jpg', TRUE, 0, 'admin'),
    (v_id, 'https://...gallery_1.jpg', FALSE, 1, 'admin');
END;
$$;
```

**Why `DO $$` block:** PostgreSQL CTEs with multiple DELETE + INSERT on the same table
see the original DB state — DELETE is not visible to INSERT in the same CTE chain.
A `DO $$` block executes sequentially, each statement sees previous changes. ✅

---

## 8. Folder Structure

```
lib/
  main.dart
  features/
    auth/                              (existing — untouched)
    home/                              (MAP feature)
      controller/
        map_cubit.dart                 (existing — to be extended in Sprint 5)
        map_cache_manager.dart         (existing)
      maps/
        map_service.dart               (existing)
        map_launcher.dart              (Sprint 5 — directions service)
        facility_map_marker.dart       (Sprint 5 — H and ⚕ custom markers)
      screens/
        home_screen.dart               (existing)
      widgets/
        home_map_widget.dart           (existing)
        map_controls.dart              (existing)
        map_info_sheet.dart            (existing)
        header_search.dart             (existing)
        establishment_tile.dart        (existing)
        highlights_carousel.dart       (Sprint 5 — bottom floating strip)

    hospitals/                         (FACILITIES feature)
      bloc/
        facility_bloc.dart             (Sprint 4 — events + states + bloc)
        bookmark_cubit.dart            (Sprint 4 — bookmark toggle + saved list)
        recently_viewed_cubit.dart     (Sprint 4 — last 10 viewed, Hive only)
      data/
        facility_model.dart            (Sprint 3 ✅ — all models)
        facility_local.dart            (Sprint 3 ✅ — Hive operations)
        facility_remote.dart           (Sprint 3 ✅ — Supabase RPC calls)
        facility_repository.dart       (Sprint 3 ✅ — orchestration)
      screens/
        hospitals_screen.dart          (Sprint 6 — search + 2-column grid)
        facility_detail_screen.dart    (Sprint 7 — full detail view)
      widgets/
        facility_grid_card.dart        (Sprint 6 — 2-col card widget)
        facility_filter_bar.dart       (Sprint 6 — filter dropdowns)
        detail_image_carousel.dart     (Sprint 7 — top carousel on detail screen)

    pharmacy/                          (future feature, same pattern)
    profile/                           (existing)
```

**Structure rules:**
- Map feature lives in `home/` (it is an extension of the home/map screen)
- Hospital discovery feature lives in `hospitals/` (separate tab, separate feature)
- Model + Hive adapter + JSON = **one file** (`facility_model.dart`)
- All Hive reads/writes = **one file** (`facility_local.dart`)
- All Supabase calls = **one file** (`facility_remote.dart`)
- BLoC events + states + bloc class = **one file** (`facility_bloc.dart`)

---

## 9. Sprint Log

### ✅ Sprint 1 — Supabase Configuration (COMPLETE)

**Files produced:** `01_schema.sql`, `02_rls_policies.sql`, `03_functions.sql`, `04_seed.sql`

What was done:
- Enabled PostGIS, pg_trgm, unaccent extensions
- Created all 7 tables with constraints, cascading rules, and indexes
- Created `updated_at` trigger
- Defined RLS policies (public read, no write for app users, bookmark isolation)
- Created 4 PostGIS RPC functions
- Configured Supabase Storage bucket `facility-images`
- Seeded services and tags lookup tables
- Seeded 1 test facility (CHU Yaoundé) for RPC testing

**Key function change:** `get_nearby_facilities()` was redesigned to `get_all_facilities()` with no radius/limit — all pins loaded once and cached.

**Useful verification queries:**
```sql
-- Test all facilities load
SELECT facility_id, name, type, rating, latitude, longitude
FROM get_all_facilities();

-- Test fuzzy search (French accent-insensitive)
SELECT facility_id, name, relevance FROM search_facilities('hopital');

-- Test detail
SELECT get_facility_detail((SELECT facility_id FROM facility LIMIT 1));

-- View facility with all services and tags joined
SELECT
  f.name, f.type, f.rating,
  STRING_AGG(DISTINCT s.name, ', ') AS services,
  STRING_AGG(DISTINCT t.name, ', ') AS tags
FROM facility f
LEFT JOIN facility_services fs ON fs.facility_id = f.facility_id
LEFT JOIN services s ON s.service_id = fs.service_id
LEFT JOIN facility_tags ft ON ft.facility_id = f.facility_id
LEFT JOIN tags t ON t.tag_id = ft.tag_id
GROUP BY f.facility_id, f.name, f.type, f.rating
ORDER BY f.name;
```

### ⏭ Sprint 2 — OSM Data Import (SKIPPED — Post-MVP)

Planned: Node.js script using Overpass API to bulk-import real Yaoundé facility data.
Skipped to maintain MVP focus. Facilities are manually seeded via SQL Editor for now.
When implemented: uses `service_role` key, `ON CONFLICT (osm_id) DO UPDATE` for safe re-runs.

### ✅ Sprint 3 — Flutter Data Layer (COMPLETE)

**Files produced:**
- `facility_model.dart` — `FacilityType` enum, `FacilityModel`, `FacilityImage`, `FacilityDetailModel`
- `facility_local.dart` — `FacilityLocal` class (all Hive operations)
- `facility_remote.dart` — `FacilityRemote` class (all Supabase RPC calls)
- `facility_repository.dart` — `FacilityRepository` class (orchestration)

**Key implementation details:**

`FacilityModel` contains `distanceTo(lat, lng)` and `formatDistance(lat, lng)` using the haversine formula. Used by `getHighlights()` to sort facilities client-side.

`FacilityLocal` stores data as JSON-encoded strings in Hive (not TypeAdapters) to avoid `typeId` conflicts with existing Hive boxes in the app.

`FacilityRepository.getAllFacilities()` returns `Stream<List<FacilityModel>>` that emits twice: once from Hive (immediate), once from Supabase (fresh). BLoC uses `emit.forEach()` to handle both emissions.

`FacilityRepository.getHighlights()` is **fully synchronous** — reads Hive, sorts in Dart, returns. Zero async, zero network.

`FacilityRepository.getFacilityDetail()` is **cache-first** — Hive hit returns instantly, miss fetches Supabase and saves to Hive.

**main.dart additions required:**
```dart
// After existing Hive.initFlutter():
await FacilityLocal.init();

// After Supabase.initialize():
final facilityRepo = FacilityRepository(
  local:  FacilityLocal(),
  remote: FacilityRemote(Supabase.instance.client),
);
```

### 🔜 Sprint 4 — BLoC Layer (UPCOMING)

**Files to create:**
- `hospitals/bloc/facility_bloc.dart` — events, states, bloc class (one file)
- `hospitals/bloc/bookmark_cubit.dart` — bookmark toggle, saved list
- `hospitals/bloc/recently_viewed_cubit.dart` — last 10 viewed (Hive only)

**Events planned:**
- `LoadFacilities` → triggers `getAllFacilities()` stream
- `SearchFacilities(query, filters)` → triggers `searchFacilities()` (with 300ms debounce)
- `ClearSearch` → returns to idle/nearby state
- `LoadFacilityDetail(facilityId)` → triggers `getFacilityDetail()`
- `LoadHighlights(lat, lng)` → triggers `getHighlights()` (sync, no loading state)
- `ApplyFilters(typeFilter, cityFilter, minRating)` → re-runs search with new filters

**States planned:**
- `FacilityInitial`
- `FacilitiesLoading` (only shown when cache is empty)
- `FacilitiesLoaded(facilities, fromCache: bool)`
- `FacilitiesError(message)`
- `FacilityDetailLoading`
- `FacilityDetailLoaded(detail)`
- `FacilityDetailError`

**Map states** (separate from facility states, managed in existing `MapCubit`):
- `MapIdle` — all pins + carousel
- `MapPinSelected(facilityId)` — pin highlighted, mini card shown
- `MapSearchActive(results)` — matching pins highlighted, non-matching dimmed
- `MapDetailSheet(facilityId)` — expanded bottom sheet

**BookmarkCubit state:** Holds a `Set<String>` of bookmarked `facility_id` values in memory. Loaded from Supabase on auth. Toggled optimistically on UI tap, synced to Supabase.

**RecentlyViewedCubit:** Holds a `List<String>` of up to 10 recently viewed `facility_id` values. Persisted in Hive. Shown as chips on hospitals screen "Recent History" section.

### 🔜 Sprint 5 — Map Integration (UPCOMING)

**Files to create/modify:**
- `home/maps/facility_map_marker.dart` — custom marker widgets per facility type
- `home/maps/map_launcher.dart` — `url_launcher` directions service
- `home/widgets/highlights_carousel.dart` — bottom floating carousel
- `home/controller/map_cubit.dart` — extend existing with 4 map states

**Map marker design:**
```dart
// Hospital / Clinic: red container, white 'H' text
// Pharmacy: red container, white '⚕' text (U+2695)
```

**Directions implementation:**
```dart
// Android
final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');

// iOS
final uri = Uri.parse('maps://?daddr=$lat,$lng');

await launchUrl(uri);
```

**Highlights carousel:**
- Positioned above bottom nav bar
- `LocationCubit` position change → `LoadHighlights` event → `getHighlights()` (sync) → carousel updates
- Each card: primary image, name, type badge, distance string (`formatDistance()`), tap to expand

### 🔜 Sprint 6 — Hospitals Screen (UPCOMING)

**Files to create:**
- `hospitals/screens/hospitals_screen.dart`
- `hospitals/widgets/facility_grid_card.dart`
- `hospitals/widgets/facility_filter_bar.dart`

**Grid card layout** (2-column, compact):
- Image (top, square aspect ratio)
- Rating badge overlaid top-left of image
- Bookmark icon overlaid top-right of image
- Facility name (max 2 lines, overflow ellipsis)
- 2–3 service chips + `+N` label
- "Details →" text button + directions icon button side by side

**Filter bar:** Three `DropdownButton` widgets in a row:
- Health Condition → values from `services` table
- Select City → hardcoded list for MVP (Yaoundé, Douala, Bafoussam, etc.)
- Price Rating → Free / Affordable / Premium

**Search debounce:** 300ms `Timer` reset on each keystroke. Fires `SearchFacilities` event when timer completes.

### 🔜 Sprint 7 — Detail Screen (UPCOMING)

**Files to create:**
- `hospitals/screens/facility_detail_screen.dart`
- `hospitals/widgets/detail_image_carousel.dart`

**Detail screen sections (top to bottom):**
1. Image carousel (`PageView`) with dot indicators — uses `images` array ordered by `display_order`
2. Facility name (large bold)
3. Rating row + bookmark icon
4. Service chips (all services, not capped at 3)
5. Description text
6. Contact card: phone, address, work hours with icons
7. GET DIRECTIONS button (teal filled)
8. CALL button (outlined, `tel:` URI)
9. Tags bullet list (all amenities/equipment)

**Image placeholder:** If `facility.primaryImage == null` or image fails to load → show teal gradient container with facility type icon (`local_hospital`, `local_pharmacy`, etc.)

### 🔜 Sprint 8 — Settings: Saved Facilities (UPCOMING)

- Saved Facilities screen in Profile/Settings tab
- Uses `BookmarkCubit.savedFacilities` list
- Same `facility_grid_card.dart` widget (reused)
- Tap bookmark icon on any card → toggle in `BookmarkCubit` → updates Supabase + local state

---

## 10. Packages Required for This Feature

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | existing | Supabase client, auth, RPC, storage |
| `hive_flutter` | existing | Local cache (facility list + details) |
| `flutter_bloc` | existing | BLoC + Cubit state management |
| `flutter_map` | existing | Map rendering |
| `flutter_map_marker_cluster` | NEW | Cluster overlapping pins at low zoom |
| `url_launcher` | NEW | Directions (native maps) + Call button |
| `cached_network_image` | NEW | Image loading with placeholder/error states |
| `shimmer` | NEW | Loading skeleton for grid cards |

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_map_marker_cluster: ^1.3.4
  url_launcher: ^6.3.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
```

---

## 11. Key Decisions Reference

| Decision | Choice | Reason |
|---|---|---|
| Load all facilities vs paginated | All at once, no limit | Emergency context, Google Maps model, tiny dataset |
| Distance calculation | Dart haversine, not PostGIS | Data already cached, microseconds for 300 facilities |
| Maps app preference | Platform default (no in-app setting) | OS decides, not our concern |
| iOS directions | `maps://` → Apple Maps | Platform default |
| Android directions | `geo:` URI → Google Maps | Platform default |
| Hive storage format | JSON strings (not TypeAdapters) | Avoids typeId conflicts with existing app boxes |
| `getAllFacilities` stream | Emits twice (cache then network) | Instant render + fresh data without loading spinner |
| Opening hours format | Free text `work_hours` column | MVP simplicity, structured `opening_hours` table is post-MVP |
| Services vs Tags | Two separate tables | Services = chips + filtering; Tags = bullet list only |
| `is_primary` on images | Keep (REQUIRED) | Without it, no way to identify card thumbnail from multiple images |
| `display_order` on images | Keep (REQUIRED) | Without it, carousel order is insertion-order = unpredictable |
| `osm_id` column | Keep, nullable | Import script dedup — invisible to users and UI |
| Ratings | Static decimal field | User reviews are a post-MVP sprint |
| `service_role` key | Never in Flutter app | Only in Supabase SQL Editor + OSM import script |
| `DO $$` block for seed | Over CTE chain | CTEs see original DB state — DELETE not visible to INSERT in same query |
| `SECURITY DEFINER` on functions | Yes + `SET search_path` | Bypasses RLS for reads, search_path prevents injection |

---

## 12. Environment Variables

```
SUPABASE_URL=https://{project-ref}.supabase.co
SUPABASE_ANON_KEY={anon-key}          ← safe to include in Flutter app
SUPABASE_SERVICE_ROLE_KEY={key}       ← NEVER in Flutter, SQL Editor / import script only
```

Use `--dart-define` or a `.env` file approach (never hardcode keys in source):
```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

```dart
// Access in Dart
const supabaseUrl    = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```
