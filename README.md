# BTC Price Tracker

Real-time Bitcoin price tracking with interactive Plotly charts.

## Features

- Live BTC price from CoinGecko API
- Auto-refresh every 60 seconds
- Interactive price chart
- 24-hour high/low stats
- Dark theme UI

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Dashboard with chart |
| GET | `/health` | Health check |
| GET | `/price` | Current BTC price |
| GET | `/history` | Price history data |

## Built With

- R 4.3.0
- Plumber (R web framework)
- Plotly.js (charts)
- CoinGecko API (price data)
- Docker

## Deploy

```bash
docker build -t btc-tracker .
docker run -d -p 8080:10000 btc-tracker
```

---

*Part of Taskomation - https://taskomation.com*
