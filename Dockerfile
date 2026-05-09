# Dockerfile avec corrections complètes
FROM php:8.3-fpm-alpine

# Installation des dépendances
RUN apk add --no-cache \
    nginx \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    unzip \
    git

# Installation des extensions PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    pdo_mysql \
    pdo_pgsql \
    zip \
    opcache \
    bcmath \
    exif

# Installation de Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copie des fichiers de l'application
COPY . .

# Correction des permissions avant installation
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Installation des dépendances avec gestion des plateformes
RUN composer install --no-interaction --optimize-autoloader --no-dev --ignore-platform-req=ext-pdo_pgsql

# Création de la configuration Nginx
RUN mkdir -p /etc/nginx/http.d/ && \
    echo 'server { \
    listen 80; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    add_header X-Frame-Options "SAMEORIGIN"; \
    add_header X-Content-Type-Options "nosniff"; \
    location / { \
        try_files $uri $uri/ /index.php?$query_string; \
    } \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name; \
        include fastcgi_params; \
    } \
    location ~ /\.(?!well-known).* { \
        deny all; \
    } \
}' > /etc/nginx/http.d/default.conf

# Script de démarrage
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo 'php-fpm -D' >> /docker-entrypoint.sh && \
    echo 'nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]