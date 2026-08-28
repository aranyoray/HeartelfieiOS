// Shared output stage for both data pipelines (placeholder + real scraper).
// Guarantees identical on-disk layout so the frontend never has to care which
// pipeline produced the data.
//
//   public/data/meta.json                 — measures, years, color domains, provenance
//   public/data/county/<MEASUREID>.json   — { [year]: { [countyFips]: value } }
//   public/data/state/<MEASUREID>.json     — { [year]: { [stateFips]: value } }
//   public/data/places.json               — fuzzy-search index (counties/states/zips)
//   public/geo/counties-10m.json          — TopoJSON geometry (decoded client-side)
//   public/geo/states-10m.json
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { MEASURES, YEARS, DATA_VALUE_TYPE } from './schema.mjs'

const require = createRequire(import.meta.url)
const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const ROOT = path.resolve(__dirname, '..', '..')
const DATA_DIR = path.join(ROOT, 'public', 'data')
const GEO_DIR = path.join(ROOT, 'public', 'geo')

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true })
}

function percentile(sortedAsc, p) {
  if (sortedAsc.length === 0) return 0
  const idx = (sortedAsc.length - 1) * p
  const lo = Math.floor(idx)
  const hi = Math.ceil(idx)
  if (lo === hi) return sortedAsc[lo]
  return sortedAsc[lo] + (sortedAsc[hi] - sortedAsc[lo]) * (idx - lo)
}

/**
 * @param {object} args
 * @param {Record<string,{county:Record<string,Record<string,number>>,state:Record<string,Record<string,number>>}>} args.measureValues
 * @param {string[]} args.years
 * @param {string} args.source        human-readable provenance string
 * @param {boolean} args.isPlaceholder
 * @param {string[]} args.notes
 * @param {number} args.countyCount
 */
export function writeDataset({ measureValues, years, source, isPlaceholder, notes, countyCount }) {
  ensureDir(path.join(DATA_DIR, 'county'))
  ensureDir(path.join(DATA_DIR, 'state'))

  const metaMeasures = []
  for (const m of MEASURES) {
    const mv = measureValues[m.id]
    if (!mv) continue
    fs.writeFileSync(path.join(DATA_DIR, 'county', `${m.id}.json`), JSON.stringify(mv.county))
    fs.writeFileSync(path.join(DATA_DIR, 'state', `${m.id}.json`), JSON.stringify(mv.state))

    // Color domain from the 2nd–98th percentile of county values (across all
    // years) so a handful of extreme counties don't wash out the ramp.
    const all = []
    for (const yr of Object.keys(mv.county)) {
      for (const v of Object.values(mv.county[yr])) all.push(v)
    }
    all.sort((a, b) => a - b)
    const lo = Math.round(percentile(all, 0.02) * 10) / 10
    const hi = Math.round(percentile(all, 0.98) * 10) / 10
    metaMeasures.push({
      id: m.id,
      label: m.label,
      short: m.short,
      unit: m.unit,
      description: m.description,
      colorDomain: [lo, hi],
      elevationDomain: m.range,
      dataMin: all.length ? Math.round(all[0] * 10) / 10 : 0,
      dataMax: all.length ? Math.round(all[all.length - 1] * 10) / 10 : 0,
    })
  }

  const meta = {
    title: 'DailyDil — U.S. Heart & Circulatory Wellness Atlas',
    source,
    sourceUrl: 'https://www.cdc.gov/places/',
    isPlaceholder,
    adjustment: DATA_VALUE_TYPE,
    generated: new Date().toISOString().slice(0, 10),
    years,
    measures: metaMeasures,
    countyCount,
    notes: notes ?? [],
  }
  fs.writeFileSync(path.join(DATA_DIR, 'meta.json'), JSON.stringify(meta, null, 2))
  return meta
}

/** Build the fuzzy-search index from county/state centroids + every US ZIP. */
export function writePlaces(geo) {
  ensureDir(DATA_DIR)
  const counties = geo.counties.map((c) => ({
    id: c.fips,
    name: c.name,
    st: c.st,
    label: `${c.name}, ${c.st}`,
    lon: c.centroid[0],
    lat: c.centroid[1],
  }))
  const states = geo.states.map((s) => ({
    id: s.stfips,
    name: s.name,
    st: s.st,
    label: s.name,
    lon: s.centroid[0],
    lat: s.centroid[1],
  }))

  // ZIP centroids from us-zips: stored compactly as [zip, lon, lat].
  let zips = []
  try {
    const usZips = require('us-zips')
    const table = usZips.default ?? usZips
    zips = Object.entries(table)
      .map(([zip, c]) => [zip, round3(c.longitude), round3(c.latitude)])
      .filter(([, lon, lat]) => Number.isFinite(lon) && Number.isFinite(lat))
      .sort((a, b) => a[0].localeCompare(b[0]))
  } catch (e) {
    console.warn('  ! us-zips unavailable, ZIP search disabled:', e.message)
  }

  fs.writeFileSync(path.join(DATA_DIR, 'places.json'), JSON.stringify({ counties, states, zips }))
  return { counties: counties.length, states: states.length, zips: zips.length }
}

/** Copy TopoJSON geometry into public/geo for the client to fetch + decode. */
export function copyGeometry() {
  ensureDir(GEO_DIR)
  for (const name of ['counties-10m.json', 'states-10m.json']) {
    const src = require.resolve(`us-atlas/${name}`)
    fs.copyFileSync(src, path.join(GEO_DIR, name))
  }
}

export { YEARS }

function round3(v) {
  return Math.round(v * 1000) / 1000
}
