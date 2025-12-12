'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import dynamic from 'next/dynamic';

// Lazy load Recharts (~200KB) - only loads when chart is needed
const LazyChart = dynamic(
  () => import('../components/PriceChart'),
  {
    ssr: false,
    loading: () => (
      <div className="h-64 md:h-80 bg-slate-700/30 rounded-lg animate-pulse flex items-center justify-center">
        <span className="text-slate-500">Loading chart...</span>
      </div>
    )
  }
);

// Direct Supabase connection (no R API middleware needed)
const SUPABASE_URL = 'https://kzltorgncwddsjiqbooh.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6bHRvcmduY3dkZHNqaXFib29oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2MzMyMDQsImV4cCI6MjA4MDIwOTIwNH0.RQGSeITtZXyZI-npBLyj0rZXWXjQ8mdqkrSO6VovBQE';

const COINS = ['BTC', 'ETH', 'SOL', 'LINK', 'AVAX', 'POL', 'NEAR'];
const RANGES = ['1h', '24h', '7d', '30d', '90d'];
const CURRENCIES = ['USD', 'BTC'];
const TABS = ['Tracker', 'Portfolio', 'Assets'] as const;
type TabType = typeof TABS[number];

// Asset information for the Assets tab - based on unique "niches"
const ASSET_INFO: Record<string, {
  name: string;
  niche: string;
  category: 'humans' | 'agents';
  description: string;
  valueProposition: string;
  useCases: string[];
}> = {
  BTC: {
    name: 'Bitcoin',
    niche: 'Savings Technology',
    category: 'humans',
    description: 'The original cryptocurrency - digital gold with a hard cap of 21 million coins. It\'s the only asset in history with mathematically guaranteed scarcity. No government, company, or person can print more.',
    valueProposition: 'Bitcoin is pristine collateral - the hardest money ever created. With BlackRock, Fidelity, and sovereign nations now holding BTC, it\'s transitioning from "internet money" to global reserve asset. The 21 million cap means your percentage of the total supply can never be diluted.',
    useCases: [
      'Corporate treasury reserve (MicroStrategy, Tesla model)',
      'Emerging market remittances (send money home without 10% Western Union fees)',
      'Lightning Network retail payments (instant, near-zero fees)',
    ],
  },
  ETH: {
    name: 'Ethereum',
    niche: 'Settlement Layer',
    category: 'agents',
    description: 'The world\'s programmable blockchain - a global computer that runs "smart contracts" (self-executing code). Think of it as the operating system for decentralized finance and AI agents.',
    valueProposition: 'Ethereum settles $4+ trillion in transactions annually. After switching to Proof of Stake, it became deflationary - more ETH is burned than created. As AI agents need to transact autonomously, ETH becomes "money for machines."',
    useCases: [
      'DeFi loans & yield (Aave, Compound - earn interest without banks)',
      'NFT royalties for creators (automatic payments on every resale)',
      'DAO governance (vote on protocol decisions with your tokens)',
    ],
  },
  SOL: {
    name: 'Solana',
    niche: 'Fast Rails for Retail',
    category: 'humans',
    description: 'The speed chain - 65,000+ transactions per second with sub-cent fees. Built for high-frequency applications that need instant finality. Popular for gaming, payments, and NFTs.',
    valueProposition: 'Solana is positioned as the "Visa of crypto" - fast enough for everyday payments. The ecosystem grew 10x in 2024 despite past network issues. If crypto becomes mainstream for daily transactions, Solana\'s speed advantage is decisive.',
    useCases: [
      'High-frequency DEX trading (Jupiter handles $2B+ daily volume)',
      'Web3 gaming (instant in-game item transfers)',
      'Compressed NFTs (mint millions for pennies)',
    ],
  },
  LINK: {
    name: 'Chainlink',
    niche: 'Oracle & Data Layer',
    category: 'agents',
    description: 'The bridge between blockchains and the real world. Smart contracts can\'t access external data (prices, weather, sports scores) on their own - Chainlink provides this critical connection securely.',
    valueProposition: 'Chainlink secures $75B+ in smart contracts. Swift (global banking network) and DTCC (clears $2 quadrillion yearly) are integrating Chainlink for cross-border payments. As traditional finance moves on-chain, reliable data feeds become essential infrastructure.',
    useCases: [
      'DeFi price feeds (every major protocol uses Chainlink oracles)',
      'Cross-chain bridges (CCIP enables secure multi-chain transfers)',
      'Enterprise data APIs (banks get real-time market data on-chain)',
    ],
  },
  AVAX: {
    name: 'Avalanche',
    niche: 'Enterprise Subnets',
    category: 'agents',
    description: 'The enterprise blockchain - lets institutions create custom, permissioned blockchains ("subnets") that connect to the public network. Sub-second finality makes it suitable for trading.',
    valueProposition: 'Avalanche is where traditional finance experiments with blockchain. JPMorgan, Citi, and major banks have run pilots on Avalanche subnets. The ability to create compliant, private chains while connecting to public liquidity is unique.',
    useCases: [
      'Bank-grade payment subnets (Evergreen subnet for institutions)',
      'Tokenized real estate (fractional ownership with instant settlement)',
      'Gaming chains (custom rules, dedicated throughput)',
    ],
  },
  POL: {
    name: 'Polygon',
    niche: 'Ethereum Scaling',
    category: 'humans',
    description: 'Ethereum\'s express lane - same security, 100x cheaper. Uses "zero-knowledge" math to batch thousands of transactions into one Ethereum transaction, dramatically reducing costs.',
    valueProposition: 'Polygon processes millions of transactions for Starbucks, Nike, Disney, and Reddit. Its zkEVM technology is the leading solution for Ethereum scaling. As Ethereum gas fees remain high, Layer 2s capture more activity.',
    useCases: [
      'Low-cost DeFi (same apps as Ethereum, 100x cheaper)',
      'Enterprise NFTs (Starbucks Odyssey, Reddit Collectibles)',
      'Gas-free onboarding (brands sponsor user transactions)',
    ],
  },
  NEAR: {
    name: 'NEAR Protocol',
    niche: 'UX-First Chain',
    category: 'agents',
    description: 'The user-friendly blockchain - human-readable addresses (alice.near instead of 0x7a3b...), account abstraction built-in, and the ability to interact with multiple chains from one account.',
    valueProposition: 'NEAR solves crypto\'s biggest problem: complexity. Its "chain abstraction" lets users interact with any blockchain without knowing which one they\'re on. NEAR is also leading AI-blockchain integration with autonomous agent wallets.',
    useCases: [
      'Human-readable accounts (send to alice.near, not 0x7a3b...)',
      'Chain abstraction (one account works across all blockchains)',
      'AI agent wallets (autonomous agents manage their own funds)',
    ],
  },
};

// Portfolio allocation approaches
const ALLOCATION_APPROACHES = {
  mpt: {
    name: 'Modern Portfolio Theory',
    description: 'Classic Markowitz optimization - maximize risk-adjusted returns based on historical volatility and correlations.',
    weights: { BTC: 40, ETH: 25, SOL: 15, LINK: 8, AVAX: 5, POL: 4, NEAR: 3 },
    expectedReturn: 45.2,
    volatility: 28.5,
    sharpeRatio: 1.35,
  },
  kelly: {
    name: 'Kelly Conviction Sizing',
    description: 'Position sizes based on "edge" - how unique and irreplaceable each asset\'s niche is in the crypto ecosystem.',
    weights: { BTC: 32, ETH: 24, SOL: 14, LINK: 14, AVAX: 7, POL: 5, NEAR: 4 },
    edgeScores: {
      BTC: { edge: 0.4, description: 'Only truly scarce digital asset' },
      ETH: { edge: 0.3, description: 'Dominant smart contract platform' },
      SOL: { edge: 0.18, description: 'Speed leader, but competitors exist' },
      LINK: { edge: 0.18, description: 'Oracle monopoly, but replaceable' },
      AVAX: { edge: 0.09, description: 'Enterprise focus, growing competition' },
      POL: { edge: 0.06, description: 'L2 leader, but many alternatives' },
      NEAR: { edge: 0.05, description: 'UX innovation, early stage' },
    },
  },
  scenario: {
    name: 'Scenario Analysis',
    description: 'Weight allocations differently based on macro conditions - normal growth vs debt crisis.',
    scenarios: {
      normal: {
        name: 'Normal Conditions',
        probability: 70,
        description: 'Steady adoption, no major crises. Tech innovation drives growth.',
        weights: { BTC: 30, ETH: 28, SOL: 16, LINK: 12, AVAX: 6, POL: 5, NEAR: 3 },
        rationale: 'Higher allocation to innovation (ETH, SOL) in stable environment.',
      },
      crisis: {
        name: 'US Debt/Banking Crisis',
        probability: 30,
        description: 'Dollar weakness, bank failures, flight to hard assets.',
        weights: { BTC: 50, ETH: 20, SOL: 10, LINK: 10, AVAX: 4, POL: 4, NEAR: 2 },
        rationale: 'BTC dominates as "digital gold" safe haven. Utility tokens underperform.',
      },
    },
    blendedWeights: { BTC: 36, ETH: 26, SOL: 14, LINK: 11, AVAX: 5, POL: 5, NEAR: 3 },
  },
};

type AllocationApproach = 'mpt' | 'kelly' | 'scenario';

// 10-year projection calculator (with 80% confidence interval)
const calculateProjection = (startAmount: number, annualReturn: number, volatility: number, years: number) => {
  // Expected value: compound growth
  const expectedValue = startAmount * Math.pow(1 + annualReturn / 100, years);

  // For 80% confidence interval (10th to 90th percentile)
  // Using log-normal distribution approximation
  const annualVol = volatility / 100;
  const totalVol = annualVol * Math.sqrt(years);
  const z80 = 1.28; // Z-score for 80% CI (10th-90th percentile)

  // Log-normal confidence bounds
  const logMean = Math.log(expectedValue) - (totalVol * totalVol) / 2;
  const low = Math.exp(logMean - z80 * totalVol);
  const high = Math.exp(logMean + z80 * totalVol);

  return { expected: expectedValue, low, high };
};

interface StatsData {
  symbol: string;
  range: string;
  currency: string;
  data_points: number;
  current: number;
  start_price: number;
  period_change_pct: number;
  high: number;
  low: number;
  mean: number;
  percentile: number;
  lower_half_mean: number;
  history: { timestamp: string; price: number }[];
  timestamp: string;
}

interface BtcPrice {
  current: number;
}

export default function Home() {
  const [activeTab, setActiveTab] = useState<TabType>('Tracker');
  const [coin, setCoin] = useState('BTC');
  const [range, setRange] = useState('7d');
  const [currency, setCurrency] = useState('USD');
  const [data, setData] = useState<StatsData | null>(null);
  const [btcPrice, setBtcPrice] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [allocationApproach, setAllocationApproach] = useState<AllocationApproach>('mpt');
  const [investmentAmount] = useState(100000); // $100k default

  // Calculate countdown based on real time - synced across all viewers
  // Refreshes at the top of every minute (:00)
  const getSecondsUntilNextMinute = () => 60 - new Date().getSeconds();
  const [countdown, setCountdown] = useState(getSecondsUntilNextMinute);

  // Helper to get time range in ISO format
  const getTimeRange = (rangeStr: string): string => {
    const now = new Date();
    let ms = 0;
    switch (rangeStr) {
      case '1h': ms = 60 * 60 * 1000; break;
      case '24h': ms = 24 * 60 * 60 * 1000; break;
      case '7d': ms = 7 * 24 * 60 * 60 * 1000; break;
      case '30d': ms = 30 * 24 * 60 * 60 * 1000; break;
      case '90d': ms = 90 * 24 * 60 * 60 * 1000; break;
      default: ms = 7 * 24 * 60 * 60 * 1000;
    }
    return new Date(now.getTime() - ms).toISOString();
  };

  // Calculate statistics from price data
  const calculateStats = (prices: number[]): { high: number; low: number; mean: number; percentile: number; lower_half_mean: number } => {
    if (prices.length === 0) return { high: 0, low: 0, mean: 0, percentile: 0, lower_half_mean: 0 };
    const sorted = [...prices].sort((a, b) => a - b);
    const high = Math.max(...prices);
    const low = Math.min(...prices);
    const mean = prices.reduce((a, b) => a + b, 0) / prices.length;
    const current = prices[prices.length - 1];
    const percentile = Math.round((sorted.filter(p => p <= current).length / sorted.length) * 100);
    const lowerHalf = sorted.slice(0, Math.floor(sorted.length / 2));
    const lower_half_mean = lowerHalf.length > 0 ? lowerHalf.reduce((a, b) => a + b, 0) / lowerHalf.length : mean;
    return { high, low, mean, percentile, lower_half_mean };
  };

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const startTime = getTimeRange(range);

      // Fetch from Supabase directly
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/crypto_prices?symbol=eq.${coin}&timestamp=gte.${startTime}&order=timestamp.desc&limit=1000`,
        {
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`,
          }
        }
      );
      const rows = await res.json();

      if (!Array.isArray(rows) || rows.length === 0) {
        console.log('No data returned from Supabase');
        setLoading(false);
        return;
      }

      // Extract prices and calculate stats
      const prices = rows.map((r: { price_usd: number }) => r.price_usd);
      const stats = calculateStats(prices);
      const current = prices[0]; // Most recent (desc order)
      const startPrice = prices[prices.length - 1]; // Oldest in range
      const period_change_pct = startPrice > 0 ? ((current - startPrice) / startPrice) * 100 : 0;

      // Convert to BTC if needed
      let displayPrices = prices;
      if (currency === 'BTC' && coin !== 'BTC') {
        // Fetch BTC price to convert
        const btcRes = await fetch(
          `${SUPABASE_URL}/rest/v1/crypto_prices?symbol=eq.BTC&order=timestamp.desc&limit=1`,
          {
            headers: {
              'apikey': SUPABASE_KEY,
              'Authorization': `Bearer ${SUPABASE_KEY}`,
            }
          }
        );
        const btcRows = await btcRes.json();
        if (btcRows.length > 0) {
          const btcPrice = btcRows[0].price_usd;
          displayPrices = prices.map((p: number) => p / btcPrice);
        }
      }

      const displayStats = currency === 'BTC' && coin !== 'BTC' ? calculateStats(displayPrices) : stats;

      const normalized: StatsData = {
        symbol: coin,
        range: range,
        currency: currency,
        data_points: rows.length,
        current: currency === 'BTC' && coin !== 'BTC' ? displayPrices[0] : current,
        start_price: currency === 'BTC' && coin !== 'BTC' ? displayPrices[displayPrices.length - 1] : startPrice,
        period_change_pct: period_change_pct,
        high: displayStats.high,
        low: displayStats.low,
        mean: displayStats.mean,
        percentile: displayStats.percentile,
        lower_half_mean: displayStats.lower_half_mean,
        history: rows.slice(0, 200).map((r: { timestamp: string; price_usd: number }) => ({
          timestamp: r.timestamp,
          price: currency === 'BTC' && coin !== 'BTC' && displayPrices.length > 0
            ? r.price_usd / (prices[0] / displayPrices[0])
            : r.price_usd
        })),
        timestamp: rows[0]?.timestamp || new Date().toISOString(),
      };
      setData(normalized);

      // Also fetch BTC price for inverse calculation
      if (coin !== 'BTC' && currency === 'USD') {
        const btcRes = await fetch(
          `${SUPABASE_URL}/rest/v1/crypto_prices?symbol=eq.BTC&order=timestamp.desc&limit=1`,
          {
            headers: {
              'apikey': SUPABASE_KEY,
              'Authorization': `Bearer ${SUPABASE_KEY}`,
            }
          }
        );
        const btcRows = await btcRes.json();
        if (btcRows.length > 0) {
          setBtcPrice(btcRows[0].price_usd);
        }
      }
    } catch (err) {
      console.error('Fetch error:', err);
    }
    setLoading(false);
  }, [coin, range, currency]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Sync countdown with real clock time - all viewers see same countdown
  useEffect(() => {
    let lastFetchMinute = -1;

    const timer = setInterval(() => {
      const now = new Date();
      const currentMinute = now.getMinutes();
      const secondsLeft = 60 - now.getSeconds();
      setCountdown(secondsLeft);

      // Fetch at top of each minute (only once per minute)
      if (now.getSeconds() === 0 && currentMinute !== lastFetchMinute) {
        lastFetchMinute = currentMinute;
        fetchData();
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [fetchData]);

  const formatPrice = (val: number | null | undefined) => {
    if (val == null || isNaN(val)) return '--';
    if (currency === 'BTC') {
      return val.toFixed(8);
    }
    if (val >= 1000) return val.toLocaleString('en-US', { maximumFractionDigits: 2 });
    if (val >= 1) return val.toFixed(2);
    return val.toFixed(6);
  };

  const formatChange = (val: number | null | undefined) => {
    if (val == null || isNaN(val)) return '--';
    const sign = val >= 0 ? '+' : '';
    return `${sign}${val.toFixed(2)}%`;
  };

  // Memoize chart data to prevent unnecessary recalculations
  // Include range in dependencies to force recalculation on timeframe change
  const chartData = useMemo(() =>
    data?.history
      ?.slice()
      .reverse()
      .map((h) => ({
        time: new Date(h.timestamp).toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
        }),
        price: h.price,
      })) || [],
    [data?.history, range]
  );

  const priceColor =
    data?.current && data?.mean
      ? data.current >= data.mean
        ? '#10b981'
        : '#ef4444'
      : '#f1f5f9';

  const changeColor =
    data?.period_change_pct != null
      ? data.period_change_pct >= 0
        ? '#10b981'
        : '#ef4444'
      : '#f1f5f9';

  // Calculate how many of this coin needed to buy 1 BTC
  const coinsPerBtc =
    coin !== 'BTC' && currency === 'USD' && data?.current && btcPrice
      ? (btcPrice / data.current).toFixed(1)
      : null;

  return (
    <main className="min-h-screen bg-slate-900 text-slate-100 p-4 md:p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4">
          <h1 className="text-2xl md:text-3xl font-bold text-white mb-4 sm:mb-0">
            Crypto Tracker
          </h1>
          <div className="flex items-center gap-2 text-sm text-slate-400">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
            Refresh in {countdown}s
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex gap-2 mb-6 border-b border-slate-700 pb-3">
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`py-2 px-4 rounded-t-lg font-medium text-sm transition-all ${
                activeTab === tab
                  ? 'bg-blue-600 text-white'
                  : 'bg-slate-800/50 text-slate-400 hover:bg-slate-700'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        {activeTab === 'Tracker' && (
          <>
            {/* Coin Selector */}
            <div className="grid grid-cols-4 sm:grid-cols-7 gap-2 mb-4">
              {COINS.map((c) => (
                <button
                  key={c}
                  onClick={() => setCoin(c)}
                  className={`py-2 px-3 rounded-lg font-semibold text-sm transition-all ${
                    coin === c
                      ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/30'
                      : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                  }`}
                >
                  {c}
                </button>
              ))}
            </div>

            {/* Range & Currency Selectors */}
            <div className="flex flex-col sm:flex-row gap-4 mb-6">
              <div className="flex gap-2">
                {RANGES.map((r) => (
                  <button
                    key={r}
                    onClick={() => setRange(r)}
                    className={`py-2 px-4 rounded-lg font-medium text-sm transition-all ${
                      range === r
                        ? 'bg-slate-700 text-white'
                        : 'bg-slate-800/50 text-slate-400 hover:bg-slate-800'
                    }`}
                  >
                    {r}
                  </button>
                ))}
              </div>
              <div className="flex gap-2">
                {CURRENCIES.map((c) => (
                  <button
                    key={c}
                    onClick={() => setCurrency(c)}
                    className={`py-2 px-4 rounded-lg font-medium text-sm transition-all ${
                      currency === c
                        ? 'bg-slate-700 text-white'
                        : 'bg-slate-800/50 text-slate-400 hover:bg-slate-800'
                    }`}
                  >
                    {c}
                  </button>
                ))}
              </div>
            </div>

            {/* Warning Banner */}
            {data?.current &&
              data?.lower_half_mean &&
              data.current < data.lower_half_mean && (
                <div className="bg-red-900/50 border border-red-500/50 text-red-200 px-4 py-3 rounded-lg mb-4 text-sm">
                  Price is in the lower half of the {range} range - potential
                  buying opportunity
                </div>
              )}

            {/* Current Price */}
            <div className="bg-slate-800/50 rounded-xl p-6 mb-6">
              <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
                <div>
                  <div className="text-slate-400 text-sm mb-1">
                    {coin}/{currency} Current
                  </div>
                  <div
                    className="text-4xl md:text-5xl font-bold"
                    style={{ color: priceColor }}
                  >
                    {loading ? (
                      <span className="animate-pulse">Loading...</span>
                    ) : (
                      <>
                        {currency === 'USD' ? '$' : ''}
                        {formatPrice(data?.current)}
                      </>
                    )}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-slate-400 text-sm mb-1">{range} Change</div>
                  <div
                    className="text-2xl md:text-3xl font-bold"
                    style={{ color: changeColor }}
                  >
                    {formatChange(data?.period_change_pct)}
                  </div>
                </div>
              </div>
            </div>

            {/* BTC Inverse - How many coins to buy 1 BTC */}
            {coinsPerBtc && (
              <div className="bg-slate-800/50 rounded-xl p-4 mb-6 text-center">
                <span className="text-slate-400">To buy 1 BTC: </span>
                <span className="text-xl font-bold text-amber-400">
                  {coinsPerBtc} {coin}
                </span>
              </div>
            )}

            {/* Chart - Lazy loaded */}
            <div className="bg-slate-800/50 rounded-xl p-4 mb-6">
              <LazyChart key={`${coin}-${range}-${currency}`} data={chartData} mean={data?.mean} currency={currency} />
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
              <StatCard label="High" value={formatPrice(data?.high)} />
              <StatCard label="Low" value={formatPrice(data?.low)} />
              <StatCard label="Mean" value={formatPrice(data?.mean)} />
              <StatCard
                label="Percentile"
                value={data?.percentile != null ? `${data.percentile}%` : '--'}
              />
            </div>
          </>
        )}

        {activeTab === 'Portfolio' && (
          <div className="space-y-6">
            {/* Allocation Approach Subtabs */}
            <div className="flex gap-2 flex-wrap">
              {(['mpt', 'kelly', 'scenario'] as const).map((approach) => (
                <button
                  key={approach}
                  onClick={() => setAllocationApproach(approach)}
                  className={`py-2 px-4 rounded-lg font-medium text-sm transition-all ${
                    allocationApproach === approach
                      ? 'bg-purple-600 text-white'
                      : 'bg-slate-800/50 text-slate-400 hover:bg-slate-700'
                  }`}
                >
                  {approach === 'mpt' && 'MPT'}
                  {approach === 'kelly' && 'Kelly Sizing'}
                  {approach === 'scenario' && 'Scenarios'}
                </button>
              ))}
            </div>

            {/* Approach Description */}
            <div className="bg-slate-800/50 rounded-xl p-4">
              <h3 className="font-bold text-white mb-1">
                {ALLOCATION_APPROACHES[allocationApproach].name}
              </h3>
              <p className="text-slate-400 text-sm">
                {ALLOCATION_APPROACHES[allocationApproach].description}
              </p>
            </div>

            {/* 10-Year Projection Calculator */}
            {allocationApproach === 'mpt' && (
              <div className="bg-gradient-to-br from-slate-800/80 to-slate-900/80 rounded-xl p-6 border border-slate-700">
                <h2 className="text-xl font-bold text-white mb-4">10-Year Projection: $100K Portfolio</h2>
                {(() => {
                  const projection = calculateProjection(investmentAmount, 45.2, 28.5, 10);
                  return (
                    <div className="space-y-4">
                      <div className="grid grid-cols-3 gap-4">
                        <div className="bg-slate-700/50 rounded-lg p-4 text-center">
                          <div className="text-slate-400 text-xs mb-1">10th Percentile</div>
                          <div className="text-2xl font-bold text-red-400">
                            ${Math.round(projection.low).toLocaleString()}
                          </div>
                          <div className="text-slate-500 text-xs">Bearish outcome</div>
                        </div>
                        <div className="bg-slate-700/50 rounded-lg p-4 text-center border-2 border-green-500/30">
                          <div className="text-slate-400 text-xs mb-1">Expected Value</div>
                          <div className="text-2xl font-bold text-green-400">
                            ${Math.round(projection.expected).toLocaleString()}
                          </div>
                          <div className="text-slate-500 text-xs">Most likely</div>
                        </div>
                        <div className="bg-slate-700/50 rounded-lg p-4 text-center">
                          <div className="text-slate-400 text-xs mb-1">90th Percentile</div>
                          <div className="text-2xl font-bold text-blue-400">
                            ${Math.round(projection.high).toLocaleString()}
                          </div>
                          <div className="text-slate-500 text-xs">Bullish outcome</div>
                        </div>
                      </div>
                      <div className="bg-slate-700/30 rounded-lg p-3">
                        <p className="text-slate-400 text-sm">
                          <span className="text-amber-400 font-semibold">80% confidence:</span> Your $100K has an 80% chance of being worth between ${Math.round(projection.low).toLocaleString()} and ${Math.round(projection.high).toLocaleString()} in 10 years.
                        </p>
                      </div>
                    </div>
                  );
                })()}
              </div>
            )}

            {/* MPT Stats */}
            {allocationApproach === 'mpt' && (
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-slate-800/50 rounded-lg p-3 text-center">
                  <div className="text-slate-400 text-xs">Expected Return/yr</div>
                  <div className="text-xl font-bold text-green-400">+{ALLOCATION_APPROACHES.mpt.expectedReturn}%</div>
                </div>
                <div className="bg-slate-800/50 rounded-lg p-3 text-center">
                  <div className="text-slate-400 text-xs">Volatility</div>
                  <div className="text-xl font-bold text-amber-400">{ALLOCATION_APPROACHES.mpt.volatility}%</div>
                </div>
                <div className="bg-slate-800/50 rounded-lg p-3 text-center">
                  <div className="text-slate-400 text-xs">Sharpe Ratio</div>
                  <div className="text-xl font-bold text-blue-400">{ALLOCATION_APPROACHES.mpt.sharpeRatio}</div>
                </div>
              </div>
            )}

            {/* Kelly Edge Scores */}
            {allocationApproach === 'kelly' && (
              <div className="bg-slate-800/50 rounded-xl p-6">
                <h3 className="font-bold text-white mb-4">Conviction Edge Scores</h3>
                <div className="space-y-3">
                  {Object.entries(ALLOCATION_APPROACHES.kelly.edgeScores)
                    .sort(([, a], [, b]) => b.edge - a.edge)
                    .map(([symbol, data]) => (
                      <div key={symbol} className="flex items-center gap-3">
                        <div className="w-14 font-bold text-white">{symbol}</div>
                        <div className="flex-1">
                          <div className="flex justify-between text-xs mb-1">
                            <span className="text-slate-400">{data.description}</span>
                            <span className="text-purple-400">{(data.edge * 100).toFixed(0)}% edge</span>
                          </div>
                          <div className="bg-slate-700 rounded-full h-2 overflow-hidden">
                            <div
                              className="h-full bg-gradient-to-r from-purple-600 to-purple-400"
                              style={{ width: `${data.edge * 100}%` }}
                            />
                          </div>
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            )}

            {/* Scenario Analysis */}
            {allocationApproach === 'scenario' && (
              <div className="grid md:grid-cols-2 gap-4">
                {Object.entries(ALLOCATION_APPROACHES.scenario.scenarios).map(([key, scenario]) => (
                  <div key={key} className={`bg-slate-800/50 rounded-xl p-4 border ${key === 'crisis' ? 'border-red-500/30' : 'border-green-500/30'}`}>
                    <div className="flex justify-between items-start mb-2">
                      <h4 className="font-bold text-white">{scenario.name}</h4>
                      <span className={`text-xs px-2 py-1 rounded ${key === 'crisis' ? 'bg-red-900/50 text-red-300' : 'bg-green-900/50 text-green-300'}`}>
                        {scenario.probability}% likely
                      </span>
                    </div>
                    <p className="text-slate-400 text-sm mb-3">{scenario.description}</p>
                    <div className="space-y-1">
                      {Object.entries(scenario.weights)
                        .sort(([, a], [, b]) => b - a)
                        .slice(0, 4)
                        .map(([symbol, weight]) => (
                          <div key={symbol} className="flex items-center gap-2 text-sm">
                            <span className="w-10 text-slate-300">{symbol}</span>
                            <div className="flex-1 bg-slate-700 rounded-full h-3 overflow-hidden">
                              <div
                                className={`h-full ${key === 'crisis' ? 'bg-red-500' : 'bg-green-500'}`}
                                style={{ width: `${weight}%` }}
                              />
                            </div>
                            <span className="text-slate-400 w-8 text-right">{weight}%</span>
                          </div>
                        ))}
                    </div>
                    <p className="text-slate-500 text-xs mt-2 italic">{scenario.rationale}</p>
                  </div>
                ))}
              </div>
            )}

            {/* Blended Weights for Scenario */}
            {allocationApproach === 'scenario' && (
              <div className="bg-slate-800/50 rounded-xl p-4">
                <h4 className="font-bold text-white mb-2">Probability-Weighted Allocation</h4>
                <p className="text-slate-400 text-xs mb-3">70% normal + 30% crisis = blended portfolio</p>
                <div className="space-y-2">
                  {Object.entries(ALLOCATION_APPROACHES.scenario.blendedWeights)
                    .sort(([, a], [, b]) => b - a)
                    .map(([symbol, weight]) => (
                      <div key={symbol} className="flex items-center gap-3">
                        <div className="w-12 font-bold text-white">{symbol}</div>
                        <div className="flex-1 bg-slate-700 rounded-full h-5 overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-amber-600 to-amber-400 flex items-center justify-end pr-2"
                            style={{ width: `${weight}%` }}
                          >
                            <span className="text-xs font-bold text-white">{weight}%</span>
                          </div>
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            )}

            {/* Allocation Bars (for MPT and Kelly) */}
            {(allocationApproach === 'mpt' || allocationApproach === 'kelly') && (
              <div className="bg-slate-800/50 rounded-xl p-6">
                <h2 className="text-xl font-bold text-white mb-4">
                  {allocationApproach === 'mpt' ? 'MPT Optimal' : 'Kelly-Sized'} Allocation
                </h2>
                <div className="space-y-3">
                  {Object.entries(ALLOCATION_APPROACHES[allocationApproach].weights)
                    .sort(([, a], [, b]) => b - a)
                    .map(([symbol, weight]) => (
                      <div key={symbol} className="flex items-center gap-3">
                        <div className="w-12 font-bold text-white">{symbol}</div>
                        <div className="flex-1 bg-slate-700 rounded-full h-6 overflow-hidden">
                          <div
                            className={`h-full flex items-center justify-end pr-2 ${
                              allocationApproach === 'kelly'
                                ? 'bg-gradient-to-r from-purple-600 to-purple-400'
                                : 'bg-gradient-to-r from-blue-600 to-blue-400'
                            }`}
                            style={{ width: `${weight}%` }}
                          >
                            <span className="text-xs font-bold text-white">{weight}%</span>
                          </div>
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            )}

            <p className="text-slate-500 text-xs">
              * These allocations are for educational purposes. Your personal allocation should consider your risk tolerance, investment horizon, and financial situation.
            </p>
          </div>
        )}

        {activeTab === 'Assets' && (
          <div className="space-y-4">
            {/* Legend */}
            <div className="bg-slate-800/50 rounded-xl p-4 mb-4">
              <p className="text-slate-300 mb-3">
                Each crypto occupies a unique &quot;niche&quot; in the ecosystem. Understanding these niches helps explain why you might hold multiple assets.
              </p>
              <div className="flex gap-4 text-sm">
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full bg-blue-500"></span>
                  <span className="text-slate-400">Money for Humans</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full bg-purple-500"></span>
                  <span className="text-slate-400">Money for AI Agents</span>
                </div>
              </div>
            </div>

            {COINS.map((symbol) => {
              const info = ASSET_INFO[symbol];
              return (
                <div key={symbol} className="bg-slate-800/50 rounded-xl p-6">
                  {/* Header with niche badge */}
                  <div className="flex flex-wrap items-center gap-3 mb-3">
                    <span className={`font-bold px-3 py-1 rounded-lg ${info.category === 'humans' ? 'bg-blue-600 text-white' : 'bg-purple-600 text-white'}`}>
                      {symbol}
                    </span>
                    <h3 className="text-lg font-bold text-white">{info.name}</h3>
                    <span className="text-xs px-2 py-1 bg-slate-700 text-slate-300 rounded">
                      {info.niche}
                    </span>
                  </div>

                  {/* Description */}
                  <div className="mb-4">
                    <h4 className="text-amber-400 text-sm font-semibold mb-1">What is it?</h4>
                    <p className="text-slate-300 text-sm">{info.description}</p>
                  </div>

                  {/* Value Proposition */}
                  <div className="mb-4">
                    <h4 className="text-green-400 text-sm font-semibold mb-1">Why it could hold value for 10+ years</h4>
                    <p className="text-slate-300 text-sm">{info.valueProposition}</p>
                  </div>

                  {/* Use Cases */}
                  <div>
                    <h4 className="text-cyan-400 text-sm font-semibold mb-2">Real-World Use Cases</h4>
                    <ul className="space-y-1">
                      {info.useCases.map((useCase, idx) => (
                        <li key={idx} className="text-slate-400 text-sm flex items-start gap-2">
                          <span className="text-cyan-400 mt-1">•</span>
                          {useCase}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Footer */}
        <div className="text-center text-slate-500 text-sm mt-6">
          {activeTab === 'Tracker' && (
            <>
              Data points: {data?.data_points || '--'} | Updated:{' '}
              {data?.timestamp
                ? new Date(data.timestamp).toLocaleString()
                : '--'}
              <br />
            </>
          )}
          Powered by Next.js + Supabase | v6.0
        </div>
      </div>
    </main>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-slate-800/50 rounded-lg p-4">
      <div className="text-slate-400 text-xs mb-1">{label}</div>
      <div className="text-lg font-semibold text-white">{value}</div>
    </div>
  );
}
