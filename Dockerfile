FROM oven/bun:1.3-alpine

WORKDIR /app

# Install git (needed for project scanning)
RUN apk add --no-cache git

# Copy API source
COPY api/ ./api/

# Data volume for persistent state (api key + swipe records)
VOLUME ["/data"]

# Projects directory (mounted from host)
VOLUME ["/projects"]

EXPOSE 4242

CMD ["bun", "run", "api/server.ts"]
