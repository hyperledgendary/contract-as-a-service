FROM node:12.15-alpine

WORKDIR /usr/src/app

# Copy package.json first to check if an npm install is needed
COPY package.json /usr/src/app
RUN npm install --production

# Bundle app source
COPY . /usr/src/app

ENV PORT 9999
EXPOSE 9999

CMD ["npm", "run", "start:server"]
