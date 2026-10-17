---
name: using-brussels-open-data
description: Use when an app imports, shows or links to FixMyStreet Brussels incidents, Brussels Mobility roadworks or Brussels market data; when a fixmystreet.brussels link opens the home page instead of the incident; or when checking a deep link into a single-page web app that answers HTTP 200 for every path.
---

# Using Brussels open data

## FixMyStreet Brussels

**Bulk data**
- WFS layer `bm_maintenance_and_planning:fims` on `https://data.mobility.brussels/geoserver/wfs`.
  CC0, updated daily, about 627,000 records, so always filter.
- `CQL_FILTER` and `sortBy` work. `srsName=EPSG:4326` returns longitude/latitude; the
  native projection is Belgian Lambert 72.
- Fields:
  - `fims_id`, `category`;
  - `status`: `CREATED`, `PROCESSING` or `CLOSED`;
  - `createddate`, `updateddate`;
  - `road_fr`, `road_nl`;
  - `geom`.

```text
https://data.mobility.brussels/geoserver/wfs?service=WFS&version=2.0.0&request=GetFeature
  &outputFormat=json&srsName=EPSG:4326&typeNames=bm_maintenance_and_planning:fims&count=50000
  &CQL_FILTER=category IN (4010,4011) AND status IN ('CREATED','PROCESSING') AND createddate >= '2026-10-01'
  &propertyName=fims_id,category,status,createddate,updateddate,road_fr,road_nl,geom
```

- Shown unencoded for reading. Encode the parameters when sending: `URLSearchParams`,
  or `curl -G --data-urlencode`.
- Keep each answer under `count` by filtering on dates; a daily import only needs what
  changed.
- To read more than `count`, page with `startIndex` and a stable `sortBy=fims_id`.

**One incident**
- `fims_id` is the public incident number: the site, its API and its search all use
  this same number.
- **Public page: `https://fixmystreet.brussels/<fims_id>`.**
  - There is no `/incidents/<id>` page and no language prefix. Unknown paths land on the
    home page with HTTP 200.
  - The site picks its language from the `fmxlg` cookie, otherwise from the browser
    language. A link cannot choose it.
- JSON: `https://fixmystreet.brussels/api/incidents/<id>`. It gives:
  - status and dates;
  - address in FR/NL;
  - category in FR/NL/EN;
  - the commune and service in charge.
- Category tree: `https://fixmystreet.brussels/api/categories`.

**The site's wording for the number**
- FR: "Numéro d'incident" ("N° d'incident" in its search).
- NL: "Incidentnummer". EN: "Incident number".
- All the site's texts: `https://fixmystreet.brussels/assets/i18n/{fr,nl,en}.json`.

**Categories**

| Topic | Codes |
|---|---|
| Illegal dumps | 4010 bulky waste < 1 m³, 4011 bulky waste > 1 m³, 3304 green waste, 3307 oil, paint and chemicals, 10023 gas cylinders, 10019–10022 dumps by a bottle bank, 3030 construction waste |
| Uncollected bags | 4001–4006 bag not collected, 4051–4056 torn bag |
| Potholes | 3027 roadway, 2410 sidewalk, 2420 cycle path |

## Other sources (checked October 2026)

**Usable**
- **Roadworks on regional roads:**
  - WFS layer `bm_traffic:events` on `https://data.mobility.brussels/geoserver/bm_traffic/wfs`;
  - CC0, live;
  - its feature ids change, so build your own key, e.g. `datex|start_time|lon4|lat4`;
  - the REST API at api.mobility.brussels needs a token, the WFS does not.
- **Markets**, on `https://opendata.bruxelles.be`:
  - `marches-alimentaires-region-bruxelloise`: 64 markets, CC BY 4.0, attribution
    required;
  - `marches-plein-air-vbx`: 12 markets, CC0;
  - days come as words; hours come as "08:00:00 - 14:00:00" or "Samedi / 9h - 17h".

**Not usable**
- `bm_traffic:worksites_comm`: no dates, last update 2024-11.
- `bm_osiris:chantiers_actu`: every worksite ended by 2019.
- Osiris: login only. Moving permits and works on communal streets are not open data.
- `bm_parking:*`: permanent rules, last updated 2019.

## Checking a deep link into a single-page app

An HTTP 200 proves nothing: every path returns the same `index.html`.

1. Read the router in the main bundle:

   ```bash
   curl -sS -o main.js "https://fixmystreet.brussels/static/main.js"
   grep -oE 'path:"[^"]{0,60}"' main.js | sort -u
   grep -oE '.{300}path:":incidentId".{200}' main.js
   ```

   - Find the array passed to `forRoot(...)`. Its routes hang off the site root.
   - `{path:"**",redirectTo:""}` sends unknown paths home.
   - The proxy can drop large downloads: retry.
2. Check the id through the site's own API (`/api/incidents/<id>` returns it).
3. When you can, open the link in a real browser: Safari on the simulator, or Playwright.
4. Pin the URL format in a unit test.
