# ============================================================
# Downstream Example — Minimal WordPress Project
# ============================================================
# This directory shows the minimum a downstream project needs
# to build on top of the AppLabX WordPress Base image.
#
# This is NOT a WordPress website.
# This is a project template that INHERITS from the base image.
# ============================================================

# ── Your project's Dockerfile ────────────────────────────────
# Copy this into your new project root and customise it.

# syntax=docker/dockerfile:1
FROM ghcr.io/applabx/wordpress-base:latest

# ── Optional: install additional system packages ────────────
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     ghostscript \
#     && rm -rf /var/lib/apt/lists/*

# ── Optional: install WordPress plugins via WP-CLI ───────────
# RUN wp plugin install \
#         wordpress-seo \
#         wp-super-cache \
#         redis-cache \
#     --allow-root

# ── Optional: install a theme ───────────────────────────────
# RUN wp theme install astra --activate --allow-root

# ── Optional: copy custom wp-content (themes / plugins) ─────
# COPY ./custom-themes /var/www/html/wp-content/themes/custom-themes
# COPY ./custom-plugins /var/www/html/wp-content/plugins/custom-plugins

# ── Optional: add your own Apache config overrides ───────────
# COPY custom-httpd.conf /usr/local/apache2/conf/extra/custom.conf
# RUN echo "IncludeOptional conf/extra/custom.conf" >> /usr/local/apache2/conf/httpd.conf
