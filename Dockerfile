FROM php:8.3-fpm-alpine

RUN apk add --no-cache nginx curl libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev unzip git nodejs npm

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip opcache bcmath exif

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# Installation des dépendances
RUN composer install --no-interaction --optimize-autoloader --no-dev \
    --ignore-platform-req=ext-pdo_mysql \
    --ignore-platform-req=ext-pdo_pgsql \
    --ignore-platform-req=ext-pdo_sqlite

# Installation des assets (si vous utilisez Vite ou npm)
RUN npm install && npm run build || true

# Créer les liens symboliques
RUN php artisan storage:link || true
RUN php artisan optimize:clear

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache \
    && chmod -R 755 /var/www/html/public

# Configuration Nginx optimisée
RUN mkdir -p /etc/nginx/http.d/ && \
    echo 'server { \
    listen 80; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    \
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
        try_files $uri =404; \
    } \
    \
    location / { \
        try_files $uri $uri/ /index.php?$query_string; \
    } \
    \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name; \
        include fastcgi_params; \
    } \
}' > /etc/nginx/http.d/default.conf

RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo 'php-fpm -D' >> /docker-entrypoint.sh && \
    echo 'nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]