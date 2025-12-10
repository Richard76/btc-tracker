# Crypto Price Tracker API
# R + Plumber + Supabase

library(plumber)
library(jsonlite)

# Supabase config
SUPABASE_URL <- "https://kzltorgncwddsjiqbooh.supabase.co"
SUPABASE_KEY <- "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6bHRvcmduY3dkZHNqaXFib29oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2MzMyMDQsImV4cCI6MjA4MDIwOTIwNH0.RQGSeITtZXyZI-npBLyj0rZXWXjQ8mdqkrSO6VovBQE"

# Convert range to limit
range_to_limit <- function(range) {
  switch(range,
    "24h" = 1440,
    "7d" = 10080,
    "30d" = 43200,
    1440  # default
  )
}

# Fetch prices from Supabase using curl
fetch_prices <- function(symbol = "BTC", limit = 1440) {
  tryCatch({
    url <- paste0(SUPABASE_URL, "/rest/v1/crypto_prices?symbol=eq.", symbol,
                  "&order=timestamp.desc&limit=", limit)
    cmd <- sprintf('curl -s "%s" -H "apikey: %s" -H "Authorization: Bearer %s"',
                   url, SUPABASE_KEY, SUPABASE_KEY)
    response <- system(cmd, intern = TRUE)
    data <- fromJSON(paste(response, collapse = ""))
    return(data)
  }, error = function(e) {
    return(NULL)
  })
}

# Get latest price for a symbol
get_latest_price <- function(symbol = "BTC") {
  data <- fetch_prices(symbol, 1)
  if (!is.null(data) && nrow(data) > 0) {
    return(list(
      symbol = data$symbol[1],
      price_usd = data$price_usd[1],
      timestamp = data$timestamp[1]
    ))
  }
  return(list(symbol = symbol, price_usd = NA, timestamp = NA))
}

#* @apiTitle Crypto Price Tracker
#* @apiDescription Multi-coin price tracking with Supabase storage

#* Health check
#* @get /health
function() {
  list(
    status = "ok",
    service = "Crypto Price Tracker",
    version = "2.1.0",
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
    source = "Supabase"
  )
}

#* Get current price for a symbol
#* @param symbol Coin symbol (BTC, ETH, SOL, LINK, AVAX, POL, NEAR)
#* @get /price
function(symbol = "BTC") {
  get_latest_price(toupper(symbol))
}

#* Get price history for a symbol with time range
#* @param symbol Coin symbol
#* @param range Time range: 24h, 7d, 30d
#* @get /history
function(symbol = "BTC", range = "24h") {
  limit <- range_to_limit(range)
  data <- fetch_prices(toupper(symbol), limit)
  if (!is.null(data) && nrow(data) > 0) {
    list(
      symbol = toupper(symbol),
      range = range,
      data_points = nrow(data),
      history = data
    )
  } else {
    list(symbol = toupper(symbol), range = range, data_points = 0, history = data.frame())
  }
}

#* Get all latest prices
#* @get /prices
function() {
  symbols <- c("BTC", "ETH", "SOL", "LINK", "AVAX", "POL", "NEAR")
  prices <- lapply(symbols, get_latest_price)
  names(prices) <- symbols
  prices
}

#* Serve the dashboard HTML
#* @get /
#* @serializer html
function() {
  html <- '
<!DOCTYPE html>
<html>
<head>
  <title>Crypto Price Tracker</title>
  <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0f172a;
      color: #f1f5f9;
      min-height: 100vh;
      padding: 20px;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 {
      font-size: 2rem;
      margin-bottom: 10px;
      color: #f59e0b;
    }
    .selector-row {
      display: flex;
      gap: 20px;
      margin: 20px 0;
      flex-wrap: wrap;
      align-items: center;
    }
    .selector-group {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
    .selector-label {
      color: #64748b;
      font-size: 0.8rem;
      margin-right: 8px;
      align-self: center;
    }
    .coin-btn, .range-btn {
      padding: 8px 16px;
      border: 2px solid #334155;
      background: #1e293b;
      color: #f1f5f9;
      border-radius: 6px;
      cursor: pointer;
      font-weight: bold;
      font-size: 0.9rem;
      transition: all 0.2s;
    }
    .coin-btn:hover, .range-btn:hover { border-color: #f59e0b; }
    .coin-btn.active { border-color: #f59e0b; background: #f59e0b; color: #0f172a; }
    .range-btn.active { border-color: #10b981; background: #10b981; color: #0f172a; }
    .price-display {
      font-size: 3rem;
      font-weight: bold;
      color: #10b981;
      margin: 20px 0;
    }
    .timestamp {
      color: #64748b;
      font-size: 0.9rem;
      margin-bottom: 20px;
    }
    #chart {
      background: #1e293b;
      border-radius: 12px;
      padding: 20px;
      margin-top: 20px;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
      gap: 12px;
      margin: 20px 0;
    }
    .stat-card {
      background: #1e293b;
      padding: 12px;
      border-radius: 8px;
      text-align: center;
    }
    .stat-label { color: #64748b; font-size: 0.75rem; }
    .stat-value { font-size: 1.1rem; font-weight: bold; margin-top: 4px; }
    .footer {
      text-align: center;
      margin-top: 30px;
      color: #64748b;
      font-size: 0.8rem;
    }
    .warning {
      background: #7f1d1d;
      border: 2px solid #ef4444;
      color: #fca5a5;
      padding: 12px 20px;
      border-radius: 8px;
      margin: 15px 0;
      font-weight: bold;
      display: none;
    }
    .warning.show { display: block; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Crypto Price Tracker</h1>

    <div class="selector-row">
      <div class="selector-group">
        <span class="selector-label">COIN:</span>
        <button class="coin-btn active" data-symbol="BTC">BTC</button>
        <button class="coin-btn" data-symbol="ETH">ETH</button>
        <button class="coin-btn" data-symbol="SOL">SOL</button>
        <button class="coin-btn" data-symbol="LINK">LINK</button>
        <button class="coin-btn" data-symbol="AVAX">AVAX</button>
        <button class="coin-btn" data-symbol="POL">POL</button>
        <button class="coin-btn" data-symbol="NEAR">NEAR</button>
      </div>
      <div class="selector-group">
        <span class="selector-label">RANGE:</span>
        <button class="range-btn active" data-range="24h">24H</button>
        <button class="range-btn" data-range="7d">7D</button>
        <button class="range-btn" data-range="30d">30D</button>
      </div>
    </div>

    <div class="price-display" id="current-price">Loading...</div>
    <div class="timestamp" id="last-update">Last update: Loading...</div>
    <div class="warning" id="dip-warning">WARNING: Price below lower-half average - significant dip detected!</div>

    <div class="stats">
      <div class="stat-card">
        <div class="stat-label">Data Points</div>
        <div class="stat-value" id="data-points">0</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">High</div>
        <div class="stat-value" id="high-price">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Low</div>
        <div class="stat-value" id="low-price">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Mean</div>
        <div class="stat-value" id="mean-price">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Percentile</div>
        <div class="stat-value" id="percentile">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Next Update</div>
        <div class="stat-value" id="countdown">60</div>
      </div>
    </div>

    <div id="chart"></div>

    <div class="footer">
      Powered by R + Plumber + Supabase | Data updates every minute | 7 coins tracked
    </div>
  </div>

  <script>
    let currentSymbol = "BTC";
    let currentRange = "24h";
    let priceMean = null;
    let lowerHalfMean = null;
    let priceHistory = [];

    function formatPrice(price) {
      if (price >= 1) {
        return "$" + price.toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2});
      } else {
        return "$" + price.toFixed(6);
      }
    }

    function calculatePercentile(prices, currentPrice) {
      const sorted = [...prices].sort((a, b) => a - b);
      let count = 0;
      for (const p of sorted) {
        if (p < currentPrice) count++;
      }
      return Math.round((count / sorted.length) * 100);
    }

    function updateChart() {
      fetch("/history?symbol=" + currentSymbol + "&range=" + currentRange)
        .then(r => r.json())
        .then(data => {
          const history = data.history;
          if (!history || !history.timestamp || history.timestamp.length === 0) {
            document.getElementById("data-points").textContent = "0";
            return;
          }

          const timestamps = history.timestamp;
          const prices = history.price_usd;

          document.getElementById("data-points").textContent = data.data_points;
          if (prices && prices.length > 0) {
            priceHistory = prices;
            const high = Math.max(...prices);
            const low = Math.min(...prices);
            priceMean = prices.reduce((a, b) => a + b, 0) / prices.length;
            document.getElementById("high-price").textContent = formatPrice(high);
            document.getElementById("low-price").textContent = formatPrice(low);
            document.getElementById("mean-price").textContent = formatPrice(priceMean);
            const sorted = [...prices].sort((a, b) => a - b);
            const lowerHalf = sorted.slice(0, Math.ceil(sorted.length / 2));
            lowerHalfMean = lowerHalf.reduce((a, b) => a + b, 0) / lowerHalf.length;
          }

          const trace = {
            x: timestamps,
            y: prices,
            type: "scatter",
            mode: "lines",
            line: { color: "#f59e0b", width: 2 },
            fill: "tozeroy",
            fillcolor: "rgba(245, 158, 11, 0.1)"
          };

          const layout = {
            paper_bgcolor: "#1e293b",
            plot_bgcolor: "#1e293b",
            font: { color: "#f1f5f9" },
            xaxis: { gridcolor: "#334155", title: "Time" },
            yaxis: { gridcolor: "#334155", title: "Price (USD)", tickprefix: "$" },
            margin: { t: 20, r: 20, b: 50, l: 80 }
          };

          Plotly.newPlot("chart", [trace], layout, {responsive: true});
        });
    }

    function updatePrice() {
      fetch("/price?symbol=" + currentSymbol)
        .then(r => r.json())
        .then(data => {
          const priceEl = document.getElementById("current-price");
          const warningEl = document.getElementById("dip-warning");

          if (data.price_usd) {
            priceEl.textContent = formatPrice(data.price_usd);

            if (priceMean !== null) {
              priceEl.style.color = data.price_usd >= priceMean ? "#10b981" : "#ef4444";
            }

            if (lowerHalfMean !== null && priceHistory.length >= 2) {
              warningEl.classList.toggle("show", data.price_usd < lowerHalfMean);
            }

            if (priceHistory.length >= 2) {
              const pct = calculatePercentile(priceHistory, data.price_usd);
              document.getElementById("percentile").textContent = pct + "%";
            }
          }

          document.getElementById("last-update").textContent = "Last update: " + (data.timestamp || "N/A");
          updateChart();
        });
    }

    function selectCoin(symbol) {
      currentSymbol = symbol;
      document.querySelectorAll(".coin-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.symbol === symbol);
      });
      resetStats();
      updatePrice();
    }

    function selectRange(range) {
      currentRange = range;
      document.querySelectorAll(".range-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.range === range);
      });
      resetStats();
      updateChart();
    }

    function resetStats() {
      priceMean = null;
      lowerHalfMean = null;
      priceHistory = [];
      document.getElementById("current-price").textContent = "Loading...";
      document.getElementById("dip-warning").classList.remove("show");
      document.getElementById("high-price").textContent = "-";
      document.getElementById("low-price").textContent = "-";
      document.getElementById("mean-price").textContent = "-";
      document.getElementById("percentile").textContent = "-";
    }

    document.querySelectorAll(".coin-btn").forEach(btn => {
      btn.addEventListener("click", () => selectCoin(btn.dataset.symbol));
    });

    document.querySelectorAll(".range-btn").forEach(btn => {
      btn.addEventListener("click", () => selectRange(btn.dataset.range));
    });

    let countdown = 60;
    function updateCountdown() {
      countdown--;
      document.getElementById("countdown").textContent = countdown;
      if (countdown <= 0) {
        updatePrice();
        countdown = 60;
      }
    }

    updatePrice();
    setInterval(updateCountdown, 1000);
  </script>
</body>
</html>
'
  html
}
