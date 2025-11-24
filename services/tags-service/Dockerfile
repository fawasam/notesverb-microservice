# Production-ready Dockerfile for tags-service
FROM node:18-alpine AS builder
WORKDIR /app

# Copy shared module
COPY shared ./shared
WORKDIR /app/shared
RUN npm ci

# Copy service
WORKDIR /app
COPY services/tags-service ./services/tags-service

# Install dependencies and build
WORKDIR /app/services/tags-service
RUN npm ci --legacy-peer-deps
RUN npx prisma generate
RUN npm run build

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

# Copy shared
COPY --from=builder /app/shared ./shared

# Copy built service
COPY --from=builder /app/services/tags-service/package*.json ./services/tags-service/
COPY --from=builder /app/services/tags-service/dist ./services/tags-service/dist
COPY --from=builder /app/services/tags-service/node_modules ./services/tags-service/node_modules
COPY --from=builder /app/services/tags-service/prisma ./services/tags-service/prisma

WORKDIR /app/services/tags-service
EXPOSE 3004
CMD ["node", "dist/index.js"]
