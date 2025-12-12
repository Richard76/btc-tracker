'use client';

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from 'recharts';

interface ChartData {
  time: string;
  price: number;
}

interface PriceChartProps {
  data: ChartData[];
  mean?: number;
  currency: string;
}

export default function PriceChart({ data, mean, currency }: PriceChartProps) {
  return (
    <div className="h-64 md:h-80">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data}>
          <XAxis
            dataKey="time"
            stroke="#64748b"
            tick={{ fontSize: 11 }}
            tickLine={false}
            axisLine={false}
          />
          <YAxis
            stroke="#64748b"
            tick={{ fontSize: 11 }}
            tickLine={false}
            axisLine={false}
            domain={['auto', 'auto']}
            tickFormatter={(v) =>
              currency === 'BTC' ? v.toFixed(6) : v.toLocaleString()
            }
          />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1e293b',
              border: '1px solid #334155',
              borderRadius: '8px',
            }}
            labelStyle={{ color: '#94a3b8' }}
            formatter={(value: number) => [
              currency === 'BTC'
                ? value.toFixed(8)
                : `$${value.toLocaleString()}`,
              'Price',
            ]}
          />
          {mean && (
            <ReferenceLine
              y={mean}
              stroke="#f59e0b"
              strokeDasharray="3 3"
            />
          )}
          <Line
            type="monotone"
            dataKey="price"
            stroke="#3b82f6"
            strokeWidth={2}
            dot={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
