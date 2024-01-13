# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2020 Vox Media, Inc
# Copyright (c) 2021 Patrick Dung

FROM docker.io/node:18-alpine

# seems not effective when npm is run
# try to set it again after USER is set
ENV NODE_OPTIONS="--max-old-space-size=8192 --openssl-legacy-provider --no-experimental-fetch"
ENV GENERATE_SOURCEMAP=false

# Install build dependancies.
# Create app directory.

# add linux-headers for linux/unistd.h not found in alpine

RUN apk --no-cache --update add g++ make git python3 linux-headers sed \
  && rm -rf /var/cache/apk/* && \
  npm install -g npm@8.0.0 && \
  mkdir -p /usr/src/app

WORKDIR /usr/src/app

# Bundle application source.
COPY . /usr/src/app

# Store the current git revision.
ARG REVISION_HASH
RUN mkdir -p dist/core/common/__generated__ && \
  echo "{\"revision\": \"${REVISION_HASH}\"}" > dist/core/common/__generated__/revision.json

# Run all application code and dependancy setup as a non-root user:
# SEE: https://github.com/nodejs/docker-node/blob/a2eb9f80b0fd224503ee2678867096c9e19a51c2/docs/BestPractices.md#non-root-user
RUN chown -R node /usr/src/app
USER node

# in 8.7.0 the package.json seems to override the NODE_OPTIONS
ENV NODE_OPTIONS="--max-old-space-size=15000 --openssl-legacy-provider --no-experimental-fetch"
ENV GENERATE_SOURCEMAP=false

# Node alpine image does not include ssh. This is a workaround for https://github.com/npm/cli/issues/2610.
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
  npm config set fetch-retries 5 && \
  npm config set fetch-retry-mintimeout 600000 && \
  npm config set fetch-retry-maxtimeout 1200000 && \
  npm config set fetch-timeout 1800000 && \
  cd config && npm ci && \
  cd ../common && npm ci && \
  cd ../client && npm ci && \
  cd ../server && npm ci && \
  cd .. && \
  cd server && \
  npm run generate && \
  cd .. && \
  cd config && \
  npm run build && \
  cd .. && \
  cd common && \
  npm run build && \
  cd .. && \
  cd client && \
  sed -i -E 's|--openssl-legacy-provider|--openssl-legacy-provider --max-old-space-size=12000|g' package.json && \
  npm run build && \
  npm prune --production && \
  cd .. && \
  cd server && \
  sed -i -E 's|--openssl-legacy-provider|--openssl-legacy-provider --max-old-space-size=12000|g' package.json && \
  npm run build && \
  npm prune --production && \
  cd ..

# Set working directory within server folder
WORKDIR /usr/src/app/server

# Setup the environment
ENV NODE_ENV production
ENV PORT 5000
EXPOSE 5000

# Run the node process directly instead of using `npm run start`:
# SEE: https://github.com/nodejs/docker-node/blob/a2eb9f80b0fd224503ee2678867096c9e19a51c2/docs/BestPractices.md#cmd
CMD ["node", "dist/index.js"]
