# syntax=docker.io/docker/dockerfile:1

FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

ARG NEXT_PUBLIC_SITE_NAME=${NEXT_PUBLIC_SITE_NAME}
ARG NEXT_PUBLIC_SITE_DESC=${NEXT_PUBLIC_SITE_DESC}
ARG NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
ARG NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ARG NEXT_PUBLIC_WS_API_URL=${NEXT_PUBLIC_WS_API_URL}
ARG NEXT_PUBLIC_WS_HOST=${NEXT_PUBLIC_WS_HOST}
ARG NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ARG AUTH_GOOGLE_ID=${AUTH_GOOGLE_ID}
ARG AUTH_GOOGLE_SECRET=${AUTH_GOOGLE_SECRET}
ARG AUTH_SECRET=${AUTH_SECRET}

# 🔽 Set ENV (agar terbaca oleh build system Next.js)
ENV NEXT_PUBLIC_SITE_NAME=${NEXT_PUBLIC_SITE_NAME}
ENV NEXT_PUBLIC_SITE_DESC=${NEXT_PUBLIC_SITE_DESC}
ENV NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_WS_API_URL=${NEXT_PUBLIC_WS_API_URL}
ENV NEXT_PUBLIC_WS_HOST=${NEXT_PUBLIC_WS_HOST}
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ENV AUTH_GOOGLE_ID=${AUTH_GOOGLE_ID}
ENV AUTH_GOOGLE_SECRET=${AUTH_GOOGLE_SECRET}
ENV AUTH_SECRET=${AUTH_SECRET}

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* .npmrc* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

# Re-declare ARGs for builder stage
ARG NEXT_PUBLIC_SITE_NAME
ARG NEXT_PUBLIC_SITE_DESC
ARG NEXT_PUBLIC_SITE_URL
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_WS_API_URL
ARG NEXT_PUBLIC_WS_HOST
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG AUTH_GOOGLE_ID
ARG AUTH_GOOGLE_SECRET
ARG AUTH_SECRET

# Set ENV for build process
ENV NEXT_PUBLIC_SITE_NAME=${NEXT_PUBLIC_SITE_NAME}
ENV NEXT_PUBLIC_SITE_DESC=${NEXT_PUBLIC_SITE_DESC}
ENV NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_WS_API_URL=${NEXT_PUBLIC_WS_API_URL}
ENV NEXT_PUBLIC_WS_HOST=${NEXT_PUBLIC_WS_HOST}
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ENV AUTH_GOOGLE_ID=${AUTH_GOOGLE_ID}
ENV AUTH_GOOGLE_SECRET=${AUTH_GOOGLE_SECRET}
ENV AUTH_SECRET=${AUTH_SECRET}

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN echo $NEXT_PUBLIC_SITE_NAME
RUN echo $NEXT_PUBLIC_SITE_DESC
RUN echo $NEXT_PUBLIC_SITE_URL
RUN echo $NEXT_PUBLIC_API_URL
RUN echo $NEXT_PUBLIC_WS_API_URL
RUN echo $NEXT_PUBLIC_WS_HOST
RUN echo $NEXT_PUBLIC_SUPABASE_URL
RUN echo $NEXT_PUBLIC_SUPABASE_ANON_KEY
RUN echo $AUTH_GOOGLE_ID
RUN echo $AUTH_GOOGLE_SECRET
RUN echo $AUTH_SECRET

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED=1

RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3001
ENV PORT=3001
# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/config/next-config-js/output
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]