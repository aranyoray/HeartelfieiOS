// 50 states + DC (CDC PLACES coverage). Mirrors scripts/lib/schema.mjs but kept
// client-side so geometry can be filtered without shipping the build scripts.
export const STATE_ABBR: Record<string, string> = {
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

// Distinct, non-red palette for the 2–3 comparison selections (kept clear of
// the pink→red choropleth).
export const COMPARE_COLORS = ['#38bdf8', '#fbbf24', '#a78bfa']
export const COMPARE_RGB: [number, number, number][] = [
  [56, 189, 248],
  [251, 191, 36],
  [167, 139, 250],
]
export const MAX_COMPARE = 3

// Continental-US framing. A non-zero pitch gives the flat choropleth a tilted,
// perspective "3D" look without extruding the polygons.
export const INITIAL_VIEW = {
  longitude: -96,
  latitude: 38.6,
  zoom: 3.4,
  pitch: 45,
  bearing: 0,
}
