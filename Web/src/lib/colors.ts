import { interpolateRgbBasis } from 'd3-interpolate'
import { color as d3color } from 'd3-color'

// Pink → red ramp: pale pink (low) through hot pink and rose to deep maroon
// (high). "Shades of red to pink", with deeper/redder = higher burden.
const STOPS = ['#ffe1ec', '#ffa9c9', '#ff6f91', '#f43f5e', '#be123c', '#7f1d1d']
const ramp = interpolateRgbBasis(STOPS)

export function rampCss(t: number): string {
  return ramp(t)
}

/** CSS gradient string for the legend bar. */
export function legendGradient(): string {
  const stops = STOPS.map((c, i) => `${c} ${Math.round((i / (STOPS.length - 1)) * 100)}%`)
  return `linear-gradient(90deg, ${stops.join(', ')})`
}

function normalize(value: number, domain: [number, number]): number {
  const [lo, hi] = domain
  if (hi <= lo) return 0.5
  return Math.max(0, Math.min(1, (value - lo) / (hi - lo)))
}

/** Fill color for a metric value as an [r,g,b] (or [r,g,b,a]) tuple for deck.gl. */
export function fillColor(
  value: number | undefined,
  domain: [number, number],
  alpha = 255,
): [number, number, number, number] {
  if (value == null || Number.isNaN(value)) return [42, 47, 66, 90] // "no data" slate
  const c = d3color(ramp(normalize(value, domain)))?.rgb()
  if (!c) return [120, 120, 120, alpha]
  return [Math.round(c.r), Math.round(c.g), Math.round(c.b), alpha]
}

/** A swatch color (CSS) for a metric value — used by tooltip & legend ticks. */
export function swatchCss(value: number | undefined, domain: [number, number]): string {
  if (value == null || Number.isNaN(value)) return '#2a2f42'
  return ramp(normalize(value, domain))
}
