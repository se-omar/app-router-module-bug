FROM node:22.8.0-alpine AS base

# Build dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
ENV NODE_ENV production

COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund --loglevel=error

# Build Application
FROM base AS builder

ENV NEXT_PUBLIC_APP_ENV $APP_ENV
ENV NODE_ENV production

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Need Typescript and ESLint installed during build to validate types
RUN npm install typescript eslint sharp

RUN npm run build

# Prepare Server
FROM base AS runner
WORKDIR /app

# Needed for run time image optimizations
RUN npm install sharp

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

RUN cd .next && find . -name "*.map" -type f -delete

USER nextjs

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
