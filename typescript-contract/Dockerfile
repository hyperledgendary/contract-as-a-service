#
# SPDX-License-Identifier: Apache-2.0
#
FROM node:12.15 AS builder

WORKDIR /usr/src/app

# Copy node.js source and build, changing owner as well
COPY --chown=node:node . /usr/src/app
RUN npm ci && npm run build

# Bundle app source


FROM node:12.15 AS production

# Setup tini to work better handle signals
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini


WORKDIR /usr/src/app
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist
COPY --chown=node:node --from=builder /usr/src/app/package*.json ./
COPY --chown=node:node docker/docker-entrypoint.sh /usr/src/app/docker-entrypoint.sh
RUN npm ci --only=production

ENV PORT 9999
EXPOSE 9999
ENV NODE_ENV=production

USER node
ENTRYPOINT [ "/tini", "--", "/usr/src/app/docker-entrypoint.sh" ]
