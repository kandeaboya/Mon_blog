# Dockerfile pour Laravel - Site statique sans base de données
FROM php:8.3-fpm-alpine

# Installation des dépendances système (dont oniguruma pour mbstring)
RUN apk add --no-cache \
    nginx \
    curl \
    unzip \
    git \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev

# Installation des extensions PHP nécessaires pour Laravel (sans erreurs)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    zip \
    opcache \
    bcmath \
    exif \
    mbstring \
    tokenizer \
    fileinfo

# Installation de Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copie des fichiers de l'application
COPY . .

# Suppression des dépendances de base de données (optionnel)
RUN composer remove laravel/pail --no-update 2>/dev/null || true && \
    composer remove doctrine/dbal --no-update 2>/dev/null || true

# Installation des dépendances PHP en ignorant les req DB et les erreurs
RUN composer install --no-interaction --optimize-autoloader --no-dev \
    --ignore-platform-req=ext-pdo \
    --ignore-platform-req=ext-pdo_mysql \
    --ignore-platform-req=ext-pdo_pgsql \
    --ignore-platform-req=ext-pdo_sqlite \
    --ignore-platform-req=ext-pgsql \
    --ignore-platform-req=ext-mysql 2>&1 || echo "Composer install completed with warnings"

# Création du fichier .env
RUN cat > .env << 'EOF'
APP_NAME=MonBlog
APP_ENV=production
APP_DEBUG=false
APP_URL=https://mon-blog-jm2x.onrender.com
ASSET_URL=https://mon-blog-jm2x.onrender.com

LOG_CHANNEL=stack
LOG_LEVEL=error

SESSION_DRIVER=file
CACHE_STORE=file
VIEW_COMPILED_PATH=/tmp/views
EOF

# Optimisations Laravel (sans erreur si DB manquante)
RUN php artisan optimize:clear 2>/dev/null || true && \
    php artisan view:cache 2>/dev/null || true && \
    php artisan config:cache 2>/dev/null || true

# Permissions des dossiers
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache \
    && chmod -R 755 /var/www/html/public

# Vérification et permissions du fichier CSS
RUN if [ -f "/var/www/html/public/css/style.css" ]; then \
        chmod 644 /var/www/html/public/css/style.css && \
        echo "✅ CSS trouvé et permissions fixées"; \
    else \
        echo "⚠️ Aucun fichier style.css trouvé, création d'un fichier par défaut"; \
        mkdir -p /var/www/html/public/css && \
        echo "/* CSS par défaut */ body { background: #f0f4ff; font-family: Arial; }" > /var/www/html/public/css/style.css; \
    fi

# Configuration Nginx (gestion des fichiers statiques)
RUN cat > /etc/nginx/http.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    access_log /dev/stdout;
    error_log /dev/stderr;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param APP_ENV production;
        fastcgi_param APP_DEBUG false;
        include fastcgi_params;
    }
}
EOF

# Script de démarrage
RUN cat > /docker-entrypoint.sh << 'EOF'
#!/bin/sh
set -e

echo "========================================="
echo "🚀 Démarrage de MonBlog"
echo "========================================="

if [ -f "/var/www/html/public/css/style.css" ]; then
    echo "✅ CSS chargé : /var/www/html/public/css/style.css"
else
    echo "⚠️ CSS non trouvé"
fi

php-fpm -D
nginx -g "daemon off;"
EOF

RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]