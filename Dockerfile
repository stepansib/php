ARG BUILD_IMAGE=''
FROM $BUILD_IMAGE
MAINTAINER Stepan Yudin <stepan.sib@gmail.com>

ENV APP_TIMEZONE=Europe/Moscow

# Install libs
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
  libmcrypt \
  zlib1g-dev \
  libicu-dev g++ \
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
  build-essential \
  openssh-client \
  openssl

# Install node & npm
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - \
  && curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - \
  && sudo apt-get install -y nodejs

# Install PHP mcrypt extension
RUN pecl install mcrypt-1.0.2
RUN docker-php-ext-enable mcrypt

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
  gd \
  ldap \
  opcache \
  pdo \
  pdo_mysql \
  soap \
  zip \
  tidy \
  bcmath

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

# Fix www-data permissions and create work directory
RUN usermod -a -G sudo www-data \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && chgrp -R www-data /var/www \
  && chmod -R g+w /var/www \
  && mkdir -p /var/www/backend \
  && chown -R www-data:www-data /var/www/backend

# Install PHP MSSQL extension
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql17 mssql-tools unixodbc-dev
RUN pecl install sqlsrv pdo_sqlsrv \
  && docker-php-ext-enable sqlsrv pdo_sqlsrv
RUN sed -i 's,^\(MinProtocol[ ]*=\).*,\1'TLSv1.0',g' /etc/ssl/openssl.cnf \
  && sed -i 's,^\(CipherString[ ]*=\).*,\1'DEFAULT@SECLEVEL=1',g' /etc/ssl/openssl.cnf

USER www-data

WORKDIR /var/www/backend

# Install dropbox uploader
RUN cd ~ && curl "https://raw.githubusercontent.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh" -o dropbox_uploader.sh \
  && chmod +x dropbox_uploader.sh \
  && touch .dropbox_uploader

# Speed up composer for www-data user
RUN composer global require hirak/prestissimo