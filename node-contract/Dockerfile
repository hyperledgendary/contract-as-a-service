#
# SPDX-License-Identifier: Apache-2.0
#
FROM node:12.15

WORKDIR /usr/src/app

# Copy node.js source and build, changing owner as well
COPY --chown=node:node . /usr/src/app
RUN npm ci --only=production

# Bundle app source

# Setup tini to work better handle signals
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

COPY docker/docker-entrypoint.sh /usr/src/app/docker-entrypoint.sh

ENV PORT 9999
EXPOSE 9999
ENV NODE_ENV=production


USER node
ENTRYPOINT [ "/tini", "--", "/usr/src/app/docker-entrypoint.sh" ]
