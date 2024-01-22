FROM node:alpine AS build

WORKDIR /app

COPY ./primal-web-app ./

RUN npm cache clean --force && \
    npm ci --foreground-scripts && \
    npm run build && \
    rm -rf /root/.npm

FROM nginx:alpine3.18 AS final

WORKDIR /usr/share/nginx/html
COPY --from=build /app/dist ./

ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod a+x /usr/local/bin/docker_entrypoint.sh
