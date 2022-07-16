# CentOS6 環境で Apache2.2 と PHP4 環境をDockerコンテナで構築
[先日作成した](https://github.com/shigetaa/docker-centos6-apache2.2) CentOS をベースに Apache コンテナイメージを元に
PHP をソースからインストールしてイメージを作成する。

## コンテナ内で作業をする
```bash
docker run -it -p 8080:80 --rm --name centos6-apache2.2 centos6-apache2.2 /bin/bash
```

### 問題
Docker Desktop for Windows (WSL2 backend) を使っていて centos:5 を動かそうとすると、起動せずに Exited (139) で即落ちるというエラーに遭遇しました。

### 対処方法
Docker Desktop for Windows (WSL2 backend) で問題を回避するには %USERPROFILE%/.wslcofig に設定を追加して PC を再起動します。
```bash
[wsl2]
kernelCommandLine = vsyscall=emulate
```
そうすると、以降は起動できるようになります。

## tar.gz から PHP をインストールする

### 環境変数を設定する
```bash
export PHP_PREFIX=/usr/local/php
export PATH=$PHP_PREFIX/bin:$PATH
export PHP_VERSION=4.3.11

export CURL_PREFIX=/usr/local/curl
export PATH=$CURL_PREFIX/bin:$PATH
export CURL_VERSION=7.15.0
```

### インストールフォルダを設定する
```bash
mkdir -p "$PHP_PREFIX"/src
mkdir -p "$CURL_PREFIX"/src
```

### 必要なパッケージをインストールする
```bash
yum -y install gd gd-devel libpng-devel libxml2-devel libjpeg-devel flex bison openssl-* libtool-ltdl-devel
```

### curl 7.15 sorce からインストール
PHP4では curl 7.15 以上の場合　configure 時にエラーがでるのでダウングレードをインストール
```bash
cd $CURL_PREFIX
wget --no-check-certificate -O curl-$CURL_VERSION.tar.gz https://curl.se/download/archeology/curl-$CURL_VERSION.tar.gz
```
```bash
tar zxvf curl-$CURL_VERSION.tar.gz -C src --strip-components=1 && cd src
./configure \
--prefix=$CURL_PREFIX \
--with-ssl \
--with-gnutls
```
```bash
make -j "$(nproc)" && make install
```
### libjpeg, libpng エラー対策
CentOS 64bit kernel の場合 `libjpeg` `libpng` の保存場所が `/usr/lib64` の為
Configure 時に `/usr/lib` を見に行くのでエラーになる為、シンボリックを張って対応する
```bash
# libjpeg
ln -sfT /usr/lib64/libjpeg.so /usr/lib/libjpeg.so
ln -sfT /usr/lib64/libjpeg.so.62 /usr/lib/libjpeg.so.62
ln -sfT /usr/lib64/libjpeg.so.62.0.0 /usr/lib/libjpeg.so.62.0.0
# libpng
ln -sfT /usr/lib64/libpng.so /usr/lib/libpng.so
ln -sfT /usr/lib64/libpng.so.3 /usr/lib/libpng.so.3
ln -sfT /usr/lib64/libpng.so.3.49.0 /usr/lib/libpng.so.3.49.0
ln -sfT /usr/lib64/libpng12.so /usr/lib/libpng12.so
ln -sfT /usr/lib64/libpng12.so.0 /usr/lib/libpng12.so.0
ln -sfT /usr/lib64/libpng12.so.0.49.0 /usr/lib/libpng12.so.0.49.0
```

### PHP source をダウンロードする
```bash
cd $PHP_PREFIX
wget -O php-$PHP_VERSION.tar.gz http://museum.php.net/php4/php-$PHP_VERSION.tar.gz
```
```bash
tar zxvf php-$PHP_VERSION.tar.gz -C src --strip-components=1 && rm -f php-$PHP_VERSION.tar.gz && cd src
```

### OpenSSL エラー対策
OpenSSL1.1を利用の際は開発環境のパッチを当てた ext/openssl/openssl.c をコピーして make する
```bash
wget --no-check-certificate -O ext/openssl/openssl.c https://www.softel.co.jp/blogs/tech/wordpress/wp-content/uploads/2012/10/openssl.c
```
### インストール設定をする
```bash
./configure \
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
--with-openssl
```

### インストールする
```bash
make -j "$(nproc)" && make install
```

### PHP 設定
```bash
cp php.ini-dist $PHP_PREFIX/lib/php.ini
```
```bash
sed -i -e "s|;error_log = syslog|error_log = /proc/self/fd/2|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|;mbstring.language = Japanese|mbstring.language = Japanese|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|;mbstring.internal_encoding = EUC-JP|mbstring.internal_encoding = UTF-8|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|;mbstring.http_input = auto|mbstring.http_input = auto|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|;mbstring.detect_order = auto|mbstring.detect_order = auto|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|expose_php = On|expose_php = Off|" $PHP_PREFIX/lib/php.ini
sed -i -e "s|;date.timezone =|date.timezone = Asia/Tokyo|" $PHP_PREFIX/lib/php.ini
```
```bash
sed -i -e "s|DirectoryIndex index.html|DirectoryIndex index.php index.html index.htm|g" $HTTPD_PREFIX/conf/httpd.conf
sed -i -e "s|AddType application/x-gzip .gz .tgz|AddType application/x-gzip .gz .tgz\n    \# PHP\n    AddType application/x-httpd-php .php|" $HTTPD_PREFIX/conf/httpd.conf
```
### 後始末
```bash
cd $PHP_PREFIX
rm -Rf src man
```

### Apache 再起動
```bash
/usr/local/apache2/bin/apachectl stop
/usr/local/apache2/bin/apachectl start
```
## Dockerfile から Apache のコンテナイメージを作成
以下の Dockerfileファイルを作成する。
```docker
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
```

以下のコマンドで Dockerfile ファイルからコンテナイメージを作成する。
```bash
docker build -t イメージ名 Dockerfileディレクトリ
```
例 Apache のイメージを作成してみる `-t` は イメージ名 最後の文字列は `Dockerfile` のディレクトリを指定します。 `.` はカレントディレクトリを表します。
```bash
docker build -t apache2.2-php4 .
```

下記のコマンドでコンテナを動作させる
```bash
docker run -d -p 8080:80 --name コンテナ名 イメージ名
```
例 DocmentRoot をマウントしてコンテナを起動してみる。 \
`-d` は コンテナをバックグラウンドで実行させる \
`-p` は ホストのポート番号:コンテナのポート番号 \
`-v` は ボリュームをマウントするオプションです。 \
`$Pwd` は Windowsのカレントディレクトリを返す変数 \
`--name` は コンテナ名を指定する \
最後の文字列はイメージ名になります。
```bash
docker run -d -p 8080:80 -v $Pwd/public:/usr/local/apache2/htdocs --name container-apache-php apache2.2-php4
```

実行中のコンテナでシェルを実行する
```bash
docker container exec -it container-apache-php /bin/bash
```




