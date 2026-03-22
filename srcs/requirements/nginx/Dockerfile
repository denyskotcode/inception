FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl \
    && mkdir -p /var/www/html

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/dkot.42.fr.crt /etc/nginx/ssl/dkot.42.fr.crt
COPY conf/dkot.42.fr.key /etc/nginx/ssl/dkot.42.fr.key

RUN chmod 600 /etc/nginx/ssl/dkot.42.fr.key

CMD ["nginx", "-g", "daemon off;"]