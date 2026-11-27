# Palco Player v1.2.0 - servidor de arquivos estaticos
FROM nginx/nginx-unprivileged:1.30.6-alpine-slim@sha256:f597851ed3b6963fd5703225af4d31034bda960a5db20c5de51495ce0403e512
COPY deploy/default.conf /etc/nginx/conf.d/default.conf
COPY dist/docs/manual.html dist/docs/arquitetura.html /usr/share/nginx/html/docs/
COPY dist/index.html /usr/share/nginx/html/index.html
EXPOSE 8080
