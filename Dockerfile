FROM node:20-slim

# Install FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files and install
COPY package*.json ./
RUN npm ci --production || npm install --production

# Copy source
COPY . .

# Create directories for assets and cache
RUN mkdir -p /app/assets/cache /app/assets/dj /app/assets/scenes /app/logs

ENV NODE_ENV=production
ENV LOG_DIR=/app/logs
ENV ASSET_DIR=/app/assets

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=15s \
  CMD curl -f http://localhost:3100/health || exit 1

EXPOSE 3100

# Use a restart-friendly entry point
CMD ["node", "src/orchestrator.js"]