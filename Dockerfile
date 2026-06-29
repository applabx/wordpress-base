# ============================================================
# AppLabX WordPress Base Image
# ============================================================
# A production-grade, reusable WordPress foundation for all
# AppLabX WordPress deployments. Based on the official
# WordPress Apache image.
#
# Supported architectures: linux/amd64, linux/arm64/v8
# WordPress version: Latest stable (inherited from base)
# PHP version:        Latest stable (inherited from base)
# Apache version:     Latest stable (inherited from base)
# ============================================================

# ── Stage 1: Build dependencies ────────────────────────────
# We use a multi-stage build to keep the final image lean.
# The "builder" stage is discarded after installing packages.

FROM debian:bookworm-slim AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools and libraries needed to compile PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials for compiling pecl extensions
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Libraries required by various PHP extensions
    libmagickwand-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype-dev \
    libwebp-dev \
    libxpm-dev \
    libmcrypt-dev \
    libedit-dev \
    libffi-dev \
    libkrb5-dev \
    libsodium-dev \
    libldap2-dev \
    libmariadb-dev \
    libpq-dev \
    libtidy-dev \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*


# ── Stage 2: Runtime image ─────────────────────────────────
# All runtime logic lives here. The final image inherits from
# the official WordPress Apache image, which already includes
# Apache 2.4, PHP-FPM (or mod-php), and WordPress scaffolding.

FROM wordpress:php8.3-apache

# Labels — follow OCI distribution-spec
LABEL maintainer="AppLabX <dev@applabx.com>" \
      org.opencontainers.image.title="AppLabX WordPress Base" \
      org.opencontainers.image.description="Production-ready WordPress base image for AppLabX deployments" \
      org.opencontainers.image.source="https://github.com/applabx/wordpress-base" \
      org.opencontainers.image.licenses="MIT"

# ── System packages ────────────────────────────────────────
# Install useful utilities and MariaDB client (useful for
# wp-cli db operations, migrations, health checks).
# We intentionally keep this list short to minimise attack
# surface and image size.

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Version control (git is required by many WP plugins / themes)
    git \
    # HTTP tooling
    curl \
    # Archive utilities
    unzip \
    zip \
    # Text editors for debugging inside the container
    nano \
    vim-tiny \
    # Log viewer
    less \
    # MariaDB client — lets wp-cli connect to remote DBs,
    # run mysqldump, and perform health checks without
    # installing a full MySQL server.
    mariadb-client \
    # System utilities
    ca-certificates \
    tzdata \
    # SMTP sendmail replacement (required by WordPress mail())
    msmtp \
    msmtp-mta \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ── PHP extensions ─────────────────────────────────────────
# Compile and enable additional PHP extensions on top of the
# ones already bundled with the official wordpress image.
# Extensions already in the base image (php8.3-apache):
#   pdo, pdo_mysql, mysqli, gd, exif, zip, intl, opcache
# We add the ones below.

RUN install-php-extensions \
    imagick \
    redis \
    && rm -rf /tmp/pear

# ── Custom PHP configuration ───────────────────────────────
# Copy tuned php.ini and OPcache settings on top of the
# defaults shipped in the official image.

COPY php.ini       $PHP_INI_DIR/conf.d/99-applabx-overrides.ini
COPY opcache.ini   $PHP_INI_DIR/conf.d/zz-applabx-opcache.ini

# ── Apache hardening ────────────────────────────────────────
# Apply security and performance HTTP headers via Apache
# include.  We copy the file first so the symlink below
# resolves reliably.

COPY apache-security.conf /usr/local/apache2/conf/extra/applabx-security.conf

# Enable the custom security config inside Apache's httpd.conf
# fragment.  We append to the IncludeOptional directive list
# rather than patching the main conf file directly.
RUN echo "" >> /usr/local/apache2/conf/httpd.conf \
 && echo "# AppLabX security & hardening" >> /usr/local/apache2/conf/httpd.conf \
 && echo "IncludeOptional conf/extra/applabx-security.conf" >> /usr/local/apache2/conf/httpd.conf

# ── Custom entrypoint ──────────────────────────────────────
# Our entrypoint validates the environment, prints a friendly
# startup banner, then delegates to the official WP entrypoint.
# NEVER overwrite WORDPRESS_DIRECTORY or other WP env vars
# that the upstream entrypoint expects.

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

# ── Health check ────────────────────────────────────────────
# HTTP check against WordPress's built-in xmlrpc.php (or
# wp-cron.php) so we detect a fully-bootstrapped, responding
# container rather than just an open TCP port.

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:80/xmlrpc.php > /dev/null \
     || curl -sf http://localhost:80/wp-cron.php > /dev/null \
     || exit 1

# ── Runtime environment ─────────────────────────────────────
# Sensible defaults that downstream images can override.
# Keep these environment-friendly (uppercase, _-separated).

ENV WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST:-mysql}
ENV WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME:-wordpress}
ENV WORDPRESS_DB_USER=${WORDPRESS_DB_USER:-wordpress}
ENV WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX:-wp_}
ENV PHP_UPLOAD_MAX_FILESIZE=256M
ENV PHP_POST_MAX_SIZE=256M

# ── Ports ───────────────────────────────────────────────────
EXPOSE 80 443
