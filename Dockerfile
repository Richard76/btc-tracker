# BTC Price Tracker - Dockerfile
FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    zlib1g-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org/')"

# Create app directory
WORKDIR /app

# Copy the API file
COPY plumber.R /app/plumber.R

# Expose port
EXPOSE 10000

# Run the API
CMD ["R", "-e", "plumber::plumb('plumber.R')$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"]
