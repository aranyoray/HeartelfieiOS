// Loads US county/state geometry from the `us-atlas` package (derived from the
// US Census cartographic boundary files), filters to the 50 states + DC that
// CDC PLACES covers, and computes centroids for the search index.
import { createRequire } from 'node:module'
import { feature } from 'topojson-client'
import { geoCentroid } from 'd3-geo'
import { STATE_ABBR, INCLUDED_STATE_FIPS } from './schema.mjs'

const require = createRequire(import.meta.url)

export function loadGeo() {
  const countiesTopo = require('us-atlas/counties-10m.json')
  const statesTopo = require('us-atlas/states-10m.json')

  const allCounties = feature(countiesTopo, countiesTopo.objects.counties).features
  const allStates = feature(statesTopo, statesTopo.objects.states).features

  const counties = []
  for (const f of allCounties) {
    const fips = String(f.id).padStart(5, '0')
    const stfips = fips.slice(0, 2)
    if (!INCLUDED_STATE_FIPS.has(stfips)) continue
    const centroid = geoCentroid(f)
    counties.push({
      fips,
      name: f.properties?.name ?? fips,
      stfips,
      st: STATE_ABBR[stfips],
      centroid: [round3(centroid[0]), round3(centroid[1])],
    })
  }

  const states = []
  for (const f of allStates) {
    const stfips = String(f.id).padStart(2, '0')
    if (!INCLUDED_STATE_FIPS.has(stfips)) continue
    const centroid = geoCentroid(f)
    states.push({
      stfips,
      name: f.properties?.name ?? stfips,
      st: STATE_ABBR[stfips],
      centroid: [round3(centroid[0]), round3(centroid[1])],
    })
  }

  counties.sort((a, b) => a.fips.localeCompare(b.fips))
  states.sort((a, b) => a.stfips.localeCompare(b.stfips))

  return { countiesTopo, statesTopo, counties, states }
}

function round3(v) {
  return Math.round(v * 1000) / 1000
}
