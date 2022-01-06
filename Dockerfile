# SPDX-License-Identifier: Apache-2.0
#
# Copyright (c) 2021 Patrick Dung

FROM docker.io/node:14-bullseye-slim

ARG LABEL_IMAGE_URL
ARG LABEL_IMAGE_SOURCE
LABEL org.opencontainers.image.url=${LABEL_IMAGE_URL}
LABEL org.opencontainers.image.source=${LABEL_IMAGE_SOURCE}

ARG REVISION_HASH
ARG ARCH="arm64"

# With Docker's buildx, TARGETARCH gives out amd64/arm64
ARG TARGETARCH

ENV DEBIAN_FRONTEND noninteractive
RUN set -eux && \
    apt-get -y update && \
    apt-get -y install --no-install-suggests --no-install-recommends \
    bash git sed make pkg-config python procps libjemalloc2 file coreutils && \
    apt-get -y upgrade && apt-get -y autoremove && apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    if [ -e /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 ] ; then ln -s /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 /usr/lib/libjemalloc.so.2 ; fi && \
    npm install -g npm@8.0.0 && \
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

# Node alpine image does not include ssh. This is a workaround for https://github.com/npm/cli/issues/2610.
# Install build static assets and clear caches.
RUN set -eux && \
    git config --global url."https://github.com/".insteadOf ssh://git@github.com/ && \
    git config --global url."https://".insteadOf ssh:// && \
    npm ci && \
    npm run build && \
    npm prune --production

# Setup the environment
ENV NODE_ENV production
ENV PORT 5000
EXPOSE 5000/tcp

# For x86_64
#ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
# For arm64
#ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Run the node process directly instead of using `npm run start`:
# SEE: https://github.com/nodejs/docker-node/blob/a2eb9f80b0fd224503ee2678867096c9e19a51c2/docs/BestPractices.md#cmd
CMD ["node", "dist/index.js"]
