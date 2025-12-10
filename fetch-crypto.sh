#!/bin/bash
# Fetch crypto prices and store in Supabase
# Runs every minute via cron

SUPABASE_URL="https://kzltorgncwddsjiqbooh.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6bHRvcmduY3dkZHNqaXFib29oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2MzMyMDQsImV4cCI6MjA4MDIwOTIwNH0.RQGSeITtZXyZI-npBLyj0rZXWXjQ8mdqkrSO6VovBQE"

# CoinGecko IDs
COINS="bitcoin,ethereum,solana,chainlink,avalanche-2,polygon-ecosystem-token,near"

# Fetch all prices in one call
RESPONSE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=$COINS&vs_currencies=usd")

# Check if we got a valid response
if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q "error"; then
  exit 1
fi

# Parse JSON with jq and insert each coin
declare -A SYMBOL_MAP
SYMBOL_MAP=([bitcoin]="BTC" [ethereum]="ETH" [solana]="SOL" [chainlink]="LINK" [avalanche-2]="AVAX" [polygon-ecosystem-token]="POL" [near]="NEAR")

for coin in bitcoin ethereum solana chainlink avalanche-2 polygon-ecosystem-token near; do
  PRICE=$(echo "$RESPONSE" | jq -r ".[\"$coin\"].usd // empty")
  SYMBOL=${SYMBOL_MAP[$coin]}

  if [ -n "$PRICE" ] && [ "$PRICE" != "null" ]; then
    curl -s -X POST "$SUPABASE_URL/rest/v1/crypto_prices" \
      -H "apikey: $SUPABASE_KEY" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=minimal" \
      -d "{\"symbol\": \"$SYMBOL\", \"price_usd\": $PRICE}"
  fi
done
