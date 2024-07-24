FROM node:20.9.0-alpine3.18 as node

RUN apk add bash git php-cli

COPY . /usr/src/myapp
WORKDIR /usr/src/myapp
CMD [ "php", "./app" ]
