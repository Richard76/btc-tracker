# BTC Price Tracker API
# R + Plumber + Plotly

library(plumber)
library(jsonlite)

# In-memory price storage (resets on restart)
price_history <- data.frame(
  timestamp = as.POSIXct(character()),
  price = numeric(),
  stringsAsFactors = FALSE
)

# Fetch current BTC price from CoinGecko
fetch_btc_price <- function() {
  tryCatch({
    url <- "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
    response <- readLines(url, warn = FALSE)
    data <- fromJSON(response)
    return(data$bitcoin$usd)
  }, error = function(e) {
    return(NA)
  })
}

# Update price history
update_price <- function() {
  price <- fetch_btc_price()
  if (!is.na(price)) {
    new_row <- data.frame(
      timestamp = Sys.time(),
      price = price,
      stringsAsFactors = FALSE
    )
    price_history <<- rbind(price_history, new_row)
    # Keep only last 1440 points (24 hours at 1 min intervals)
    if (nrow(price_history) > 1440) {
      price_history <<- tail(price_history, 1440)
    }
  }
  return(price)
}

#* @apiTitle BTC Price Tracker
#* @apiDescription Real-time Bitcoin price tracking with charts

#* Health check
#* @get /health
function() {
  list(
    status = "ok",
    service = "BTC Price Tracker",
    version = "1.0.0",
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
    data_points = nrow(price_history)
  )
}

#* Get current BTC price
#* @get /price
function() {
  price <- update_price()
  list(
    symbol = "BTC",
    price_usd = price,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
    source = "CoinGecko"
  )
}

#* Get price history
#* @get /history
function() {
  if (nrow(price_history) == 0) {
    update_price()
  }
  list(
    symbol = "BTC",
    data_points = nrow(price_history),
    history = price_history
  )
}

#* Serve the dashboard HTML
#* @get /
#* @serializer html
function() {
  # Update price on page load
  current_price <- update_price()

  html <- sprintf('
<!DOCTYPE html>
<html>
<head>
  <title>BTC Price Tracker</title>
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
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 15px;
      margin: 20px 0;
    }
    .stat-card {
      background: #1e293b;
      padding: 15px;
      border-radius: 8px;
      text-align: center;
    }
    .stat-label { color: #64748b; font-size: 0.8rem; }
    .stat-value { font-size: 1.2rem; font-weight: bold; margin-top: 5px; }
    .footer {
      text-align: center;
      margin-top: 30px;
      color: #64748b;
      font-size: 0.8rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Bitcoin Price Tracker</h1>
    <div class="price-display" id="current-price">$%s</div>
    <div class="timestamp" id="last-update">Last update: Loading...</div>

    <div class="stats">
      <div class="stat-card">
        <div class="stat-label">Data Points</div>
        <div class="stat-value" id="data-points">0</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">24h High</div>
        <div class="stat-value" id="high-price">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">24h Low</div>
        <div class="stat-value" id="low-price">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Auto-refresh</div>
        <div class="stat-value">60s</div>
      </div>
    </div>

    <div id="chart"></div>

    <div class="footer">
      Powered by R + Plumber | Data from CoinGecko | Auto-updates every minute
    </div>
  </div>

  <script>
    function formatPrice(price) {
      return "$" + price.toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2});
    }

    function updateChart() {
      fetch("/history")
        .then(r => r.json())
        .then(data => {
          const history = data.history;
          if (!history || history.timestamp.length === 0) return;

          const timestamps = history.timestamp;
          const prices = history.price;

          // Update stats
          document.getElementById("data-points").textContent = data.data_points;
          if (prices.length > 0) {
            document.getElementById("high-price").textContent = formatPrice(Math.max(...prices));
            document.getElementById("low-price").textContent = formatPrice(Math.min(...prices));
          }

          // Plot chart
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
            xaxis: {
              gridcolor: "#334155",
              title: "Time"
            },
            yaxis: {
              gridcolor: "#334155",
              title: "Price (USD)",
              tickprefix: "$"
            },
            margin: { t: 20, r: 20, b: 50, l: 70 }
          };

          Plotly.newPlot("chart", [trace], layout, {responsive: true});
        });
    }

    function updatePrice() {
      fetch("/price")
        .then(r => r.json())
        .then(data => {
          document.getElementById("current-price").textContent = formatPrice(data.price_usd);
          document.getElementById("last-update").textContent = "Last update: " + data.timestamp;
          updateChart();
        });
    }

    // Initial load
    updatePrice();

    // Auto-refresh every 60 seconds
    setInterval(updatePrice, 60000);
  </script>
</body>
</html>
', ifelse(is.na(current_price), "Loading...", format(current_price, big.mark = ",", nsmall = 2)))

  html
}
