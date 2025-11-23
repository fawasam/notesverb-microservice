# Production-ready Dockerfile for user-service
FROM node:18-alpine AS builder
WORKDIR /app

# Copy shared module
COPY shared ./shared
WORKDIR /app/shared
RUN npm ci --omit=dev

# Copy service
WORKDIR /app
COPY services/user-service ./services/user-service

# Install dependencies and build
WORKDIR /app/services/user-service
RUN npm ci
RUN npx prisma generate
RUN npm run build

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

# Copy shared
COPY --from=builder /app/shared ./shared

# Copy built service
COPY --from=builder /app/services/user-service/package*.json ./services/user-service/
COPY --from=builder /app/services/user-service/dist ./services/user-service/dist
COPY --from=builder /app/services/user-service/node_modules ./services/user-service/node_modules
COPY --from=builder /app/services/user-service/prisma ./services/user-service/prisma

WORKDIR /app/services/user-service
EXPOSE 3002
CMD ["node", "dist/index.js"]
