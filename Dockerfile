# Dockerfile pour Laravel - Site statique sans base de données
FROM php:8.3-fpm-alpine

# Installation des dépendances minimales (pas de DB)
RUN apk add --no-cache \
    nginx \
    curl \
    unzip \
    git

# Installation des extensions PHP (uniquement nécessaires)
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    bcmath \
    exif

# Installation de Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copie des fichiers de l'application
COPY . .

# Suppression de toutes les dépendances de base de données
RUN composer remove laravel/pail --no-update 2>/dev/null || true && \
    composer remove doctrine/dbal --no-update 2>/dev/null || true

# Installation des dépendances PHP en ignorant tout ce qui concerne les DB
RUN composer install --no-interaction --optimize-autoloader --no-dev \
    --ignore-platform-req=ext-pdo \
    --ignore-platform-req=ext-pdo_mysql \
    --ignore-platform-req=ext-pdo_pgsql \
    --ignore-platform-req=ext-pdo_sqlite \
    --ignore-platform-req=ext-pgsql \
    --ignore-platform-req=ext-mysql

# Création du fichier .env SANS base de données
RUN echo "APP_NAME=MonBlog" > .env && \
    echo "APP_ENV=production" >> .env && \
    echo "APP_DEBUG=false" >> .env && \
    echo "APP_URL=https://mon-blog-jm2x.onrender.com" >> .env && \
    echo "ASSET_URL=https://mon-blog-jm2x.onrender.com" >> .env && \
    echo "" >> .env && \
    echo "LOG_CHANNEL=stack" >> .env && \
    echo "LOG_LEVEL=error" >> .env && \
    echo "" >> .env && \
    echo "SESSION_DRIVER=file" >> .env && \
    echo "SESSION_LIFETIME=120" >> .env && \
    echo "" >> .env && \
    echo "CACHE_STORE=file" >> .env && \
    echo "VIEW_COMPILED_PATH=/tmp/views" >> .env

# Optimisations Laravel sans DB
RUN php artisan optimize:clear || true && \
    php artisan view:cache || true && \
    php artisan config:cache || true && \
    php artisan route:cache || true

# Configuration des permissions CORRECTE pour CSS
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache \
    && chmod -R 755 /var/www/html/public

# Forcer les bonnes permissions pour le CSS
RUN if [ -f "/var/www/html/public/css/style.css" ]; then \
        chmod 644 /var/www/html/public/css/style.css && \
        echo "✅ CSS permissions fixées"; \
    else \
        echo "⚠️ Pas de fichier style.css trouvé"; \
        mkdir -p /var/www/html/public/css && \
        echo "/* CSS par défaut */ body { background: #f0f4ff; }" > /var/www/html/public/css/style.css; \
    fi

# Configuration Nginx ultra simple
RUN cat > /etc/nginx/http.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    # Logs
    access_log /dev/stdout;
    error_log /dev/stderr;

    # Fichiers statiques (CSS, JS, images)
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Redirection principale
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param APP_ENV production;
        fastcgi_param APP_DEBUG false;
        include fastcgi_params;
    }
}
EOF

# Script de démarrage avec vérification CSS
RUN cat > /docker-entrypoint.sh << 'EOF'
#!/bin/sh
set -e

echo "========================================="
echo "🚀 Démarrage de MonBlog"
echo "========================================="

# Vérification CSS
echo ""
echo "📁 Vérification des fichiers CSS :"
if [ -f "/var/www/html/public/css/style.css" ]; then
    echo "✅ CSS trouvé : /var/www/html/public/css/style.css"
    echo "📄 Taille : $(wc -c < /var/www/html/public/css/style.css) bytes"
else
    echo "❌ CSS non trouvé !"
    echo "Contenu de public/ :"
    ls -la /var/www/html/public/
fi

# Vérification des views
echo ""
echo "📁 Vérification des layouts :"
if [ -f "/var/www/html/resources/views/layouts/master.blade.php" ]; then
    echo "✅ master.blade.php trouvé"
    grep -q "css/style.css" /var/www/html/resources/views/layouts/master.blade.php && \
        echo "✅ Lien CSS présent dans master.blade.php" || \
        echo "⚠️ Lien CSS absent de master.blade.php"
fi

echo ""
echo "========================================="
echo "✅ Démarrage des services"
echo "========================================="

php-fpm -D
nginx -g "daemon off;"
EOF

RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]