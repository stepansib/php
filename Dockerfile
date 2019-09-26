FROM php:7.1-fpm
MAINTAINER Stepan Yudin <stepan.sib@gmail.com>

ENV APP_TIMEZONE=Europe/Moscow

# Install node & npm
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -

# Install libs
RUN apt-get update && apt-get install -y --no-install-recommends \
  zlib1g-dev \
  libicu-dev g++ \
  libmcrypt-dev \
  libfreetype6-dev \
  libjpeg62-turbo-dev \
  libpng-dev \
  libldap2-dev \
  libxml2-dev \
  libcurl4-openssl-dev \
  libtidy-dev \
  zip \
  unzip \
  wget \
  xvfb \
  wkhtmltopdf \
  default-mysql-client \
  git \
  mc \
  ruby-full \
  gnupg \
  iputils-ping \
  faketime \
  cron \
  mc \
  sudo \
  iputils-ping \
  supervisor \
  procps \
  dos2unix \
  tzdata \
  freetds-dev \
  nodejs \
  build-essential \
  openssh-client

# Configure PHP extensions
RUN docker-php-ext-configure intl \
  && docker-php-ext-configure pcntl \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/

# Install PHP extensions
RUN docker-php-ext-install \
  curl \
  intl \
  pcntl \
  mcrypt \
  gd \
  ldap \
  opcache \
  pdo \
  pdo_mysql \
  soap \
  zip \
  tidy \
  bcmath

#Install freetds & MSSQL driver
RUN docker-php-ext-configure pdo_dblib --with-libdir=/lib/x86_64-linux-gnu/ \
  && docker-php-ext-install -j$(nproc) pdo_dblib

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHPUnit
RUN wget https://phar.phpunit.de/phpunit.phar \
  && chmod +x phpunit.phar \
  && mv phpunit.phar /usr/local/bin/phpunit

# Install Codeception
RUN curl -LsS https://codeception.com/codecept.phar -o /usr/local/bin/codecept \
  && chmod a+x /usr/local/bin/codecept

# Configure PHP and FPM
COPY ./php.ini /usr/local/etc/php/
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/' /usr/local/etc/php-fpm.d/www.conf
RUN sed -i 's/user = www-data/user = root/' /usr/local/etc/php-fpm.d/www.conf
RUN sed -i 's/group = www-data/group = root/' /usr/local/etc/php-fpm.d/www.conf

# Change app and system timezone
RUN sed -i 's,\Etc/UTC,'"$APP_TIMEZONE"',' /usr/local/etc/php/php.ini
RUN cp /usr/share/zoneinfo/$APP_TIMEZONE /etc/localtime && echo $APP_TIMEZONE > /etc/timezone

# Install Supercronic
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.6/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=c3b78d342e5413ad39092fd3cfc083a85f5e2b75

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Speed up composer for www-data user
RUN composer global require hirak/prestissimo

WORKDIR "/var/www/backend"

RUN cat /usr/local/etc/php/php.ini