# Changelog

All notable changes to the AppLabX WordPress Base Image are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-06-30

### Added

- **Dockerfile** — multi-stage build based on `wordpress:php8.3-apache`, adding `imagick`, `redis`, `git`, `curl`, `unzip`, `zip`, `nano`, `vim-tiny`, `less`, `mariadb-client`, `msmtp` system packages.
- **`php.ini`** — production PHP defaults: 512 MB memory, 300 s execution time, 256 M upload/POST limits, 5 000 max input vars, `display_errors=Off`, `expose_php=Off`, `error_reporting` tuned for production, `realpath_cache_size=4096K`, `session.cookie_httponly/Secure=On`.
- **`opcache.ini`** — tuned OPcache: 256 MB memory, 100 000 accelerated files, timestamps validation off, JIT enabled (function mode, 128 MB buffer), interned strings 32 MB, fast shutdown.
- **`apache-security.conf`** — Apache 2.4 hardening: `ServerTokens Prod`, `ServerSignature Off`, TRACE blocked via rewrite, `Options -Indexes` + `-FollowSymLinks`, `KeepAlive On`, `mod_deflate` gzip, `mod_expires` asset caching, security headers (`X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`, `Permissions-Policy`) with relaxed CSP inside `/wp-admin/`.
- **`docker-entrypoint.sh`** — custom pre-flight entrypoint: validates PHP binary, checks required directories, verifies PHP INI overrides applied, lists loaded extensions, prints environment summary, delegates to official WordPress entrypoint.
- **`.gitignore`** — excludes `.env`, `.pem`, `.key`, vendor directories, IDE files, OS artifacts.
- **`examples/docker-compose.yml`** — full WordPress + MySQL 8 + Redis 7 stack with named volumes and health checks.
- **`examples/downstream-example/`** — minimal downstream project skeleton with `Dockerfile`, `docker-compose.yml`, and `.env.example`.
- **`.github/workflows/docker.yml`** — GitHub Actions CI: build on push/PR, run validation script, push `latest` and version tags to GHCR on tag events.
- **`CHANGELOG.md`** — this file.
- **`LICENSE`** — MIT licence.

[1.0.0]: https://github.com/applabx/wordpress-base/releases/tag/v1.0.0
