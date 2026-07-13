// Generates a realistic PLACEHOLDER dataset in the exact CDC PLACES schema so
// the entire app works end-to-end before data.cdc.gov is reachable. Values are
// SYNTHETIC: a per-state cardiovascular-burden index (Stroke Belt / Appalachia
// high, Mountain West / Upper Midwest low) plus a stable per-county offset and
// a small per-measure yearly trend. Reproducible (seeded). Replace by running
// `npm run data:scrape` once data.cdc.gov is allowlisted.
import { loadGeo } from './lib/geo.mjs'
import { writeDataset, writePlaces, copyGeometry } from './lib/output.mjs'
import {
  MEASURES,
  YEARS,
  MID_YEAR,
  STATE_BURDEN,
  signedNoise,
  clamp,
  round1,
} from './lib/schema.mjs'

console.log('Loading geometry (us-atlas)…')
const geo = loadGeo()
console.log(`  ${geo.counties.length} counties, ${geo.states.length} states (50 + DC)`)

// Stable per-county burden in [0,1] (constant across years -> smooth trends).
const burden = new Map()
for (const c of geo.counties) {
  const base = STATE_BURDEN[c.st] ?? 0.5
  burden.set(c.fips, clamp(base + signedNoise(`burden:${c.fips}`) * 0.18, 0, 1))
}

const measureValues = {}
for (const m of MEASURES) {
  const county = {}
  const state = {}
  const { lo, hi, trend, noise } = m.gen

  for (const year of YEARS) {
    const yKey = String(year)
    county[yKey] = {}
    // accumulate per-state for the aggregate
    const acc = new Map() // stfips -> {sum,n}

    for (const c of geo.counties) {
      const b = burden.get(c.fips)
      const trendShift = trend * (year - MID_YEAR)
      const wobble = signedNoise(`v:${m.id}:${c.fips}:${year}`) * noise
      const value = clamp(round1(lo + b * (hi - lo) + trendShift + wobble), m.range[0], m.range[1])
      county[yKey][c.fips] = value
      const a = acc.get(c.stfips) ?? { sum: 0, n: 0 }
      a.sum += value
      a.n += 1
      acc.set(c.stfips, a)
    }

    state[yKey] = {}
    for (const [stfips, a] of acc) state[yKey][stfips] = round1(a.sum / a.n)
  }
  measureValues[m.id] = { county, state }
  console.log(`  generated ${m.id}`)
}

const meta = writeDataset({
  measureValues,
  years: YEARS,
  source: 'SYNTHETIC PLACEHOLDER — schema-compatible with CDC PLACES (age-adjusted prevalence). Not real data.',
  isPlaceholder: true,
  countyCount: geo.counties.length,
  notes: [
    'These numbers are SYNTHETIC and for layout/QA only — do not cite them.',
    'Geography is realistic (the Southeast & Appalachia run higher) but values are generated, not measured.',
    'State values are the unweighted mean of their counties.',
    'Run `npm run data:scrape` after allowlisting data.cdc.gov to replace with real CDC PLACES data.',
  ],
})

console.log('Writing search index (places.json)…')
const counts = writePlaces(geo)
console.log(`  counties=${counts.counties} states=${counts.states} zips=${counts.zips}`)

console.log('Copying geometry to public/geo…')
copyGeometry()

console.log(`\nDone. ${meta.measures.length} measures × ${meta.years.length} years. PLACEHOLDER=${meta.isPlaceholder}`)
