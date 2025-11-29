# Production-ready Dockerfile for api-gateway
FROM node:18-alpine AS builder
WORKDIR /app

# Copy shared module
COPY shared ./shared
WORKDIR /app/shared
RUN npm ci

# Copy gateway
WORKDIR /app
COPY api-gateway ./api-gateway

# Install dependencies and build
WORKDIR /app/api-gateway
RUN npm ci --legacy-peer-deps
RUN npm run build

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

# Copy shared
COPY --from=builder /app/shared ./shared

# Copy built gateway
COPY --from=builder /app/api-gateway/package*.json ./api-gateway/
COPY --from=builder /app/api-gateway/dist ./api-gateway/dist
COPY --from=builder /app/api-gateway/node_modules ./api-gateway/node_modules

WORKDIR /app/api-gateway
EXPOSE 3000
CMD ["node", "dist/index.js"]
