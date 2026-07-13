// Shared definitions used by BOTH the placeholder generator and the real CDC
// scraper, so the two pipelines emit byte-compatible output that the frontend
// consumes without any code changes.

// ---------------------------------------------------------------------------
// Measures (CDC PLACES "Health Outcomes" category, age-adjusted prevalence).
// `id` matches the CDC PLACES `measureid`, so the scraper filters on these.
// ---------------------------------------------------------------------------
// Labels are wellness-framed for consumer app-store distribution: they describe
// community-level heart & circulatory *wellness awareness* for geographic areas,
// never individual diagnoses. `id` still matches the CDC PLACES `measureid`, so
// the real-data scraper is unchanged and the underlying source is disclosed.
export const MEASURES = [
  {
    id: 'BPHIGH',
    label: 'Circulatory Strain',
    short: 'Circulatory',
    unit: '% of adults',
    // observed full range across the dataset (used for 3D elevation scaling)
    range: [18, 55],
    // realistic generation band for the placeholder
    gen: { lo: 24, hi: 49, trend: 0.15, noise: 0.5 },
    description:
      'Community-level heart & circulatory wellness-awareness indicator for adults aged ≥18, from CDC PLACES public-health estimates (age-adjusted). Describes geographic areas, never individuals.',
  },
  {
    id: 'CHD',
    label: 'Heart Health',
    short: 'Heart',
    unit: '% of adults',
    range: [2, 15],
    gen: { lo: 3.2, hi: 11.5, trend: -0.08, noise: 0.25 },
    description:
      'Community-level heart-health awareness indicator for adults aged ≥18, from CDC PLACES public-health estimates (age-adjusted). Describes geographic areas, never individuals.',
  },
  {
    id: 'STROKE',
    label: 'Brain Circulation',
    short: 'Brain',
    unit: '% of adults',
    range: [1, 9],
    gen: { lo: 1.6, hi: 6.8, trend: -0.03, noise: 0.2 },
    description:
      'Community-level brain-circulation wellness-awareness indicator for adults aged ≥18, from CDC PLACES public-health estimates (age-adjusted). Describes geographic areas, never individuals.',
  },
]

export const MEASURE_IDS = MEASURES.map((m) => m.id)
export const DATA_VALUE_TYPE = 'Age-adjusted prevalence'

// Data years modeled by the placeholder. The frontend reads the year list from
// meta.json, so when the real scraper runs it can emit a different set and the
// UI simply adapts.
export const YEARS = [2016, 2017, 2018, 2019, 2020, 2021, 2022]
export const MID_YEAR = 2019

// ---------------------------------------------------------------------------
// 50 states + DC (CDC PLACES coverage). FIPS -> USPS abbreviation.
// ---------------------------------------------------------------------------
export const STATE_ABBR = {
  '01': 'AL', '02': 'AK', '04': 'AZ', '05': 'AR', '06': 'CA', '08': 'CO',
  '09': 'CT', '10': 'DE', '11': 'DC', '12': 'FL', '13': 'GA', '15': 'HI',
  '16': 'ID', '17': 'IL', '18': 'IN', '19': 'IA', '20': 'KS', '21': 'KY',
  '22': 'LA', '23': 'ME', '24': 'MD', '25': 'MA', '26': 'MI', '27': 'MN',
  '28': 'MS', '29': 'MO', '30': 'MT', '31': 'NE', '32': 'NV', '33': 'NH',
  '34': 'NJ', '35': 'NM', '36': 'NY', '37': 'NC', '38': 'ND', '39': 'OH',
  '40': 'OK', '41': 'OR', '42': 'PA', '44': 'RI', '45': 'SC', '46': 'SD',
  '47': 'TN', '48': 'TX', '49': 'UT', '50': 'VT', '51': 'VA', '53': 'WA',
  '54': 'WV', '55': 'WI', '56': 'WY',
}

export const INCLUDED_STATE_FIPS = new Set(Object.keys(STATE_ABBR))

// Regional cardiovascular-burden index in [0,1] used only to give the
// placeholder a realistic geography (the "Stroke Belt" across the Southeast and
// Appalachia runs high; the Mountain West and Upper Midwest run low). Replaced
// entirely by real values when the scraper runs.
export const STATE_BURDEN = {
  AL: 0.88, AK: 0.60, AZ: 0.50, AR: 0.84, CA: 0.34, CO: 0.20,
  CT: 0.38, DE: 0.60, DC: 0.50, FL: 0.56, GA: 0.78, HI: 0.30,
  ID: 0.48, IL: 0.56, IN: 0.72, IA: 0.52, KS: 0.64, KY: 0.86,
  LA: 0.86, ME: 0.50, MD: 0.54, MA: 0.34, MI: 0.66, MN: 0.30,
  MS: 0.92, MO: 0.70, MT: 0.44, NE: 0.50, NV: 0.56, NH: 0.44,
  NJ: 0.42, NM: 0.58, NY: 0.42, NC: 0.76, ND: 0.50, OH: 0.72,
  OK: 0.82, OR: 0.42, PA: 0.60, RI: 0.50, SC: 0.80, SD: 0.50,
  TN: 0.84, TX: 0.66, UT: 0.22, VT: 0.36, VA: 0.58, WA: 0.40,
  WV: 0.90, WI: 0.50, WY: 0.52,
}

// ---------------------------------------------------------------------------
// Deterministic helpers (so generated data is reproducible commit-to-commit).
// ---------------------------------------------------------------------------
export function hashString(str) {
  let h = 2166136261 >>> 0
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

export function mulberry32(seed) {
  let a = seed >>> 0
  return function () {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// A stable [-1,1] value for a given key.
export function signedNoise(key) {
  return mulberry32(hashString(key))() * 2 - 1
}

export function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v))
}

export function round1(v) {
  return Math.round(v * 10) / 10
}
