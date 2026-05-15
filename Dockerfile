# Dockerfile Laravel + CSS/Vite fonctionnel sur Render
FROM php:8.3-fpm-alpine

# Installation des dépendances système
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

# Installation des extensions PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install \
    gd \
    zip \
    opcache \
    bcmath \
    exif

# Installation de Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Dossier de travail
WORKDIR /var/www/html

# Copie du projet
COPY . .

# Installation des dépendances Laravel
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Installation et compilation des assets CSS/JS
RUN npm install
RUN npm run build

# Permissions Laravel
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 775 storage bootstrap/cache

# Génération de la clé Laravel
RUN php artisan key:generate --force

# Configuration Nginx
RUN rm -f /etc/nginx/http.d/default.conf && \
echo 'server {
    listen 80;
    server_name _;

    root /var/www/html/public;
    index index.php index.html;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg)$ {
        try_files $uri =404;
        expires max;
        access_log off;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}' > /etc/nginx/http.d/default.conf

# Script de démarrage
RUN echo "#!/bin/sh" > /start.sh && \
    echo "php-fpm -D" >> /start.sh && \
    echo "nginx -g 'daemon off;'" >> /start.sh && \
    chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]