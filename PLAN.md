# Brusk — Implementation plan

> Working name **Brusk** (from the spec's Annex A). The name is a single constant
> (`PRODUCT_NAME` / `app.name` string) and must be cleared for trademark, App Store,
> domain and X handle before launch.

Source of truth: `fiche-produit-bruxelles.pdf` v0.1 (14 Oct 2026). Every product
rule below cites the spec section it implements.

---

## 1. Product rules we encode (from the spec)

| Rule | Spec | Where it lives |
|---|---|---|
| Sign-in by e-mailed code only. No SMS, no itsme | §4.1 | Supabase Auth email OTP; `SignInView` |
| Identity never public, no pseudonym on the map | §4.1 | No name column anywhere; public data only via aggregate RPCs |
| Data minimisation | §4.1, §8 | Columns listed in §4 below are the complete set |
| Per-user trust score: new accounts weigh little, weight grows when others confirm | §4.2 | `profiles.trust_weight`, `recompute_trust()` |
| A zone appears only when several distinct users report the same type at the same place | §4.2 | `refresh_cell()` + thresholds in `app_settings` |
| Thresholds (count, radius, window) must be tunable during the MVP | §4.2 | `app_settings` table, no redeploy needed |
| A report = place + type + time. No names, suspect photos or physical descriptions | §4.3 | `TextGuard` (client) + `text_violates_policy()` (server) |
| Optional photo, faces and plates blurred **before** upload | §4.3 | `PhotoAnonymizer` (Vision, on-device) |
| Map shows zones and trends, never exact points | §4.3 | Hexagonal cells (PostGIS `ST_Hexagon`, 120 m edge) |
| Serious facts → help first (112, 101, CPVS, victim support) | §4.4 | `SeriousFactsBanner`, `HelpScreen` |
| 4 screens: Map, Report, Follow-up, Emergency help | §5 | `Features/*` |
| Report in 3 steps, < 20 s | §5 écran 2 | `ReportFlow` |
| Statuses: pending → confirmed by neighbours → sent to service → resolved | §5 écran 3 | `report_status` enum |
| "Reported 12 days ago, still unresolved" + share on X | §5, §7 | `ShareCardView` + `ImageRenderer` |
| "Walking home alone": live location + alert if arrival not confirmed | §5 écran 4 | `WalkHome*`, `walk_sessions`, edge fn `walk-watchdog` |
| Complaint guide + recap for the police; the **unblurred** original stays on the phone | §5 écran 4 | `ComplaintRecapView`, original kept in app sandbox only |
| Routing: cleanliness → Bruxelles-Propreté/commune; road → commune/Bruxelles Mobilité; theft/harassment → **never** auto-sent | §6 | `routing_rules`, `outbox`, edge fn `dispatch-outbox` |
| Share cards: no personal data, no unblurred photo | §7 | Card renders category, street, age, status only |
| Avoid stigmatising streets: zones not points, thresholds, neutral wording, show resolutions | §8 | Copy guidelines + "resolved" counts in zone sheet |
| Rate limiting, serial-account detection | §8 | `submit_report()` limits; moderation queue |
| App Store UGC: flag content, moderation | §8 | `content_flags`, `moderation_queue` view |
| App is not an emergency service | §4.4, §8 | Persistent line on Help screen and onboarding |

Spec gap resolved by decision: the map legend uses **four** categories, matching the
four report icons (road, cleanliness, theft/aggression, harassment), instead of the
three map types listed in §5 écran 1. Harassment keeps its own colour so it never
gets diluted inside "insecurity".

---

## 2. Architecture

```
┌──────────────────────────── iOS app (SwiftUI, iOS 18+) ────────────────────────────┐
│ Features/  Map · Report · FollowUp · Help · Onboarding · Auth · Settings          │
│   View  ──binds──▶  @Observable @MainActor ViewModel  ──calls──▶  Services         │
│ DesignSystem/  tokens + components (no feature knowledge)                          │
│ Services/  Location · PhotoAnonymizer (Vision) · LocalStore (SwiftData) · Walk     │
│ Localization/  LanguageStore (in-app FR/NL/EN switch) · L10n                       │
└───────────────┬────────────────────────────────────────────────────────────────────┘
                │ imports
┌───────────────▼──────────────┐   ┌──────────────────────────────────────────────┐
│ BruskCore (SPM, Foundation)  │   │ BruskBackend (SPM)                           │
│ Domain models, TextGuard,    │◀──│ `Backend` protocol, SupabaseBackend,         │
│ geometry, palette + WCAG,    │   │ MockBackend (demo/previews)                  │
│ deep links, emergency dir.   │   │ depends on supabase-swift                    │
│ → unit-tested on Linux & Mac │   └────────────────────┬─────────────────────────┘
└──────────────────────────────┘                        │ HTTPS (RLS-enforced)
                                   ┌────────────────────▼─────────────────────────┐
                                   │ Supabase (EU region)                         │
                                   │ Auth (email OTP) · Postgres + PostGIS        │
                                   │ Storage (private bucket) · Edge Functions    │
                                   │ pg_cron jobs                                 │
                                   └──────────────────────────────────────────────┘
```

* **MVVM**: views are dumb; each feature has one `@Observable @MainActor` view model.
  View models depend on the `Backend` protocol, never on Supabase types, so every
  screen runs against `MockBackend` in previews and in demo mode (no keys configured).
* **Concurrency**: Swift 6 language mode, complete strict concurrency. Models are
  `Sendable` value types; Vision work runs off the main actor.
* **All server writes go through Postgres functions (RPC)**, never direct table
  inserts. One place validates geography, rate limits, text policy and thresholds.
  RLS stays on as defence in depth.
* **Offline**: SwiftData caches the last zones fetched and the user's own reports, so
  the map and follow-up screen open instantly and work without network.

### Why two Swift packages
`BruskCore` has zero dependencies and no Apple-only frameworks, so its logic (text
policy, geometry, palette contrast, status rules) is unit-tested anywhere with
`swift test`. `BruskBackend` isolates the Supabase SDK behind one protocol.

---

## 3. Folder structure

```
brusk-ios/
├── PLAN.md · README.md · AUDIT.md · HUMAN-WORK.md
├── project.yml                  XcodeGen spec (source of truth for the project)
├── Brusk.xcodeproj              generated from project.yml, committed
├── Config/                      Base.xcconfig, Secrets.example.xcconfig
├── App/
│   ├── BruskApp.swift · RootView.swift · AppEnvironment.swift
│   ├── Localization/            AppLanguage, LanguageStore, L10n
│   ├── DesignSystem/
│   │   ├── Tokens/              Colors, Typography, Spacing, Radius, Elevation,
│   │   │                        Materials, Motion, Haptics
│   │   └── Components/          buttons, chips, tiles, badges, banners, states,
│   │                            OTP field, step indicator, PreviewMatrix …
│   ├── Features/{Map,Report,FollowUp,Help,Onboarding,Auth,Settings}/
│   ├── Services/                Location, PhotoAnonymizer, LocalStore, Walk, Notifications
│   └── Resources/               Localizable.xcstrings, InfoPlist.xcstrings,
│                                Assets.xcassets, PrivacyInfo.xcprivacy
├── Packages/BruskKit/           Package.swift → BruskCore, BruskBackend (+ tests)
├── supabase/
│   ├── migrations/              0001 schema … 0005 cron  (authoritative SQL)
│   ├── functions/               walk-view, walk-watchdog, dispatch-outbox, delete-account
│   ├── templates/               trilingual OTP e-mail
│   └── tests/                   local PostGIS harness + scenario tests
└── Tools/l10n/                  catalog generator + checker (no hardcoded strings)
```

---

## 4. Data model

### 4.1 Server (Postgres, schema `public`)

| Table | Columns (complete list) | Notes |
|---|---|---|
| `profiles` | `id` (= auth user), `created_at`, `language`, `trust_weight`, `validated_reports`, `useful_confirmations`, `moderation_strikes`, `is_restricted` | **No name, no handle.** E-mail lives only in `auth.users` |
| `reports` | `id`, `author_id`, `category`, `location` (Point, EPSG:31370), `hex_i`, `hex_j`, `commune_code`, `occurred_at`, `created_at`, `note` (≤ 140), `photo_path`, `status`, `confirmed_at`, `routed_to`, `routed_at`, `resolved_at` | Exact point is never returned to anyone but its author |
| `confirmations` | `report_id`, `user_id`, `created_at` | PK (report, user); cannot confirm own report |
| `communes` | `nis_code`, `name_fr`, `name_nl`, `geom` | 19 communes. Geometry imported from UrbIS (human task) |
| `app_settings` | `key`, `value` | Tunable thresholds (§4.2 "à calibrer") |
| `routing_rules` | `category`, `destination` | §6 |
| `outbox` | `id`, `report_id`, `destination`, `created_at`, `sent_at`, `last_error` | Dispatch queue to services |
| `content_flags` | `id`, `flagger_id`, `category`, `hex_i`, `hex_j`, `reason`, `created_at`, `handled_at` | App Store UGC moderation |
| `walk_sessions` | `id`, `owner_id`, `share_token`, `contact_email`, `language`, `started_at`, `expected_arrival_at`, `last_lat`, `last_lon`, `last_seen_at`, `status`, `alerted_at`, `ended_at` | Purged 24 h after the session ends. Only the **last** position is kept, never a trail |

Enums: `report_category (road, cleanliness, insecurity, harassment)`,
`report_status (pending, confirmed, sent, resolved)`, `app_language (fr, nl, en)`,
`walk_status (active, arrived, alerted, cancelled)`,
`flag_reason (personal_data, offensive, wrong_place, other)`.

### 4.2 Zones: hexagonal cells, aggregated on read
* Every report is assigned to a hexagon `(hex_i, hex_j)` with a **120 m edge**
  (≈ 37 000 m²), computed with `ST_HexagonGrid` in Belgian Lambert 72 (metres).
* A cell × category is **visible** only once its reports are `confirmed`, which
  requires (defaults, editable in `app_settings`):
  * `min_distinct_users = 3` distinct people (reporters ∪ confirmers),
  * `min_trust_weight = 1.0` summed trust of those people,
  * all within `window_days = 30`.
* `get_zones()` returns hexagon outlines (GeoJSON, WGS84), counts, intensity (0–1),
  trend (last 30 days vs the previous 30), `unresolved_since` and resolved count.

### 4.3 Trust score (§4.2)
```
trust_weight = clamp(0.30
                     + 0.15 × validated_reports      -- my reports confirmed by others
                     + 0.05 × useful_confirmations   -- my confirmations that helped confirm a zone
                     + 0.10 × (account older than 14 days)
                     − 0.25 × moderation_strikes,
                     0.10, 1.00)
restricted accounts → 0.10
```
Three brand-new accounts (3 × 0.30 = 0.90) cannot make a zone appear on their own.
They need a fourth person or one established neighbour. This blunts serial-account
manipulation while keeping the MVP usable.

### 4.4 Local cache (SwiftData)
* `StoredReport`: the user's own reports (id, category, coordinate, timestamps,
  status, note, `originalPhotoFile`). The **unblurred original** is written to
  `Application Support/Originals/` with `FileProtectionType.complete`, excluded
  from backup, and never uploaded (§5 écran 4).
* `CachedZone`: the last zones payload per filter, for an instant map and offline use.

---

## 5. Supabase SQL schema with RLS (summary)

The authoritative SQL lives in `supabase/migrations/`. Key excerpts:

```sql
create extension if not exists postgis;

create type report_category as enum ('road','cleanliness','insecurity','harassment');
create type report_status   as enum ('pending','confirmed','sent','resolved');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  language app_language not null default 'fr',
  trust_weight real not null default 0.30 check (trust_weight between 0.10 and 1.00),
  validated_reports int not null default 0,
  useful_confirmations int not null default 0,
  moderation_strikes int not null default 0,
  is_restricted boolean not null default false
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references profiles(id) on delete set null,
  category report_category not null,
  location geometry(Point, 31370) not null,
  hex_i int not null, hex_j int not null,
  commune_code text references communes(nis_code),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  note text check (note is null or char_length(note) <= 140),
  photo_path text,
  status report_status not null default 'pending',
  confirmed_at timestamptz, routed_to text, routed_at timestamptz, resolved_at timestamptz
);

-- RLS: deny by default, own rows only. Public data only through aggregate RPCs.
alter table reports enable row level security;
create policy reports_select_own on reports for select to authenticated
  using (author_id = auth.uid());
-- no insert/update/delete policies: writes go through SECURITY DEFINER functions

alter table profiles enable row level security;
create policy profiles_select_own on profiles for select to authenticated using (id = auth.uid());

alter table confirmations enable row level security;
create policy confirmations_select_own on confirmations for select to authenticated
  using (user_id = auth.uid());

alter table walk_sessions enable row level security;
create policy walk_own on walk_sessions for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

alter table communes enable row level security;
create policy communes_read on communes for select to anon, authenticated using (true);

-- Storage: private bucket 'report-photos', path '<uid>/<report-id>.jpg'
create policy photos_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'report-photos' and (storage.foldername(name))[1] = auth.uid()::text);
```

RPC surface (all `SECURITY DEFINER`, `search_path` pinned, `EXECUTE` granted explicitly):

| Function | Caller | Purpose |
|---|---|---|
| `get_zones(period_days, categories[], commune)` | anon, authenticated | Aggregated visible zones only |
| `zone_detail(category, hex_i, hex_j)` | anon, authenticated | Counts, trend, 8-week sparkline, neighbourhood score |
| `submit_report(category, lat, lon, occurred_at, note, photo_path)` | authenticated | Validates bounds, time, text policy, rate limit, then refreshes the cell |
| `nearby_reports(lat, lon)` | authenticated | Recent reports nearby that the caller can confirm (cell centre only, distance rounded to 50 m) |
| `confirm_report(report_id, lat, lon)` | authenticated | One-tap confirmation, proximity check, refreshes the cell |
| `my_reports()` | authenticated | The caller's own reports with coordinates |
| `delete_my_report(id)` | authenticated | Right to erasure for one report |
| `set_language(lang)` | authenticated | Language used for e-mails |
| `flag_zone(category, hex_i, hex_j, reason)` | authenticated | Moderation |
| `my_trust()` | authenticated | The caller's own trust level (never anyone else's) |

---

## 6. Localization setup

* **String Catalog** `App/Resources/Localizable.xcstrings`, development language `en`,
  localizations `fr`, `nl`, `en`. `InfoPlist.xcstrings` covers permission prompts.
* **Keys are semantic** (`report.step.what.title`), so translators never edit
  English source text. Plurals use catalog plural variations
  (`followup.age.days %lld`).
* **Dates and numbers** are formatted with the region-specific locales `fr_BE`,
  `nl_BE` and `en_BE` (24 h clock, `dd/MM`, Belgian conventions).
* **In-app picker** (Settings → Language: System / Français / Nederlands / English):
  `LanguageStore` injects `\.locale` at the root. SwiftUI `Text`, `Label` and
  `accessibilityLabel(Text)` re-resolve instantly. Strings needed outside views
  (notifications, share text, e-mail language) go through `L10n.string(_:)`, which
  reads the matching `.lproj` bundle. The choice is also written to `AppleLanguages`
  so system-rendered UI follows on the next launch.
* **OTP e-mail**: one Supabase template with `{{ if eq .Data.language "nl" }}`
  branches. The language is stored in user metadata at sign-up and updated by the
  picker.
* **Long Dutch words**: no fixed widths on text. Every label may wrap, chips use
  `ViewThatFits`, and the 2 × 2 grids collapse to one column at accessibility
  sizes. Previews render FR / NL / EN side by side (`PreviewMatrix`).
* **Guardrail**: `Tools/l10n/check.py` fails if a Swift literal looks like UI text,
  if a key used in code is missing from the catalog, or if any key lacks a
  translated `fr`, `nl` or `en` value.

---

## 7. Design direction

Calm, civic, trustworthy. The map is the hero and the UI is quiet glass around it.
* Accent **Iris**, a deep muted indigo-violet that nods to the Brussels-Capital
  iris emblem, replaces default blue.
* Category colours are muted and earthy: ochre (road), sage (cleanliness), brick
  (theft/aggression), plum (harassment). Each has light and dark values verified
  ≥ 4.5:1 for text and ≥ 3:1 for non-text, checked by unit tests in `BruskCore`.
* *Decision made during the build:* text-grade category colours were too close to one
  another to identify map zones (colour-blind check failed). Zones and charts use a
  separate `mark*` palette, searched in OKLCH and validated for all pairs (CVD ΔE ≥ 10,
  normal-vision ΔE ≥ 17), plus a category glyph on each zone when zoomed in.
* *Decision made during the build:* share cards exist for road and cleanliness only.
  Public pressure targets a service; sharing "harassment, rue X" would stigmatise a
  street (spec §8).
* Warm paper neutrals in light mode, soft charcoal (not pure black) in dark mode.
* SF Pro, Dynamic Type everywhere, an 8 pt grid, continuous corners, springs
  ≤ 300 ms, haptics on commit actions only.

---

## 8. Verification per step (what "builds" means here)

The development container is Linux, which cannot run Xcode. Each step is verified
with what can run here, and the remainder is listed for a Mac:

| Check | Here (Linux) | On a Mac |
|---|---|---|
| `BruskCore` / `BruskBackend` compile + unit tests | `swift build && swift test` | same |
| SQL schema, RLS, thresholds, trust | Postgres 16 + PostGIS harness in `supabase/tests` | `supabase db reset` |
| Project file | generated with XcodeGen | open `Brusk.xcodeproj` |
| Strings complete in 3 languages, no hardcoded UI text | `Tools/l10n/check.py` | Xcode catalog view |
| SwiftUI app target compile, previews, device run | **not possible here** | `xcodebuild -scheme Brusk` |

---

## 9. Build order
1. PLAN (this file)
2. Design system + core package + localization tooling + Xcode project
3. Screens (Map, Report, Follow-up, Help, Onboarding/Auth/Settings)
4. Server logic (SQL, RLS, trust, confirmation, edge functions) with tests
5. Self-audit and fixes, README, human-work list
