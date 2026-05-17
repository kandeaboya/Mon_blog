# --------------------------------------------------------
# 1. ÉTAPE DE COMPILATION DES ASSETS (Vite)
# --------------------------------------------------------
FROM node:20-alpine AS asset-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# --------------------------------------------------------
# 2. ÉTAPE D'ÉXÉCUTION (PHP + Nginx)
# --------------------------------------------------------
FROM php:8.3-fpm-alpine

# Dépendances système essentielles pour la production
RUN apk add --no-cache \
    nginx \
    curl \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev

# Extensions PHP nécessaires à Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd zip opcache bcmath exif

# Outils d'optimisation PHP pour la production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Installer Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copier le code source du projet
COPY . .

# Récupérer les assets CSS/JS compilés depuis la première étape (Vite)
COPY --from=asset-builder /app/public/build ./public/build

# Installer les dépendances PHP sans les outils de développement (No Dev)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Droits d'accès : www-data gère Laravel, mais Nginx (755) doit pouvoir lire /public
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 775 storage bootstrap/cache && \
    chmod -R 755 /var/www/html/public

# Nettoyer et configurer Nginx pour la production
RUN rm -f /etc/nginx/http.d/default.conf
RUN printf '%s\n' \
'server {' \
'    listen 80;' \
'    server_name _;' \
'    root /var/www/html/public;' \
'    index index.php index.html;' \
'' \
'    # Gestion des routes de Laravel' \
'    location / {' \
'        try_files $uri $uri/ /index.php?$query_string;' \
'    }' \
'' \
'    # Cache agressif pour les assets de production générés par Vite' \
'    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2)$ {' \
'        try_files $uri =404;' \
'        expires max;' \
'        access_log off;' \
'        add_header Cache-Control "public, no-transform";' \
'    }' \
'' \
'    # Traitement PHP' \
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

# Script d'allumage automatique du serveur (Sans le key:generate qui bloquait)
RUN printf '%s\n' \
'#!/bin/sh' \
'php artisan config:cache' \
'php artisan route:cache' \
'php artisan view:cache' \
'php-fpm -D' \
'nginx -g "daemon off;"' \
> /start.sh && chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]