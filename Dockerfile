FROM php:8.2-apache

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libicu-dev \
    libzip-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libldap2-dev \
    libsodium-dev \
    libpq-dev \
    default-mysql-client \
    cron \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    intl \
    mbstring \
    mysqli \
    pdo_mysql \
    opcache \
    soap \
    zip \
    bcmath \
    sockets \
    sodium

# Enable Apache modules (keep event MPM, it works with rewrite)
RUN a2enmod rewrite headers expires

# PHP config
COPY php.ini /usr/local/etc/php/conf.d/suitecrm.ini

# Apache config
COPY apache.conf /etc/apache2/sites-available/000-default.conf

# Download SuiteCRM 7.15.2
RUN curl -L -o /tmp/suitecrm.zip \
    "https://github.com/SuiteCRM/SuiteCRM/archive/refs/tags/v7.15.2.zip" \
    && unzip -q /tmp/suitecrm.zip -d /tmp/suitecrm-src \
    && mv /tmp/suitecrm-src/SuiteCRM-7.15.2 /var/suitecrm-app \
    && rm -rf /tmp/suitecrm.zip /tmp/suitecrm-src

# Install Composer and dependencies
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN cd /var/suitecrm-app && composer install --no-dev --optimize-autoloader --no-interaction 2>/dev/null || true

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Dir for persistent volumes (created on first boot)
RUN mkdir -p /persistent

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
