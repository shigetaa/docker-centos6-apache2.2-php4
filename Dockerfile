FROM centos6-apache2.2

ENV PHP_PREFIX /usr/local/php
ENV PATH $PHP_PREFIX/bin:$PATH
ENV PHP_VERSION 4.3.11

ENV CURL_PREFIX /usr/local/curl
ENV PATH $CURL_PREFIX/bin:$PATH
ENV CURL_VERSION 7.15.0

RUN set -x \
  && mkdir -p "$PHP_PREFIX"/src \
  && mkdir -p "$CURL_PREFIX"/src \
  \
  && yum -y install \
     gd \
     gd-devel \
     libpng-devel \
     libxml2-devel \
     libjpeg-devel \
     flex \
     bison \
     openssl-* \
     libtool-ltdl-devel \
  \
  && cd $CURL_PREFIX \
  && wget --no-check-certificate -O curl-$CURL_VERSION.tar.gz \
     https://curl.se/download/archeology/curl-$CURL_VERSION.tar.gz \
  \
  && tar zxvf curl-$CURL_VERSION.tar.gz -C src --strip-components=1 \
  && rm -f curl-$CURL_VERSION.tar.gz \
  && cd src \
  && ./configure \
     --prefix=$CURL_PREFIX \
     --with-ssl \
     --with-gnutls \
  && make -j "$(nproc)" \
  && make install \
  \
  && ln -sfT /usr/lib64/libjpeg.so /usr/lib/libjpeg.so \
  && ln -sfT /usr/lib64/libjpeg.so.62 /usr/lib/libjpeg.so.62 \
  && ln -sfT /usr/lib64/libjpeg.so.62.0.0 /usr/lib/libjpeg.so.62.0.0 \
  \
  && ln -sfT /usr/lib64/libpng.so /usr/lib/libpng.so \
  && ln -sfT /usr/lib64/libpng.so.3 /usr/lib/libpng.so.3 \
  && ln -sfT /usr/lib64/libpng.so.3.49.0 /usr/lib/libpng.so.3.49.0 \
  && ln -sfT /usr/lib64/libpng12.so /usr/lib/libpng12.so \
  && ln -sfT /usr/lib64/libpng12.so.0 /usr/lib/libpng12.so.0 \
  && ln -sfT /usr/lib64/libpng12.so.0.49.0 /usr/lib/libpng12.so.0.49.0 \
  \
  && cd $PHP_PREFIX \
  && wget -O php-$PHP_VERSION.tar.gz \
     http://museum.php.net/php4/php-$PHP_VERSION.tar.gz \
  \
  && tar zxvf php-$PHP_VERSION.tar.gz -C src --strip-components=1 \
  && rm -f php-$PHP_VERSION.tar.gz \
  && cd src \
  \
  && wget --no-check-certificate -O ext/openssl/openssl.c \
     https://www.softel.co.jp/blogs/tech/wordpress/wp-content/uploads/2012/10/openssl.c \
  && ./configure \
     --prefix=$PHP_PREFIX \
     --with-apxs2=/usr/local/apache2/bin/apxs \
     --enable-mbstring \
     --enable-mbregex \
     --enable-zend-multibyte \
     --enable-gd-native-ttf \
     --enable-bcmath \
     --with-zlib \
     --with-gd \
     --with-jpeg-dir=/usr/local/lib \
     --with-png-dir=/usr/local/lib \
     --with-freetype-dir=/usr/local/lib \
     --with-curl=$CURL_PREFIX \
     --with-dom \
     --with-openssl \
  && make -j "$(nproc)" \
  && make install \
  \
  && cp php.ini-dist $PHP_PREFIX/lib/php.ini \
  \
  && sed -i -e "s|;error_log = syslog|error_log = /proc/self/fd/2|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|;mbstring.language = Japanese|mbstring.language = Japanese|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|;mbstring.internal_encoding = EUC-JP|mbstring.internal_encoding = UTF-8|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|;mbstring.http_input = auto|mbstring.http_input = auto|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|;mbstring.detect_order = auto|mbstring.detect_order = auto|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|expose_php = On|expose_php = Off|" $PHP_PREFIX/lib/php.ini \
  && sed -i -e "s|;date.timezone =|date.timezone = Asia/Tokyo|" $PHP_PREFIX/lib/php.ini \
  \
  && sed -i -e "s|DirectoryIndex index.html|DirectoryIndex index.php index.html index.htm|g" $HTTPD_PREFIX/conf/httpd.conf \
  && sed -i -e "s|AddType application/x-gzip .gz .tgz|AddType application/x-gzip .gz .tgz\n    \# PHP\n    AddType application/x-httpd-php .php|" $HTTPD_PREFIX/conf/httpd.conf \
  \
  && cd $PHP_PREFIX \
  && rm -Rf src man

EXPOSE 80
CMD ["httpd-foreground"]