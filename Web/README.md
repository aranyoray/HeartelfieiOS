# Heartelfie — U.S. Heart & Circulatory Wellness Atlas

An interactive **3D atlas** of U.S. county- and state-level **heart & circulatory
wellness awareness**. Every county is shaded on a **pink → red** ramp (redder = a
higher community indicator) on a map you can **tilt and rotate** for a perspective
view, so geographic patterns — the Southeast, Appalachia — and their change over
time pop out at a glance.

Community wellness-awareness indicators (age-adjusted, adults ≥18) — these describe
**geographic areas, never individuals**:

- **Circulatory Strain**
- **Heart Health**
- **Brain Circulation**

> These are community-level, area-based awareness indicators derived from public
> CDC PLACES health estimates — **not medical advice** and **not** measurements of
> any person. See the medical disclaimer in `/terms`.

> Inspired by the [Climate Vulnerability Index map](https://map.climatevulnerabilityindex.org/).

## Features

- 🗺️ **Tilted-perspective choropleth** (deck.gl) — flat pink→red polygons on a map plane you can pan, tilt & rotate.
- ⏱️ **Time slider** with play/animate across years.
- 🔀 **Compare two years side by side** with a camera-synced split view.
- 🏛️ **County ↔ State** mode toggle.
- 🔎 **Fuzzy search** for any ZIP code, county, or state — autozooms to it.
- 🛈 **Hover** any area for its exact value.
- 📈 **Compare 2–3 areas** by clicking the map; trend line graphs render below.
- 📱 Responsive, plus **/privacy**, **/support**, and **/terms** pages for app-store submission.

## Data

Health measures come from **[CDC PLACES](https://www.cdc.gov/places/)** — model-based,
small-area estimates derived from the Behavioral Risk Factor Surveillance System
(BRFSS), **age-adjusted**. County & state geometry comes from the **U.S. Census
Bureau** (via the [`us-atlas`](https://github.com/topojson/us-atlas) package).

### ⚠️ The committed dataset is a realistic PLACEHOLDER

`data.cdc.gov` is not reachable from every build sandbox, so the repo ships with
a **synthetic** dataset generated in the **exact CDC PLACES schema**. The
geography is realistic (the Southeast / Appalachia run higher; Mountain West /
Upper Midwest run lower) but **the numbers are generated, not measured — do not cite them.**
The app shows a **DEMO DATA** badge while this is in effect.

### Swapping in real CDC data (no code changes)

1. Allow `data.cdc.gov` in your environment's network egress settings.
2. (Optional) set release dataset ids / token in `.env` (see `.env.example`).
3. Run:

   ```bash
   npm run data:scrape
   ```

This rewrites `public/data/**` and `public/geo/**` with real values and flips the
`isPlaceholder` flag off — the frontend reads everything from `meta.json`, so no
component changes are required.

Regenerate the placeholder any time with `npm run data:placeholder`.

## Quick start

```bash
npm install
npm run data:placeholder   # generate data + geometry + search index (already committed)
npm run dev                # http://localhost:5173
```

Build / preview:

```bash
npm run build
npm run preview
```

## Project structure

```
scripts/
  lib/schema.mjs        Measures, years, state burden, deterministic RNG (shared)
  lib/geo.mjs           us-atlas → counties/states (50 + DC) + centroids
  lib/output.mjs        Writes meta/county/state/places + copies geometry (shared)
  gen-placeholder.mjs   Synthetic dataset in CDC PLACES schema
  scrape-cdc.mjs        Real CDC PLACES Socrata scraper (same output)
public/
  data/                 meta.json, county/<M>.json, state/<M>.json, places.json
  geo/                  counties-10m.json, states-10m.json (TopoJSON)
src/
  components/           MapDeck, MapStage, TopBar, SearchBar, TimeSlider,
                        MetricSelector, ModeToggle, Legend, ComparisonPanel, AboutModal
  pages/                PrivacyPage, SupportPage, DocLayout
  lib/                  data, hooks, colors, format, types, constants
  store.ts              Zustand app state (camera, metric, mode, year, selections)
```

## Tech stack

React + TypeScript + Vite · **deck.gl** (tilted/rotatable flat choropleth, self-contained
WebGL — no basemap tiles needed) · **Fuse.js** (fuzzy search) · **Recharts** (trend lines) ·
**Zustand** (state) · **d3-scale/-interpolate** (color ramp).

## Deployment

Static SPA. `vercel.json` rewrites non-asset routes to `index.html` so deep links
(`/privacy`, `/support`, `/terms`) work, and sets baseline security headers
(`Referrer-Policy`, `X-Content-Type-Options`, `X-Frame-Options`,
`Permissions-Policy`) plus long-lived cache on hashed assets. Any static host
works with an equivalent SPA fallback.

## Support, privacy & terms

In-app **/support**, **/privacy**, and **/terms** pages are included for App
Store / Play Store review. Support contact: **support@heartelfie.app** (placeholder —
set a real, monitored address before submission).

## Disclaimer

For information and education only — **not medical advice**, and the shipped demo
numbers are synthetic. Figures describe geographic areas, never individuals.
