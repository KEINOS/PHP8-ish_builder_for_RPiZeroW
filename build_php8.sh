#!/bin/bash
# =============================================================================
#  This script builds latest master PHP from source on RaspberryPi Zero (ARMv6)
#
#  - Raspbian OS: v10 Buster
# =============================================================================

# =============================================================================
#  Pre check before run
# =============================================================================

if [ "$(whoami)" != "root" ]; then
  echo 'ERROR: You need to run this script with sudo or as a root.'
  exit 1
fi

# =============================================================================
#  Define Var/Const/Env value
# =============================================================================

VERSION_PHP='8.0.0-dev'
SCREEN_WIDTH_DEFAULT=60

NAME_FILE_ZIP_PHP='php.zip'

NAME_DIR_SRC='php-src'
NAME_DIR_EXTRACT='php-src-master'

PATH_DIR_SCRIPT=$(cd $(dirname $0); pwd)
PATH_DIR_SRC="${PATH_DIR_SCRIPT}/${NAME_DIR_SRC}/${NAME_DIR_EXTRACT}"
PATH_DIR_INI_PHP='/usr/local/etc/php'
PATH_DIR_CONF_PHP="${PATH_DIR_INI_PHP}/conf.d"

PATH_FILE_ZIP_PHP="${PATH_DIR_SCRIPT}/${NAME_FILE_ZIP_PHP}"

# PHP Envs
PHP_VERSION=$VERSION_PHP
PHP_URL='https://github.com/php/php-src/archive/master.zip'
PHP_INI_DIR='/usr/local/etc/php'

# Colorize Fonts
FONT_ESC='\e['
FONT_ESC_END='m'
FONT_COLOR_OFF="${FONT_ESC}${FONT_ESC_END}"
FONT_COLOR_BLUE="${FONT_ESC}34${FONT_ESC_END}"
FONT_COLOR_BLUE_BLINK="${FONT_ESC}34;5${FONT_ESC_END}"
FONT_COLOR_BLUE_BOLD="${FONT_ESC}34;1${FONT_ESC_END}"

# Screen Width
if [ -n "${TERM}" ];
  then SCREEN_WIDTH=$(tput cols);
  else SCREEN_WIDTH=$SCREEN_WIDTH_DEFAULT;
fi

# =============================================================================
#  Functions
# =============================================================================

function askUserContinue(){
    askUserYorN "${1}" "${2}" || {
        echo 'Script cancelled.'
        exit 1
    }
}

function askUserYorN(){
    echo -n -e "${FONT_COLOR_BLUE_BLINK}?${FONT_COLOR_OFF}"
    read -p " ${1} (y/n): " INPUT
    INPUT=$(tr '[a-z]' '[A-Z]' <<< $INPUT)
    if [ ${INPUT:0:1} = 'Y' ] ; then
        return 0
    fi
    return 1
}

function echoHR(){
    # Draws Horizontal Line with the char of $1
    printf -v _hr "%*s" ${SCREEN_WIDTH} && echo ${_hr// /${1--}}
}

function echoTitle(){
    SEPARATOR_DEFAULT='-'
    echoHR ${2:-$SEPARATOR_DEFAULT}
    sudo echo " ${1}"
    echoHR ${2:-$SEPARATOR_DEFAULT}
}

function echoStatus(){
    echo -n -e "${FONT_COLOR_BLUE_BOLD}- ${1}${FONT_COLOR_OFF} "
    echo ${@:3:($#-2)}
}

# =============================================================================
echoTitle 'PHP8-ish builder for RaspberryPi Zero (ARMv6l)' '='
# =============================================================================
askUserContinue 'This will take a lot of time. Continue install?'

# -----------------------------------------------------------------------------
echoTitle 'Install Deps(Dependencies)'
# -----------------------------------------------------------------------------

set -eu

echoStatus 'Update and upgrade apt packages'
apt update -y && apt upgrade -y

echoStatus 'Uninstall unused packages'
apt autoremove -y

# Presistent deps for runtime.
PRESIST_DEPS=(
    ca-certificates
    apt-transport-https
    curl
    wget
    tar
    xz-utils liblzma-dev
    openssl
)
echoStatus 'Install presistent deps for runtime:' "${PRESIST_DEPS[@]}"
#apt-cache policy $(echo "${PRESIST_DEPS[@]}")
apt --no-install-recommends install $(echo "${PRESIST_DEPS[@]}") -y

# Un-presistent deps for runtime.
#   These deps will be uninstalled after build.
UNPRESIST_DEPS=(
    gnupg
)
echoStatus 'Install un-presistent deps for runtime:' "${UNPRESIST_DEPS[@]}"
#apt-cache policy $(echo "${PRESIST_DEPS[@]}")
apt --no-install-recommends install $(echo "${UNPRESIST_DEPS[@]}") -y

# Deps for "phpize".
#   Required for running "phpize". These get automatically installed and
#   removed by "docker-php-ext-*" (unless they're already installed)
PHPIZE_DEPS=(
    autoconf
    dpkg-dev dpkg
    file
    g++
    gcc
    libc-dev
    make
    pkgconf
    re2c
)
echoStatus 'Install deps for phpize:' "${PHPIZE_DEPS[@]}"
apt --no-install-recommends install $(echo "${PHPIZE_DEPS[@]}") -y

# Deps for building.
#   These deps will be uninstalled after build.
BUILD_DEPS=(
    bison
    flex
    coreutils
    libcurl4
    libcurl4-openssl-dev
    libargon2-dev
    libedit-dev
    libffi6
    libffi-dev
    libjpeg-dev
    libonig-dev
    libpng-dev
    libsodium-dev
    libsqlite3-dev
    libssl-dev
    libsystemd-dev
    libxml2-dev
)
echoStatus 'Install build deps:' "${BUILD_DEPS[@]}"
#apt-cache policy $(echo "${PRESIST_DEPS[@]}")
apt --no-install-recommends install $(echo "${BUILD_DEPS[@]}") -y

# -----------------------------------------------------------------------------
echoTitle 'Download latest master of PHP'
# -----------------------------------------------------------------------------
cd $PATH_DIR_SCRIPT
if [ ! -d "${PATH_DIR_SRC}" ]; then
    mkdir -p $PATH_DIR_SRC
fi
if [ ! -f "${PATH_FILE_ZIP_PHP}" ]; then
    echoStatus 'Downloading ZIP master'
    wget -O "${PATH_FILE_ZIP_PHP}" "${PHP_URL}"
    unzip -q $PATH_FILE_ZIP_PHP -d $PATH_DIR_SRC
else
    echoStatus 'Downloaded ZIP file found.'
fi

# -----------------------------------------------------------------------------
echoTitle 'Configuring PHP install'
# -----------------------------------------------------------------------------

# Apply stack smash protection to functions using local buffers and alloca()
#   Make PHP's main executable position-independent (improves ASLR security
#   mechanism, and has no performance impact on x86_64)
#     Enable optimization (-O2)
#     Enable linker optimization (this sorts the hash buckets to improve cache
#            locality, and is non-default)
#     Adds GNU HASH segments to generated executables (this is used if present,
#          and is much faster than sysv hash; in this configuration, sysv hash
#          is also generated)
#   https://github.com/docker-library/php/issues/272
PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
PHP_CPPFLAGS="$PHP_CFLAGS"
PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

# Exporting Flags to compile
export \
    CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
    LDFLAGS="$PHP_LDFLAGS" \

# Detect Arch Type
gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
echoStatus 'Package architecture:' "${gnuArch}"

cd $PATH_DIR_SRC

echoStatus 'Building configure file'
./buildconf

echo 'Done building configure file'
ls

echoStatus 'Run configure'
./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-option-checking=fatal \
    --with-mhash \
    --enable-ftp \
    --enable-mysqlnd \
    --with-password-argon2 \
    --with-sodium=shared \
    --with-openssl=/usr \
    --with-system-ciphers \
    --with-ffi \
    --with-curl \
    --with-libedit \
    --with-zlib \
    --enable-soap \
    --enable-pcntl \
    --enable-opcache \
    --enable-mbstring \
    $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit')

# -----------------------------------------------------------------------------
echoTitle 'Make and install'
# -----------------------------------------------------------------------------
make -j "$(nproc)"
find -type f -name '*.a' -delete
make install
{ find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }
make clean
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
cp -v php.ini-* "$PHP_INI_DIR/"
