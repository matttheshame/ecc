# Brusk — the living map of Brussels

iOS app for reporting dangerous roads, dirt and fly-tipping, theft/aggression and
harassment **by place, never by person**. Zones appear only when several neighbours
confirm the same thing. Trilingual: French, Dutch, English.

> Working name from the product spec (annex A). Trademark, App Store, domain and X
> availability must be checked before launch (see [HUMAN-WORK.md](HUMAN-WORK.md)).

| Document | What's in it |
|---|---|
| [PLAN.md](PLAN.md) | Architecture, data model, SQL schema summary, localization design |
| [AUDIT.md](AUDIT.md) | Self-audit: findings, fixes, what remains to check on a Mac |
| [HUMAN-WORK.md](HUMAN-WORK.md) | What still needs people: legal, numbers, Dutch review, moderation… |

## Status, honestly

| Part | State |
|---|---|
| `Packages/BruskKit` (domain, text policy, palette, Supabase client) | Compiles; 32 tests pass (`swift test`) |
| Supabase SQL (schema, RLS, logic, API) | 77 pgTAP tests pass on Postgres 16 + PostGIS |
| Edge functions (Deno/TypeScript) | Type-check with `deno check` |
| Strings | 342 keys, FR/NL/EN complete, enforced by `Tools/l10n/check.py` |
| **iOS app target (SwiftUI)** | **Written and syntax-checked, but never compiled**: it was built on Linux, where Xcode can't run. Expect to fix a few SDK-level errors on first build. |

## Requirements

* Xcode 26 (Swift 6.2, iOS 26 SDK). Deployment target **iOS 18**. Liquid Glass is used on
  iOS 26; iOS 18–25 get the material fallback automatically.
* [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you add or move files
  (`project.yml` is the source of truth; `Brusk.xcodeproj` is generated and committed).
* Supabase CLI, Docker (for a local Supabase), Deno (edge functions).

## Run it in 2 minutes (demo mode)

```bash
open Brusk.xcodeproj        # scheme "Brusk", any iPhone simulator, Run
```

Without Supabase keys, the app runs on **local demo data**. A "Demo data" pill is shown on
the map, and any 6-digit code (except 000000) signs you in. Release builds refuse to
compile without keys.

## Connect Supabase

### 1. Project

Create a project in an **EU region** (spec §8: EU hosting), then:

```bash
supabase link --project-ref <ref>
supabase db push                  # applies supabase/migrations/*.sql
```

The migrations create the schema, RLS policies, functions, the private `report-photos`
bucket and the 19 communes.

### 2. App keys

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Fill in `SUPABASE_HOST` (for example `abcd.supabase.co`, **without** `https://`, because
xcconfig treats `//` as a comment) and `SUPABASE_ANON_KEY` (public by design: RLS
protects the data). Set your team and bundle id in `project.yml`, then run
`xcodegen generate`.

### 3. Auth (e-mail code only)

Dashboard → Authentication:

* Providers: **Email on**, "Confirm email" off, OTP length **6**, expiry 600 s. Phone off.
* Email templates: paste `supabase/templates/otp.html` into **Magic Link** and
  **Confirm signup**. It switches language on `.Data.language`, which the app stores at
  sign-up and on every language change. Subject:
  `Brusk · Votre code · Je code · Your code`.
* SMTP: configure a production SMTP (Supabase's built-in sender is rate-limited).
* Recommended: enable CAPTCHA (Turnstile/hCaptcha) against e-mail bombing.

`supabase/config.toml` mirrors these settings for `supabase start`.

### 4. Edge functions

```bash
supabase functions deploy walk-view --no-verify-jwt   # public page opened by the walk contact
supabase functions deploy walk-watchdog
supabase functions deploy dispatch-outbox
supabase functions deploy maintenance
supabase functions deploy delete-account

supabase secrets set RESEND_API_KEY=... EMAIL_FROM="Brusk <alerts@your-domain>" \
  ROUTING_EMAILS='{"bruxelles_proprete":"...","commune":"...","commune:21009":"..."}'
```

`ROUTING_EMAILS` maps the routing destinations to addresses, optionally per commune
(NIS code). Destinations without an address stay queued, and the report remains
"confirmed" in the app.

### 5. Scheduled jobs

Enable the **pg_cron** and **pg_net** extensions, then add two Vault secrets
(`project_url` = `https://<ref>.supabase.co`, `service_role_key`), then re-run the
scheduling block at the top of `supabase/migrations/20261014000006_storage_cron_seed.sql`
in the SQL editor:

| Job | Schedule | Does |
|---|---|---|
| `walk-watchdog` | every minute | e-mails a walk's contact once, if arrival isn't confirmed 5 min after the deadline |
| `dispatch-outbox` | every 5 min | sends confirmed road/cleanliness reports to the services |
| `maintenance` | daily 03:17 | purges walk data after 24 h; anonymises reports after 12 months |

### 6. Commune boundaries

Report → commune assignment uses polygons from **UrbIS** (Brussels region open data),
EPSG:31370:

```bash
ogr2ogr -f PostgreSQL "PG:$DATABASE_URL" UrbAdm_MUNICIPALITY.gpkg \
  -nln communes_import -t_srs EPSG:31370 -nlt MULTIPOLYGON
```

```sql
update public.communes c set geom = i.geom
from communes_import i where i.<nis_code_column> = c.nis_code;
```

Until then, zones work everywhere; only the commune filter has nothing to filter on.

### 7. Tunable thresholds

Calibrate during the MVP (spec §4.2) in `public.app_settings`. No redeploy is needed:

| Key | Default | Meaning |
|---|---|---|
| `min_distinct_users` | 3 | distinct people (reporters ∪ confirmers) before a zone shows |
| `min_trust_weight` | 1.0 | their summed trust (a new account weighs 0.30) |
| `window_days` | 30 | how long a report counts towards confirmation |
| `hex_edge_m` | 120 | zone cell size |
| `max_reports_per_day` | 10 | rate limit |

## Tests

```bash
(cd Packages/BruskKit && swift test)                  # domain, palette contrast, text policy, backend
supabase/tests/run_local.sh                            # plain Postgres + PostGIS + pgTAP
supabase db reset && supabase test db                  # or against a local Supabase
python3 Tools/l10n/check.py                            # no hardcoded UI strings, 3 languages complete
(cd supabase/functions && deno check --node-modules-dir=auto */index.ts)
```

## Localization

Strings live in `App/Resources/Localizable.xcstrings` (semantic keys, `en` source,
`fr`/`nl`/`en` values) and `InfoPlist.xcstrings` (permission prompts). They are generated
from `Tools/l10n/strings/*.py`:

```bash
python3 Tools/l10n/build_catalog.py && python3 Tools/l10n/check.py
```

Once translators work in Xcode or a TMS, retire the generator and edit the catalog
directly. The in-app picker (Settings → Language) switches instantly by injecting
`\.locale`. Dates and numbers use `fr_BE`, `nl_BE` and `en_BE`.

## Layout

```
App/                  SwiftUI app (MVVM): DesignSystem, Features, Services, Localization
Packages/BruskKit/    BruskCore (pure Swift, tested) + BruskBackend (Supabase / demo)
supabase/             migrations, edge functions, OTP template, pgTAP tests
Tools/l10n/           string catalog generator + checker
Config/               xcconfig (secrets git-ignored)
```
