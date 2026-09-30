# Builds the Next.js standalone server for the EC2 runtime (linux/arm64, Alpine).
# The deploy script exports this stage and runs it with node:22-alpine.

FROM node:22-alpine AS build

RUN corepack enable && corepack prepare pnpm@10.11.0 --activate

WORKDIR /src

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build \
  && mkdir -p .next/standalone/.next \
  && cp -a public .next/standalone/public \
  && cp -a .next/static .next/standalone/.next/static

FROM scratch AS artifact

COPY --from=build /src/.next/standalone /
