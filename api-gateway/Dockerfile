FROM node:18-alpine AS builder
WORKDIR /app

# --- SHARED dependency install ---
COPY shared/package*.json ./shared/
RUN cd shared && npm ci

# now copy shared source
COPY shared ./shared


# --- GATEWAY dependency install ---
COPY api-gateway/package*.json ./api-gateway/
RUN cd api-gateway && npm ci --legacy-peer-deps

# now copy gateway source
COPY api-gateway ./api-gateway

# Build from api-gateway directory to ensure correct output structure
WORKDIR /app/api-gateway
RUN npm run build
WORKDIR /app


FROM node:18-alpine AS runner
WORKDIR /app

COPY --from=builder /app/shared ./shared

COPY --from=builder /app/api-gateway/package*.json ./api-gateway/
COPY --from=builder /app/api-gateway/dist ./api-gateway/dist
COPY --from=builder /app/api-gateway/node_modules ./api-gateway/node_modules

WORKDIR /app/api-gateway
EXPOSE 3000
CMD ["node", "dist/api-gateway/src/index.js"]
