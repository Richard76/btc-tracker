# BTC Price Tracker - R/Plumber API
FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    zlib1g-dev \
    libsodium-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org/')"

WORKDIR /app
COPY plumber.R /app/plumber.R

EXPOSE 10000

# Use shell form to properly expand PORT variable
CMD R -e "port <- as.numeric(Sys.getenv('PORT', '10000')); cat('Starting Plumber on port:', port, '\n'); plumber::plumb('plumber.R')\$run(host='0.0.0.0', port=port)"
