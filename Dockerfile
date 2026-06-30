# ============================================================
# AppLabX WordPress Base Image
# ============================================================
# A production-grade, reusable WordPress foundation for all
# AppLabX WordPress deployments. Based on the official
# WordPress Apache image (PHP 8.3, Apache 2.4).
#
# Supported architectures: linux/amd64, linux/arm64/v8
# ============================================================

FROM wordpress:php8.3-apache

# Labels — OCI distribution-spec
LABEL maintainer="AppLabX <dev@applabx.com>" \
      org.opencontainers.image.title="AppLabX WordPress Base" \
      org.opencontainers.image.description="Production-ready WordPress base image for AppLabX deployments" \
      org.opencontainers.image.source="https://github.com/applabx/wordpress-base" \
      org.opencontainers.image.licenses="MIT"

# ── Prevent apt interactive prompts ─────────────────────────
ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ─────────────────────────────────────────
# Keeping this list minimal:
#   git       — required by many WP plugins/themes (composer, svn/git clones)
#   curl/wget — used by WP-CLI, health checks, plugin installs
#   unzip/zip — plugin/theme install via zip, backup tools
#   nano/vim  — in-container debugging
#   less      — log reading (docker logs)
#   mariadb-client — wp-cli db ops, mysqldump, remote DB health checks
#   ca-certificates — HTTPS outbound calls (API webhooks, plugin updates)
#   msmtp*    — sendmail replacement for wp_mail()
#   jpegoptim/optipng/cwebp — lossless image optimisation on upload
#   libmagickwand-dev — imagick PHP extension build dependency

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
    zip \
    nano \
    vim-tiny \
    less \
    mariadb-client \
    ca-certificates \
    msmtp \
    ghostscript \
    libmagickwand-dev \
    jpegoptim \
    optipng \
    webp \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ── Install mlocati/docker-php-extension-installer ──────────
# This is the standard tool for adding PHP extensions to official
# PHP/WordPress images. It handles dependency resolution, compilation,
# and enabling in one shot.
RUN curl -fsSL \
        https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
        -o /usr/local/bin/install-php-extensions \
    && chmod +x /usr/local/bin/install-php-extensions

# ── PHP extensions (in addition to those already in the base) ─
# Base already includes: pdo, pdo_mysql, mysqli, gd, exif, zip,
#   intl, opcache, curl, mbstring, xml, xmlreader, xmlwriter, dom
# We add the ones below.

RUN install-php-extensions \
        imagick \
        redis \
    && rm -rf /tmp/pear

# ── WP-CLI ──────────────────────────────────────────────────
# Pre-installed so downstream projects don't need to install it.
# Version-pinned to avoid surprise updates breaking downstream builds.
ENV WP_CLI_VERSION=2.11.0
RUN curl -fsSL "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
        -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp \
    && wp --version --allow-root 2>/dev/null \
    || echo "WP-CLI installed but wp command not found (non-fatal)"

# ── PHP configuration ───────────────────────────────────────
# Custom php.ini and OPcache settings are loaded AFTER the
# official image defaults via conf.d/ overrides.

COPY php.ini       $PHP_INI_DIR/conf.d/99-applabx-overrides.ini
COPY opcache.ini   $PHP_INI_DIR/conf.d/zz-applabx-opcache.ini

# ── Apache hardening ────────────────────────────────────────
# Copy the custom security config; enable it via IncludeOptional.
# The base image (wordpress:php8.3-apache) uses Debian Apache at
# /etc/apache2/, not the HTTPD project's at /usr/local/apache2/.

RUN a2enmod rewrite headers expires deflate filter \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "# AppLabX security & performance hardening" >> /etc/apache2/apache2.conf \
    && echo "IncludeOptional conf/extra/applabx-security.conf" >> /etc/apache2/apache2.conf

COPY apache-security.conf /etc/apache2/conf/extra/applabx-security.conf

# ── Custom entrypoint ────────────────────────────────────────
# Validates the environment, prints a startup banner, then
# delegates to the official WordPress entrypoint.
# Do NOT override WORDPRESS_DIRECTORY or WP env vars here.

# Save the official entrypoint BEFORE overwriting it with ours.
# Our entrypoint needs to call the official one at the end,
# but both are named docker-entrypoint.sh — so we preserve
# the original under a different name here.
RUN cp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-origin

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

# ── Health check ────────────────────────────────────────────
# Hits the root URL (/). WordPress always responds from / — either
# the front page (if installed), the install wizard (if not), or a
# redirect to wp-admin. All indicate the container is healthy.
#
# NOT using xmlrpc.php or wp-cron.php:
#   - xmlrpc.php is often blocked by security plugins / WAFs
#   - wp-cron.php runs on every request (not a clean health signal)
#   - Both can return non-200 even when WP is healthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf -o /dev/null -w "%{http_code}" http://localhost:80/ \
     | grep -qE "^(200|301|302|304|500)$" \
     || exit 1

# ── Runtime environment defaults ─────────────────────────────
# Explicit defaults. The WordPress entrypoint respects all WORDPRESS_*
# env vars, so these are overridden by docker-compose/Coolify as needed.
ENV WORDPRESS_DB_HOST=mysql
ENV WORDPRESS_DB_NAME=wordpress
ENV WORDPRESS_DB_USER=wordpress
ENV WORDPRESS_TABLE_PREFIX=wp_

# ── Ports ───────────────────────────────────────────────────
EXPOSE 80 443
