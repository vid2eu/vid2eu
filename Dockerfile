# syntax=docker/dockerfile:1
#
# The migrate image: applies packages/db/drizzle to the database, then exits.
# The service images are built in their own repos (vid2eu-api, vid2eu-storage,
# vid2eu-transcoder, vid2eu-web), which take packages/db from this repo as a submodule.

ARG NODE_VERSION=26

FROM node:${NODE_VERSION}-slim AS migrate
WORKDIR /app
ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false
COPY package.json package-lock.json ./
COPY packages/db/package.json packages/db/
RUN npm ci -w @vid2eu/db --include=dev && npm cache clean --force
COPY packages/db packages/db
WORKDIR /app/packages/db
USER node
CMD ["npx", "drizzle-kit", "migrate"]
