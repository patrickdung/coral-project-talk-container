# SPDX-License-Identifier: Apache-2.0
#
# Copyright (c) 2021 Patrick Dung

# as of 8.7.0, need to use bullseye to build
# openssl 3 on bookworm would have build problem
#FROM docker.io/node:18-bullseye-slim as build
FROM docker.io/node:20-bullseye-slim as build

ARG REVISION_HASH
ARG ARCH="arm64"

# With Docker's buildx, TARGETARCH gives out amd64/arm64
ARG TARGETARCH

ENV DEBIAN_FRONTEND noninteractive

# Not effective when npm is run
ENV NODE_OPTIONS="--max_old_space_size=8192 --openssl-legacy-provider --no-experimental-fetch"

RUN set -eux && \
    apt-get -y update && \
    apt-get -y install --no-install-suggests --no-install-recommends \
    bash git make pkg-config python3 gcc g++ coreutils sed && \
    apt-get -y upgrade && apt-get -y autoremove && apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@8.14.3 && \
    mkdir -p /usr/src/app && \
    mkdir -p dist/core/common/__generated__ && \
    echo "{\"revision\": \"${REVISION_HASH}\"}" > dist/core/common/__generated__/revision.json

WORKDIR /usr/src/app

# Bundle application source.
COPY . /usr/src/app

# Run all application code and dependancy setup as a non-root user:
# SEE: https://github.com/nodejs/docker-node/blob/a2eb9f80b0fd224503ee2678867096c9e19a51c2/docs/BestPractices.md#non-root-user
RUN set -eux && chown -R node /usr/src/app

USER node

ENV GENERATE_SOURCEMAP=false

# Node alpine image does not include ssh. This is a workaround for https://github.com/npm/cli/issues/2610.
# Install build static assets and clear caches.
# Initialize sub packages
# Generate schema types for common/ to use
# Build config, prune static assets
# Build common, prune static assets
# Build client, prune static assets
# Install, build server, prune static assets
  #mkdir -p /usr/include/linux && \
  #echo "#include <unistd.h>" > /usr/include/linux/unistd.h && \

RUN set -eux && \
  git config --global url."https://github.com/".insteadOf ssh://git@github.com/ && \
  git config --global url."https://".insteadOf ssh:// && \
  pnpm config set fetch-retries 5 && \
  pnpm config set fetch-retry-mintimeout 600000 && \
  pnpm config set fetch-retry-maxtimeout 1200000 && \
  pnpm config set fetch-timeout 1800000 && \
  cd config && npm ci && \
  cd ../common && npm ci && \
  cd ../client && \
  sed -i -E 's|--openssl-legacy-provider|--openssl-legacy-provider --max-old-space-size=12000|g' package.json && \
  npm ci && \
  cd ../server && \
  sed -i -E 's|--openssl-legacy-provider|--openssl-legacy-provider --max-old-space-size=12000|g' package.json && \
  npm ci && \
  cd .. && \
  cd server && \
  pnpm run generate && \
  cd .. && \
  cd config && \
  pnpm run build && \
  cd .. && \
  cd common && \
  pnpm run build && \
  cd .. && \
  cd client && \
  pnpm run build && \
  pnpm prune --production && \
  cd .. && \
  cd server && \
  pnpm run build && \
  pnpm prune --production && \
  cd ..

# Initialize sub packages
#RUN set -eux && \
#  cd config && npm ci && \
#  cd ../common && npm ci && \
#  cd ../client && npm ci && \
#  cd ../server && npm ci && \
#  cd ..

# Generate schema types for common/ to use
#RUN set -eux && \
#  cd server && \
#  npm run generate && \
#  cd ..

# Build config, prune static assets
#RUN set -eux && \
#  cd config && \
#  npm run build && \
#  cd ..

# Build common, prune static assets
#RUN set -eux && \
#  cd common && \
#  npm run build && \
#  cd ..

# Build client, prune static assets
#RUN set -eux && \
#  cd client && \
#  npm run build && \
#  npm prune --production && \
#  cd ..

# Install, build server, prune static assets
#RUN set -eux && \
#  cd server && \
#  npm run build && \
#  npm prune --production && \
#  cd ..

# ----------------

#FROM docker.io/node:18-bullseye-slim
FROM docker.io/node:20-bullseye-slim

ARG LABEL_IMAGE_URL
ARG LABEL_IMAGE_SOURCE
LABEL org.opencontainers.image.url=${LABEL_IMAGE_URL}
LABEL org.opencontainers.image.source=${LABEL_IMAGE_SOURCE}

ENV DEBIAN_FRONTEND noninteractive
RUN set -eux && \
    apt-get -y update && \
    apt-get -y install --no-install-suggests --no-install-recommends \
    tini bash python3 procps libjemalloc2 && \
    apt-get -y upgrade && apt-get -y autoremove && apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    if [ -e /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 ] ; then ln -s /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 /usr/lib/libjemalloc.so.2 ; fi && \
    npm install -g pnpm@8.14.3 && \
    mkdir -p /usr/src/app && \
    chown node:node /usr/src/app

COPY --from=build --chown=node:node /usr/src/app /usr/src/app

USER node
#WORKDIR /usr/src/app
WORKDIR /usr/src/app/server

# Setup the environment
ENV NODE_ENV production
ENV PORT 5000
EXPOSE 5000/tcp

# For x86_64
#ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
# For arm64
#ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

ENTRYPOINT ["tini", "--"]

# Run the node process directly instead of using `npm run start`:
# SEE: https://github.com/nodejs/docker-node/blob/a2eb9f80b0fd224503ee2678867096c9e19a51c2/docs/BestPractices.md#cmd
CMD ["node", "dist/index.js"]
