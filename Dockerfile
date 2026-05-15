# Dockerfile Laravel + Nginx + CSS
FROM php:8.3-fpm-alpine

# Dépendances système
RUN apk add --no-cache \
    nginx \
    curl \
    git \
    unzip \
    nodejs \
    npm \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev

# Extensions PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd zip opcache bcmath exif

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Dossier du projet
WORKDIR /var/www/html

# Copier le projet
COPY . .

# Installer Laravel
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Installer Node.js dependencies
RUN npm install

# Compiler CSS/JS
RUN npm run build

# Permissions Laravel
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 775 storage bootstrap/cache

# Générer la clé Laravel
RUN php artisan key:generate --force

# Configuration Nginx
RUN rm -f /etc/nginx/http.d/default.conf

RUN printf '%s\n' \
'server {' \
'    listen 80;' \
'    server_name _;' \
'    root /var/www/html/public;' \
'    index index.php index.html;' \
'' \
'    location / {' \
'        try_files $uri $uri/ /index.php?$query_string;' \
'    }' \
'' \
'    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg)$ {' \
'        try_files $uri =404;' \
'        expires max;' \
'        access_log off;' \
'    }' \
'' \
'    location ~ \.php$ {' \
'        fastcgi_pass 127.0.0.1:9000;' \
'        fastcgi_index index.php;' \
'        include fastcgi_params;' \
'        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' \
'    }' \
'' \
'    location ~ /\.(?!well-known).* {' \
'        deny all;' \
'    }' \
'}' \
> /etc/nginx/http.d/default.conf

# Script de démarrage
RUN printf '%s\n' \
'#!/bin/sh' \
'php-fpm -D' \
'nginx -g "daemon off;"' \
> /start.sh && chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]