# Image PHP officielle
FROM php:8.2-apache

# Installer les extensions nécessaires
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    git \
    curl

# Activer extensions PHP
RUN docker-php-ext-install pdo pdo_mysql gd

# Activer mod_rewrite (important pour Laravel)
RUN a2enmod rewrite

# Définir le dossier de travail
WORKDIR /var/www/html

# Copier le projet dans le conteneur
COPY . .

# Installer Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Installer les dépendances Laravel
RUN composer install

# Permissions Laravel
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Port Apache
EXPOSE 80