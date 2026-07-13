// Real CDC PLACES scraper. Produces the SAME files as gen-placeholder.mjs, so
// swapping real data in requires no frontend changes.
//
// Prerequisite: data.cdc.gov must be reachable (add it to the environment's
// network egress allowlist). Then:  npm run data:scrape
//
// CDC PLACES county data is published one *release* per data year, each with
// its own Socrata dataset id. List the releases you want on the time axis via
// PLACES_COUNTY_DATASETS (comma-separated ids); we group output by whatever
// `year` value each row reports, so multiple years per dataset also work.
//
//   CDC_APP_TOKEN            optional Socrata app token (higher rate limit)
//   PLACES_COUNTY_DATASETS   e.g. "swc5-untb,d3i6-k6z5,<older release ids>"
//
// Find release dataset ids at https://data.cdc.gov (search "PLACES County Data").
import { loadGeo } from './lib/geo.mjs'
import { writeDataset, writePlaces, copyGeometry } from './lib/output.mjs'
import { MEASURE_IDS, DATA_VALUE_TYPE, INCLUDED_STATE_FIPS, round1, MEASURES } from './lib/schema.mjs'

const HOST = 'https://data.cdc.gov'
const DATASETS = (process.env.PLACES_COUNTY_DATASETS || 'swc5-untb')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean)
const APP_TOKEN = process.env.CDC_APP_TOKEN || ''
const PAGE = 50000

const measureInList = MEASURE_IDS.map((m) => `'${m}'`).join(',')

async function fetchJson(url, attempt = 0) {
  try {
    const res = await fetch(url, {
      headers: APP_TOKEN ? { 'X-App-Token': APP_TOKEN } : {},
    })
    if (res.status === 403) {
      throw new Error(
        `403 from ${HOST}. Add data.cdc.gov to this environment's network egress allowlist, then retry.`,
      )
    }
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`)
    return await res.json()
  } catch (err) {
    if (attempt < 4 && !String(err.message).includes('allowlist')) {
      const wait = 2000 * 2 ** attempt
      console.warn(`  retry ${attempt + 1} in ${wait}ms (${err.message})`)
      await new Promise((r) => setTimeout(r, wait))
      return fetchJson(url, attempt + 1)
    }
    throw err
  }
}

function num(row, ...keys) {
  for (const k of keys) {
    if (row[k] != null && row[k] !== '') {
      const v = Number(row[k])
      if (Number.isFinite(v)) return v
    }
  }
  return undefined
}

async function scrapeDataset(datasetId, acc) {
  const where = `measureid in(${measureInList}) AND data_value_type='${DATA_VALUE_TYPE}' AND data_value IS NOT NULL`
  let offset = 0
  let total = 0
  for (;;) {
    const url =
      `${HOST}/resource/${datasetId}.json?$where=${encodeURIComponent(where)}` +
      `&$limit=${PAGE}&$offset=${offset}&$order=locationid`
    const rows = await fetchJson(url)
    if (!rows.length) break
    for (const row of rows) {
      const fips = String(row.locationid || row.countyfips || '').padStart(5, '0')
      if (fips.length !== 5 || !INCLUDED_STATE_FIPS.has(fips.slice(0, 2))) continue
      const measure = row.measureid
      const year = String(row.year)
      const value = num(row, 'data_value', 'datavalue')
      if (value == null || !MEASURE_IDS.includes(measure)) continue
      const pop = num(row, 'totalpopulation', 'totalpop18plus') ?? 0

      const m = (acc[measure] ??= { county: {}, popByYearFips: {} })
      ;(m.county[year] ??= {})[fips] = round1(value)
      ;(m.popByYearFips[year] ??= {})[fips] = pop
    }
    total += rows.length
    console.log(`  ${datasetId}: +${rows.length} rows (offset ${offset})`)
    if (rows.length < PAGE) break
    offset += PAGE
  }
  return total
}

console.log('Loading geometry (us-atlas)…')
const geo = loadGeo()

const acc = {}
for (const ds of DATASETS) {
  console.log(`Scraping dataset ${ds}…`)
  await scrapeDataset(ds, acc)
}

// Build the final measureValues, aggregating counties -> states by population.
const measureValues = {}
const yearSet = new Set()
for (const m of MEASURES) {
  const a = acc[m.id]
  if (!a) {
    console.warn(`  ! no rows for ${m.id}`)
    continue
  }
  const state = {}
  for (const year of Object.keys(a.county)) {
    yearSet.add(Number(year))
    const weighted = new Map() // stfips -> {wsum, psum, sum, n}
    for (const [fips, value] of Object.entries(a.county[year])) {
      const stfips = fips.slice(0, 2)
      const pop = a.popByYearFips[year]?.[fips] ?? 0
      const w = weighted.get(stfips) ?? { wsum: 0, psum: 0, sum: 0, n: 0 }
      w.wsum += value * pop
      w.psum += pop
      w.sum += value
      w.n += 1
      weighted.set(stfips, w)
    }
    state[year] = {}
    for (const [stfips, w] of weighted) {
      state[year][stfips] = round1(w.psum > 0 ? w.wsum / w.psum : w.sum / w.n)
    }
  }
  measureValues[m.id] = { county: a.county, state }
}

const years = [...yearSet].sort((a, b) => a - b)
if (!years.length) {
  console.error('No data scraped. Check dataset ids / allowlist and try again.')
  process.exit(1)
}

writeDataset({
  measureValues,
  years,
  source: `CDC PLACES, Local Data for Better Health (data.cdc.gov; datasets: ${DATASETS.join(', ')}). Age-adjusted prevalence.`,
  isPlaceholder: false,
  countyCount: geo.counties.length,
  notes: [
    'Model-based small-area estimates from CDC PLACES (derived from BRFSS).',
    'State values are population-weighted means of county estimates.',
    'PLACES releases are cross-sectional; cross-year comparisons reflect release/methodology differences.',
  ],
})

console.log('Writing search index + geometry…')
writePlaces(geo)
copyGeometry()
console.log(`\nDone. years=${years.join(', ')} measures=${Object.keys(measureValues).join(', ')}`)
