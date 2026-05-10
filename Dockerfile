# Dockerfile pour Laravel sans base de données - Version CSS fonctionnelle
FROM php:8.3-fpm-alpine

# Installation des dépendances minimales
RUN apk add --no-cache \
    nginx \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    unzip \
    git \
    nodejs \
    npm

# Installation des extensions PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    zip \
    opcache \
    bcmath \
    exif

# Installation de Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copie des fichiers de l'application
COPY . .

# Installation des dépendances PHP (sans base de données)
RUN composer install --no-interaction --optimize-autoloader --no-dev \
    --ignore-platform-req=ext-pdo_mysql \
    --ignore-platform-req=ext-pdo_pgsql \
    --ignore-platform-req=ext-pdo_sqlite

# Installation et compilation des assets CSS/JS
RUN npm install && npm run build || true

# Création du fichier .env
RUN echo "APP_NAME=Laravel" > .env && \
    echo "APP_ENV=production" >> .env && \
    echo "APP_DEBUG=false" >> .env && \
    echo "APP_URL=http://localhost" >> .env && \
    echo "" >> .env && \
    echo "LOG_CHANNEL=stack" >> .env && \
    echo "LOG_LEVEL=error" >> .env && \
    echo "" >> .env && \
    echo "SESSION_DRIVER=file" >> .env && \
    echo "SESSION_LIFETIME=120" >> .env && \
    echo "" >> .env && \
    echo "CACHE_STORE=file" >> .env && \
    echo "" >> .env && \
    echo "QUEUE_CONNECTION=sync" >> .env && \
    echo "" >> .env && \
    echo "ASSET_URL=" >> .env

# Optimisations Laravel
RUN php artisan storage:link || true
RUN php artisan optimize:clear
RUN php artisan view:cache
RUN php artisan config:cache
RUN php artisan route:cache

# Correction des permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache \
    && chmod -R 755 /var/www/html/public

# Configuration Nginx optimisée pour les CSS et assets statiques
RUN mkdir -p /etc/nginx/http.d/ && \
    echo 'server { \
    listen 80; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    \
    # Gestion des fichiers statiques (CSS, JS, images) \
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|map)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
        try_files $uri =404; \
        access_log off; \
        log_not_found off; \
    } \
    \
    # Gestion spécifique des fichiers CSS \
    location ~ \.css$ { \
        expires 1y; \
        add_header Content-Type text/css; \
        add_header Cache-Control "public, immutable"; \
        try_files $uri =404; \
    } \
    \
    # Gestion spécifique des fichiers JS \
    location ~ \.js$ { \
        expires 1y; \
        add_header Content-Type application/javascript; \
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
        fastcgi_param APP_ENV production; \
        fastcgi_param APP_DEBUG false; \
        include fastcgi_params; \
    } \
    \
    location ~ /\.(?!well-known).* { \
        deny all; \
    } \
}' > /etc/nginx/http.d/default.conf

# Script de démarrage avec vérification des assets
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Vérification des dossiers CSS' >> /docker-entrypoint.sh && \
    echo 'if [ ! -d "/var/www/html/public/css" ] && [ ! -d "/var/www/html/public/build" ]; then' >> /docker-entrypoint.sh && \
    echo '    echo "⚠️  Aucun dossier CSS trouvé. Création..."' >> /docker-entrypoint.sh && \
    echo '    mkdir -p /var/www/html/public/css' >> /docker-entrypoint.sh && \
    echo '    echo "/* CSS généré automatiquement */" > /var/www/html/public/css/app.css' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Afficher les dossiers d\'assets' >> /docker-entrypoint.sh && \
    echo 'echo "📁 Dossiers d\'assets disponibles :"' >> /docker-entrypoint.sh && \
    echo 'ls -la /var/www/html/public/ | grep -E "css|js|build|assets" || echo "   Aucun dossier d\'assets trouvé"' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Démarrer les services' >> /docker-entrypoint.sh && \
    echo 'php-fpm -D' >> /docker-entrypoint.sh && \
    echo 'nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Copie manuelle des assets si nécessaire
RUN if [ -d "resources/css" ]; then \
        mkdir -p public/css && cp -r resources/css/* public/css/ 2>/dev/null || true; \
    fi && \
    if [ -d "resources/js" ]; then \
        mkdir -p public/js && cp -r resources/js/* public/js/ 2>/dev/null || true; \
    fi && \
    if [ -d "resources/sass" ]; then \
        mkdir -p public/css && cp -r resources/sass/* public/css/ 2>/dev/null || true; \
    fi

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]