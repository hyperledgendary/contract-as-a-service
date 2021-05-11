FROM node:12.15

WORKDIR /usr/src/app

# Copy package.json first to check if an npm install is needed
COPY package.json /usr/src/app
RUN npm install --production

# Bundle app source
COPY . /usr/src/app

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

COPY docker/docker-entrypoint.sh /usr/src/app/docker-entrypoint.sh

ENV PORT 9999
EXPOSE 9999

ENTRYPOINT [ "/tini", "--", "/usr/src/app/docker-entrypoint.sh" ]
