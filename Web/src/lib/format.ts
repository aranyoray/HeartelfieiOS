export function formatValue(value: number | undefined, unit: string): string {
  if (value == null || Number.isNaN(value)) return 'No data'
  if (unit.includes('%')) return `${value.toFixed(1)}%`
  return value.toLocaleString()
}

export function pctUnit(unit: string): string {
  return unit.includes('%') ? '%' : ''
}

/** Signed delta string between two values, e.g. "+1.4 pts". */
export function deltaLabel(a: number | undefined, b: number | undefined): string | null {
  if (a == null || b == null) return null
  const d = a - b
  const sign = d > 0 ? '+' : ''
  return `${sign}${d.toFixed(1)} pts`
}
