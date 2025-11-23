# Production-ready Dockerfile for notes-service
FROM node:18-alpine AS builder
WORKDIR /app

# Copy shared module
COPY shared ./shared
WORKDIR /app/shared
RUN npm ci --omit=dev

# Copy service
WORKDIR /app
COPY services/notes-service ./services/notes-service

# Install dependencies and build
WORKDIR /app/services/notes-service
RUN npm ci
RUN npx prisma generate
RUN npm run build

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

# Copy shared
COPY --from=builder /app/shared ./shared

# Copy built service
COPY --from=builder /app/services/notes-service/package*.json ./services/notes-service/
COPY --from=builder /app/services/notes-service/dist ./services/notes-service/dist
COPY --from=builder /app/services/notes-service/node_modules ./services/notes-service/node_modules
COPY --from=builder /app/services/notes-service/prisma ./services/notes-service/prisma

WORKDIR /app/services/notes-service
EXPOSE 3003
CMD ["node", "dist/index.js"]
