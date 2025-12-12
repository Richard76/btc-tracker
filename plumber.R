# Crypto Price Tracker API v4.1
# R + Plumber + Supabase with Pre-cached Stats + USD/BTC pricing + Appreciation/Depreciation
# All calculations done in R, cache refreshed every 60s

library(plumber)
library(jsonlite)

# Supabase config
SUPABASE_URL <- "https://kzltorgncwddsjiqbooh.supabase.co"
SUPABASE_KEY <- "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6bHRvcmduY3dkZHNqaXFib29oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2MzMyMDQsImV4cCI6MjA4MDIwOTIwNH0.RQGSeITtZXyZI-npBLyj0rZXWXjQ8mdqkrSO6VovBQE"

# Coins, ranges, and currencies
COINS <- c("BTC", "ETH", "SOL", "LINK", "AVAX", "POL", "NEAR")
RANGES <- c("1h", "24h", "7d", "30d", "90d")
CURRENCIES <- c("USD", "BTC")

# Cache storage
stats_cache <- new.env()
cache_timestamp <- Sys.time()

# Convert range to hours for time filtering
range_to_hours <- function(range) {
  switch(range,
    "1h" = 1,
    "24h" = 24,
    "7d" = 168,
    "30d" = 720,
    "90d" = 2160,
    24
  )
}

# Fetch prices from Supabase using time-based filtering
fetch_prices <- function(symbol = "BTC", range = "24h") {
  tryCatch({
    hours <- range_to_hours(range)
    # Calculate cutoff time in ISO format
    cutoff <- format(Sys.time() - hours * 3600, "%Y-%m-%dT%H:%M:%S", tz = "UTC")

    url <- paste0(SUPABASE_URL, "/rest/v1/crypto_prices?symbol=eq.", symbol,
                  "&timestamp=gte.", cutoff,
                  "&order=timestamp.desc&limit=50000")
    cmd <- sprintf('curl -s "%s" -H "apikey: %s" -H "Authorization: Bearer %s"',
                   url, SUPABASE_KEY, SUPABASE_KEY)
    response <- system(cmd, intern = TRUE)
    fromJSON(paste(response, collapse = ""))
  }, error = function(e) NULL)
}

# Calculate all stats for a coin/range combo (in R)
# currency: "USD" or "BTC"
calculate_stats <- function(symbol, range, currency = "USD") {
  data <- fetch_prices(symbol, range)

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      symbol = symbol,
      range = range,
      currency = currency,
      data_points = 0,
      current = NA,
      start_price = NA,
      period_change_pct = NA,
      high = NA,
      low = NA,
      mean = NA,
      percentile = NA,
      lower_half_mean = NA,
      history = list(),
      timestamp = NA
    ))
  }

  prices <- data$price_usd
  timestamps <- data$timestamp

  # If BTC pricing requested and symbol is not BTC itself
  if (currency == "BTC" && symbol != "BTC") {
    btc_data <- fetch_prices("BTC", range)
    if (!is.null(btc_data) && nrow(btc_data) > 0) {
      # Parse timestamps to numeric (seconds since epoch) for reliable matching
      coin_times <- as.numeric(as.POSIXct(timestamps, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
      btc_times <- as.numeric(as.POSIXct(btc_data$timestamp, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
      btc_usd <- btc_data$price_usd

      # For each coin timestamp, find closest BTC price and divide
      prices_btc <- sapply(seq_along(prices), function(i) {
        coin_time <- coin_times[i]
        # Find index of closest BTC timestamp
        diffs <- abs(btc_times - coin_time)
        closest_idx <- which.min(diffs)
        prices[i] / btc_usd[closest_idx]
      })
      prices <- as.numeric(prices_btc)
    }
  } else if (currency == "BTC" && symbol == "BTC") {
    # BTC priced in BTC is always 1
    prices <- rep(1, length(prices))
  }

  n <- length(prices)
  current <- prices[1]
  start_price <- prices[n]  # Last entry is the oldest (start of period)

  # Five-number summary + stats
  sorted <- sort(prices)
  high <- max(prices)
  low <- min(prices)
  mean_val <- mean(prices)

  # Percentile of current price (what % of historical prices are below current)
  pct_rank <- round(sum(prices < current) / n * 100)

  # Lower half mean (for dip warning)
  lower_half <- sorted[1:ceiling(n/2)]
  lower_half_mean <- mean(lower_half)

  # Period change: appreciation (positive) or depreciation (negative)
  # Calculate as percentage change from start to current
  period_change_pct <- if (start_price > 0) {
    round((current - start_price) / start_price * 100, 2)
  } else {
    NA
  }

  list(
    symbol = symbol,
    range = range,
    currency = currency,
    data_points = n,
    current = current,
    start_price = start_price,
    period_change_pct = period_change_pct,
    high = high,
    low = low,
    mean = mean_val,
    percentile = pct_rank,
    lower_half_mean = lower_half_mean,
    history = data.frame(
      timestamp = timestamps,
      price = prices
    ),
    timestamp = timestamps[1]
  )
}

# Refresh cache for all combinations (both currencies)
refresh_cache <- function() {
  message("Refreshing stats cache...")
  for (symbol in COINS) {
    for (range in RANGES) {
      for (currency in CURRENCIES) {
        key <- paste0(symbol, "_", range, "_", currency)
        stats_cache[[key]] <- calculate_stats(symbol, range, currency)
      }
    }
  }
  cache_timestamp <<- Sys.time()
  message("Cache refreshed at ", cache_timestamp)
}

# Get stats from cache (or calculate if missing)
get_cached_stats <- function(symbol, range, currency = "USD") {
  key <- paste0(symbol, "_", range, "_", currency)
  if (is.null(stats_cache[[key]])) {
    stats_cache[[key]] <- calculate_stats(symbol, range, currency)
  }
  stats_cache[[key]]
}

# Skip cache on startup - load lazily on first request
# This allows the server to start immediately and pass health checks
message("Server starting - cache will load on first request")

#* @apiTitle Crypto Price Tracker
#* @apiDescription Multi-coin price tracking with Supabase storage and pre-cached stats

#* Health check
#* @get /health
function() {
  list(
    status = "ok",
    service = "Crypto Price Tracker",
    version = "4.1.0",
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
    cache_age_seconds = as.numeric(difftime(Sys.time(), cache_timestamp, units = "secs"))
  )
}

#* Get dashboard data (stats + history for one coin/range)
#* @param symbol Coin symbol
#* @param range Time range: 24h, 7d, 30d
#* @param currency Currency: USD or BTC
#* @get /dashboard
function(symbol = "BTC", range = "24h", currency = "USD") {
  # Check if cache needs refresh (> 60 seconds old)
  age <- as.numeric(difftime(Sys.time(), cache_timestamp, units = "secs"))
  if (age > 60) {
    refresh_cache()
  }
  get_cached_stats(toupper(symbol), range, toupper(currency))
}

#* Get current price for a symbol
#* @param symbol Coin symbol
#* @get /price
function(symbol = "BTC") {
  stats <- get_cached_stats(toupper(symbol), "24h")
  list(
    symbol = stats$symbol,
    price_usd = stats$current,
    timestamp = stats$timestamp
  )
}

#* Get price history for a symbol
#* @param symbol Coin symbol
#* @param range Time range: 24h, 7d, 30d
#* @get /history
function(symbol = "BTC", range = "24h") {
  stats <- get_cached_stats(toupper(symbol), range)
  list(
    symbol = stats$symbol,
    range = stats$range,
    data_points = stats$data_points,
    history = stats$history
  )
}

#* Get all latest prices
#* @get /prices
function() {
  prices <- lapply(COINS, function(sym) {
    stats <- get_cached_stats(sym, "24h")
    list(symbol = sym, price_usd = stats$current, timestamp = stats$timestamp)
  })
  names(prices) <- COINS
  prices
}

#* Force cache refresh
#* @get /refresh
function() {
  refresh_cache()
  list(status = "refreshed", timestamp = format(cache_timestamp))
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
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg width=\'128\' height=\'128\' viewBox=\'0 0 128 128\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Crect width=\'128\' height=\'128\' rx=\'16\' fill=\'%230f172a\'/%3E%3Ctext x=\'64\' y=\'82\' font-family=\'Arial\' font-size=\'72\' font-weight=\'bold\' text-anchor=\'middle\' fill=\'white\'%3ET%3Ctspan fill=\'%2310B981\'%3Eo%3C/tspan%3E%3C/text%3E%3C/svg%3E">
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
    .coin-btn, .range-btn, .currency-btn {
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
    .coin-btn:hover, .range-btn:hover, .currency-btn:hover { border-color: #f59e0b; }
    .coin-btn.active { border-color: #f59e0b; background: #f59e0b; color: #0f172a; }
    .range-btn.active { border-color: #10b981; background: #10b981; color: #0f172a; }
    .currency-btn.active { border-color: #8b5cf6; background: #8b5cf6; color: #0f172a; }
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
    .loading { opacity: 0.5; }
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
      <div class="selector-group">
        <span class="selector-label">PRICE IN:</span>
        <button class="currency-btn active" data-currency="USD">USD</button>
        <button class="currency-btn" data-currency="BTC">BTC</button>
      </div>
    </div>

    <div class="price-display" id="current-price">$--</div>
    <div class="timestamp" id="last-update">Last update: --</div>
    <div class="warning" id="dip-warning">WARNING: Price below lower-half average - significant dip detected!</div>

    <div class="stats">
      <div class="stat-card">
        <div class="stat-label">Data Points</div>
        <div class="stat-value" id="data-points">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">High</div>
        <div class="stat-value" id="high-price">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Low</div>
        <div class="stat-value" id="low-price">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Mean</div>
        <div class="stat-value" id="mean-price">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Percentile</div>
        <div class="stat-value" id="percentile">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Change</div>
        <div class="stat-value" id="period-change">--</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Next Update</div>
        <div class="stat-value" id="countdown">60</div>
      </div>
    </div>

    <div id="chart"></div>

    <div class="footer">
      Powered by R + Plumber + Supabase | Data updates every minute | 7 coins tracked | v4.1
    </div>
  </div>

  <script>
    let currentSymbol = "BTC";
    let currentRange = "24h";
    let currentCurrency = "USD";

    function formatPrice(price, currency) {
      if (!price || isNaN(price)) return currency === "BTC" ? "-- BTC" : "$--";
      if (currency === "BTC") {
        // Format BTC prices with appropriate precision
        if (price >= 1) {
          return price.toFixed(4) + " BTC";
        } else if (price >= 0.0001) {
          return price.toFixed(6) + " BTC";
        }
        return price.toFixed(8) + " BTC";
      }
      // USD formatting
      if (price >= 1) {
        return "$" + price.toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2});
      }
      return "$" + price.toFixed(6);
    }

    function updateDashboard() {
      fetch("/dashboard?symbol=" + currentSymbol + "&range=" + currentRange + "&currency=" + currentCurrency)
        .then(r => r.json())
        .then(data => {
          // Extract values (handle R array serialization)
          const current = Array.isArray(data.current) ? data.current[0] : data.current;
          const high = Array.isArray(data.high) ? data.high[0] : data.high;
          const low = Array.isArray(data.low) ? data.low[0] : data.low;
          const mean = Array.isArray(data.mean) ? data.mean[0] : data.mean;
          const percentile = Array.isArray(data.percentile) ? data.percentile[0] : data.percentile;
          const lowerHalfMean = Array.isArray(data.lower_half_mean) ? data.lower_half_mean[0] : data.lower_half_mean;
          const dataPoints = Array.isArray(data.data_points) ? data.data_points[0] : data.data_points;
          const timestamp = Array.isArray(data.timestamp) ? data.timestamp[0] : data.timestamp;

          // Update price display
          const priceEl = document.getElementById("current-price");
          priceEl.textContent = formatPrice(current, currentCurrency);
          priceEl.style.color = current >= mean ? "#10b981" : "#ef4444";

          // Update stats
          document.getElementById("data-points").textContent = dataPoints || "--";
          document.getElementById("high-price").textContent = formatPrice(high, currentCurrency);
          document.getElementById("low-price").textContent = formatPrice(low, currentCurrency);
          document.getElementById("mean-price").textContent = formatPrice(mean, currentCurrency);
          document.getElementById("percentile").textContent = percentile != null ? percentile + "%" : "--";

          // Period change with color
          const periodChange = Array.isArray(data.period_change_pct) ? data.period_change_pct[0] : data.period_change_pct;
          const changeEl = document.getElementById("period-change");
          if (periodChange != null && !isNaN(periodChange)) {
            const sign = periodChange >= 0 ? "+" : "";
            changeEl.textContent = sign + periodChange.toFixed(2) + "%";
            changeEl.style.color = periodChange >= 0 ? "#10b981" : "#ef4444";
          } else {
            changeEl.textContent = "--";
            changeEl.style.color = "#f1f5f9";
          }

          document.getElementById("last-update").textContent = "Last update: " + (timestamp || "--");

          // Dip warning
          const warningEl = document.getElementById("dip-warning");
          warningEl.classList.toggle("show", current && lowerHalfMean && current < lowerHalfMean);

          // Update chart - history is array of {timestamp, price} objects
          const history = data.history;
          if (history && Array.isArray(history) && history.length > 0) {
            const timestamps = history.map(h => h.timestamp);
            const prices = history.map(h => h.price);

            // Calculate Y-axis range: 5% below min to slightly above max
            const minPrice = Math.min(...prices);
            const maxPrice = Math.max(...prices);
            const yMin = minPrice * 0.95; // 5% below minimum
            const yMax = maxPrice * 1.02; // 2% above maximum for padding

            const trace = {
              x: timestamps,
              y: prices,
              type: "scatter",
              mode: "lines",
              line: { color: "#f59e0b", width: 2 },
              fill: "toself",
              fillcolor: "rgba(245, 158, 11, 0.1)"
            };

            const yAxisTitle = currentCurrency === "BTC" ? "Price (BTC)" : "Price (USD)";
            const tickPrefix = currentCurrency === "BTC" ? "" : "$";

            const layout = {
              paper_bgcolor: "#1e293b",
              plot_bgcolor: "#1e293b",
              font: { color: "#f1f5f9" },
              xaxis: { gridcolor: "#334155", title: "Time" },
              yaxis: { gridcolor: "#334155", title: yAxisTitle, tickprefix: tickPrefix, range: [yMin, yMax] },
              margin: { t: 20, r: 20, b: 50, l: 80 },
              height: 400
            };

            Plotly.newPlot("chart", [trace], layout, {responsive: true});
          }
        })
        .catch(err => console.error("Error fetching dashboard:", err));
    }

    function selectCoin(symbol) {
      currentSymbol = symbol;
      document.querySelectorAll(".coin-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.symbol === symbol);
      });
      updateDashboard();
    }

    function selectRange(range) {
      currentRange = range;
      document.querySelectorAll(".range-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.range === range);
      });
      updateDashboard();
    }

    document.querySelectorAll(".coin-btn").forEach(btn => {
      btn.addEventListener("click", () => selectCoin(btn.dataset.symbol));
    });

    document.querySelectorAll(".range-btn").forEach(btn => {
      btn.addEventListener("click", () => selectRange(btn.dataset.range));
    });

    function selectCurrency(currency) {
      currentCurrency = currency;
      document.querySelectorAll(".currency-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.currency === currency);
      });
      updateDashboard();
    }

    document.querySelectorAll(".currency-btn").forEach(btn => {
      btn.addEventListener("click", () => selectCurrency(btn.dataset.currency));
    });

    let countdown = 60;
    function updateCountdown() {
      countdown--;
      document.getElementById("countdown").textContent = countdown;
      if (countdown <= 0) {
        updateDashboard();
        countdown = 60;
      }
    }

    // Initial load
    updateDashboard();
    setInterval(updateCountdown, 1000);
  </script>
</body>
</html>
'
  html
}
