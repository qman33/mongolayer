FROM node:14.19.0

COPY package.json /app/package.json
RUN cd /app && npm install

WORKDIR /app