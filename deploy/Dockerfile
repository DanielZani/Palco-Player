# Palco Player v1.2.0 - servidor de arquivos estaticos
FROM nginxinc/nginx-unprivileged:stable-alpine
COPY deploy/default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
