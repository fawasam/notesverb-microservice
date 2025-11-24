# Production-ready Dockerfile for auth-service
FROM node:18-alpine AS builder
WORKDIR /app

# Copy shared module
COPY shared ./shared
WORKDIR /app/shared
RUN npm ci

# Copy service
WORKDIR /app
COPY services/auth-service ./services/auth-service

# Install dependencies and build
WORKDIR /app/services/auth-service
RUN npm ci --legacy-peer-deps
RUN npx prisma generate
RUN npm run build

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

# Copy shared
COPY --from=builder /app/shared ./shared

# Copy built service
COPY --from=builder /app/services/auth-service/package*.json ./services/auth-service/
COPY --from=builder /app/services/auth-service/dist ./services/auth-service/dist
COPY --from=builder /app/services/auth-service/node_modules ./services/auth-service/node_modules
COPY --from=builder /app/services/auth-service/prisma ./services/auth-service/prisma

WORKDIR /app/services/auth-service
EXPOSE 3001
CMD ["node", "dist/index.js"]
