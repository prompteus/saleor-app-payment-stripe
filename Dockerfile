FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache jq
WORKDIR /app

# Get PNPM version from package.json
COPY package.json pnpm-lock.yaml ./
RUN PNPM_VERSION=$(cat package.json | jq '.engines.pnpm' | sed -E 's/[^0-9.]//g') \
    && yarn global add pnpm@$PNPM_VERSION
RUN pnpm i --frozen-lockfile --prefer-offline


FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN apk add --no-cache jq
COPY /package.json pnpm-lock.yaml ./
RUN PNPM_VERSION=$(cat package.json | jq '.engines.pnpm' | sed -E 's/[^0-9.]//g') \
    && yarn global add pnpm@$PNPM_VERSION \
    && echo "PNPM_VERSION: $PNPM_VERSION"

ARG SECRET_KEY
ENV SECRET_KEY=${SECRET_KEY}
ARG APP_DEBUG
ENV APP_DEBUG=${APP_DEBUG}

RUN pnpm build


FROM base AS runner
WORKDIR /app
COPY . .

COPY --from=deps /app/node_modules ./node_modules

RUN apk add --no-cache jq
COPY /package.json pnpm-lock.yaml ./
RUN PNPM_VERSION=$(cat package.json | jq '.engines.pnpm' | sed -E 's/[^0-9.]//g') \
    && yarn global add pnpm@$PNPM_VERSION \
    && echo "PNPM_VERSION: $PNPM_VERSION"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next

USER nextjs

CMD ["pnpm", "start"]
