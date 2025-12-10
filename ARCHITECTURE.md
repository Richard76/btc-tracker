# Crypto Price Tracker - Architecture

**Live URL:** https://btc.apps.taskomation.com

---

## Overview

Multi-coin cryptocurrency price tracker with persistent storage and historical data.

**Coins Tracked:** BTC, ETH, SOL, LINK, AVAX, POL, NEAR

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Cron Job       │────▶│  CoinGecko   │────▶│  Supabase    │
│  (every minute) │     │  API         │     │  (storage)   │
└─────────────────┘     └──────────────┘     └──────┬───────┘
                                                    │
                                                    ▼
                        ┌──────────────┐     ┌──────────────┐
                        │  User        │◀────│  R/Plumber   │
                        │  Browser     │     │  Dashboard   │
                        └──────────────┘     └──────────────┘
```

---

## Components

### 1. Price Fetcher (Cron Job)

**Location:** DigitalOcean server (170.64.158.125)
**Script:** `/root/fetch-crypto.sh`
**Schedule:** Every minute via crontab

```bash
# View cron
crontab -l

# View logs
tail -f /var/log/crypto-fetch.log

# Manual run
/root/fetch-crypto.sh
```

### 2. Supabase Database

**Table:** `crypto_prices`

| Column | Type | Description |
|--------|------|-------------|
| id | BIGSERIAL | Primary key |
| symbol | TEXT | Coin symbol (BTC, ETH, etc.) |
| price_usd | DECIMAL(18,8) | Price in USD |
| timestamp | TIMESTAMPTZ | When fetched |
| source | TEXT | Always "coingecko" |

**Index:** `idx_crypto_symbol_time` on (symbol, timestamp DESC)

**Data volume:** ~302,400 rows/month (7 coins × 1440 min/day × 30 days)

### 3. R/Plumber Dashboard

**Container:** `btc-tracker`
**Network:** coolify (for Traefik integration)
**Port:** 10000 (internal)
**Domain:** btc.apps.taskomation.com (HTTPS via Traefik)

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Dashboard with interactive chart |
| GET | `/health` | Health check |
| GET | `/price?symbol=BTC` | Current price for a coin |
| GET | `/history?symbol=BTC&limit=1440` | Price history |
| GET | `/prices` | All 7 latest prices |

---

## Dashboard Features

- **Coin selector buttons** - Click to switch between coins
- **Price color coding** - Green (above 24h mean), Red (below)
- **Warning banner** - Shows when price below lower-half average
- **24h Percentile** - Where current price ranks vs. history
- **Auto-refresh** - Every 60 seconds with countdown timer
- **Interactive Plotly chart** - Zoom, pan, hover for details

---

## Maintenance

### Rebuild & Deploy

```bash
# SSH to server
ssh root@170.64.158.125

# Pull and rebuild
cd /tmp/btc-tracker
git pull
docker build -t btc-tracker .

# Redeploy
docker rm -f btc-tracker
docker run -d --name btc-tracker \
  --network coolify \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.btc.rule=Host(\`btc.apps.taskomation.com\`)" \
  --label "traefik.http.routers.btc.entrypoints=https" \
  --label "traefik.http.routers.btc.tls=true" \
  --label "traefik.http.routers.btc.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.btc.loadbalancer.server.port=10000" \
  --restart always \
  btc-tracker
```

### Check Data in Supabase

```bash
curl -s 'https://kzltorgncwddsjiqbooh.supabase.co/rest/v1/crypto_prices?order=timestamp.desc&limit=10' \
  -H 'apikey: [SUPABASE_KEY]' \
  -H 'Authorization: Bearer [SUPABASE_KEY]'
```

### Cleanup Old Data (run in Supabase SQL Editor)

```sql
DELETE FROM crypto_prices WHERE timestamp < NOW() - INTERVAL '30 days';
```

---

## Files

| File | Description |
|------|-------------|
| `plumber.R` | R API and dashboard code |
| `Dockerfile` | Docker build config |
| `fetch-crypto.sh` | Cron script (also on server) |
| `README.md` | Basic project info |
| `ARCHITECTURE.md` | This file |

---

## Costs

| Service | Cost |
|---------|------|
| DigitalOcean (hosting + cron) | $12/mo |
| Supabase (database) | Free tier |
| CoinGecko API | Free tier |
| Domain/SSL | Included via Traefik |

---

*Created: December 10, 2025*
