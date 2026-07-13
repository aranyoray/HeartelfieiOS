import { useEffect, useMemo, useState } from 'react'
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts'
import type { Meta } from '../lib/types'
import { useMeasureData } from '../lib/hooks'
import { useStore } from '../store'
import { COMPARE_COLORS } from '../lib/constants'

export default function ComparisonPanel({ meta }: { meta: Meta }) {
  const selections = useStore((s) => s.selections)
  const removeSelection = useStore((s) => s.removeSelection)
  const clearSelections = useStore((s) => s.clearSelections)
  const mode = useStore((s) => s.mode)
  const measureId = useStore((s) => s.measureId)
  const data = useMeasureData(measureId)
  const [expanded, setExpanded] = useState(false)

  const measure = meta.measures.find((m) => m.id === measureId) ?? meta.measures[0]

  useEffect(() => {
    if (selections.length > 0) setExpanded(true)
  }, [selections.length])

  const chartData = useMemo(() => {
    if (!data) return []
    const table = mode === 'county' ? data.county : data.state
    return meta.years.map((y) => {
      const row: Record<string, number | string> = { year: y }
      for (const sel of selections) {
        const v = table[String(y)]?.[sel.id]
        if (v != null) row[sel.id] = v
      }
      return row
    })
  }, [data, mode, selections, meta.years])

  const hasSel = selections.length > 0

  return (
    <div className={`compare glass ${expanded ? 'open' : ''}`}>
      <div className="compare-head" onClick={() => setExpanded((e) => !e)}>
        <span className="compare-caret">{expanded ? '▾' : '▴'}</span>
        <strong>Compare trends</strong>
        <span className="compare-sub">
          {hasSel
            ? `${selections.length} ${mode}${selections.length > 1 ? 's' : ''} · ${measure.short}`
            : `click up to 3 ${mode === 'county' ? 'counties' : 'states'} on the map`}
        </span>
        {hasSel && (
          <button
            className="compare-clear"
            onClick={(e) => {
              e.stopPropagation()
              clearSelections()
            }}
          >
            Clear
          </button>
        )}
      </div>

      {expanded && (
        <div className="compare-body">
          {!hasSel ? (
            <div className="compare-empty">
              Select areas by clicking the map or using search, then watch their{' '}
              {measure.label.toLowerCase()} trend from {meta.years[0]} to{' '}
              {meta.years[meta.years.length - 1]}.
            </div>
          ) : (
            <>
              <div className="compare-chips">
                {selections.map((sel, i) => (
                  <span className="chip" key={sel.id} style={{ borderColor: COMPARE_COLORS[i] }}>
                    <span className="chip-dot" style={{ background: COMPARE_COLORS[i] }} />
                    {sel.label}
                    <button onClick={() => removeSelection(sel.id)} aria-label={`Remove ${sel.label}`}>
                      ✕
                    </button>
                  </span>
                ))}
              </div>
              <div className="compare-chart">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={chartData} margin={{ top: 8, right: 16, bottom: 4, left: -8 }}>
                    <CartesianGrid stroke="#222838" strokeDasharray="3 3" />
                    <XAxis dataKey="year" stroke="#2a3142" tick={{ fill: '#9aa3b8', fontSize: 11 }} />
                    <YAxis
                      tick={{ fill: '#9aa3b8', fontSize: 11 }}
                      width={42}
                      domain={['auto', 'auto']}
                      unit={measure.unit.includes('%') ? '%' : ''}
                    />
                    <Tooltip
                      contentStyle={{
                        background: '#11151f',
                        border: '1px solid #2a3142',
                        borderRadius: 8,
                        fontSize: 12,
                      }}
                      labelStyle={{ color: '#cbd3e6' }}
                      formatter={(v: number, name: string) => {
                        const sel = selections.find((s) => s.id === name)
                        return [`${v}${measure.unit.includes('%') ? '%' : ''}`, sel?.label ?? name]
                      }}
                    />
                    {selections.map((sel, i) => (
                      <Line
                        key={sel.id}
                        type="monotone"
                        dataKey={sel.id}
                        stroke={COMPARE_COLORS[i]}
                        strokeWidth={2.5}
                        dot={{ r: 2.5 }}
                        activeDot={{ r: 4 }}
                        connectNulls
                        isAnimationActive={false}
                      />
                    ))}
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}
