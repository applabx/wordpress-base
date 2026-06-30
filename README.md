# AppLabX WordPress Base Image

> A **production-grade, reusable WordPress foundation** for every AppLabX WordPress deployment. Based on the official `wordpress:php8.3-apache` image with hardened PHP, tuned Apache, and operational tooling baked in.

---

## Table of Contents

- [Overview](#overview)
- [Why a base image?](#why-a-base-image)
- [Quick start](#quick-start)
- [Repository structure](#repository-structure)
- [What's inside](#whats-inside)
- [Configuration reference](#configuration-reference)
- [Creating a downstream project](#creating-a-downstream-project)
- [Local development](#local-development)
- [Coolify deployment](#coolify-deployment)
- [Security considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

This repository contains a **Dockerfile and supporting configuration** that produces a reusable WordPress base image used across all AppLabX WordPress projects:

| Downstream project | Inherits from |
|---|---|
| VisaPermit Blog | `ghcr.io/applabx/wordpress-base:latest` |
| 9cv9 Offshoring | `ghcr.io/applabx/wordpress-base:latest` |
| AppLabX websites | `ghcr.io/applabx/wordpress-base:latest` |
| Publisher | `ghcr.io/applabx/wordpress-base:latest` |
| AI Content Engine | `ghcr.io/applabx/wordpress-base:latest` |
| Future SEO sites | `ghcr.io/applabx/wordpress-base:latest` |
| Future client WP deploys | `ghcr.io/applabx/wordpress-base:latest` |

Instead of each project starting from `wordpress:latest` and repeating the same hardening and tuning steps, every project simply:

```dockerfile
FROM ghcr.io/applabx/wordpress-base:latest
```

---

## Why a base image?

| Without base image | With base image |
|---|---|
| Each project copies the same PHP/Apache config | Config lives in one place |
| Security fixes need N separate PRs | One image update → all projects benefit |
| Hard to track which deploy has what PHP version | Single image tag = consistent stack |
| Coolify "Recreate" hits the same unoptimised defaults | Base image is pre-tuned |

---

## Quick start

### Pull the published image

```bash
docker pull ghcr.io/applabx/wordpress-base:latest
```

### Run it immediately (with a MySQL sidecar)

```bash
docker run -d \
  --name wordpress \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=mysql \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=secret \
  ghcr.io/applabx/wordpress-base:latest
```

### Use Docker Compose

See [`examples/docker-compose.yml`](examples/docker-compose.yml) for a full WordPress + MySQL + Redis stack.

---

## Repository structure

```
AppLabx-Wordpress-Base/
├── .github/
│   └── workflows/
│       └── docker.yml          # CI: build → test → push to GHCR
├── examples/
│   ├── docker-compose.yml      # Full dev stack with MySQL + Redis
│   └── downstream-example/    # Minimal downstream project skeleton
│       ├── Dockerfile         # Shows how to inherit
│       └── docker-compose.yml
├── .gitignore
├── apache-security.conf       # Apache hardening & performance
├── CHANGELOG.md
├── docker-entrypoint.sh       # Pre-flight checks → WP entrypoint
├── Dockerfile                 # Main build file
├── LICENSE
├── opcache.ini                # OPcache tuning
├── php.ini                    # Production PHP defaults
└── README.md
```

---

## What's inside

### Base image

- `wordpress:php8.3-apache` (official, latest stable)

### Installed PHP extensions

| Extension | Purpose |
|---|---|
| `pdo` | Database abstraction (core) |
| `pdo_mysql` | MySQL via PDO (core) |
| `mysqli` | MySQL via mysqli (core) |
| `gd` | Image manipulation (core) |
| `exif` | EXIF metadata reading (core) |
| `zip` | ZIP archive handling (core) |
| `intl` | Internationalisation (core) |
| `curl` | HTTP requests (core) |
| `mbstring` | Multibyte string (core) |
| `xml` | XML parsing (core) |
| `imagick` *(optional)* | Advanced image processing (ImageMagick backend) |
| `redis` *(optional)* | Redis session + object cache backend |

### Installed system utilities

| Package | Purpose |
|---|---|
| `git` | Required by many WP plugins / themes |
| `curl` | HTTP tooling, health checks |
| `unzip` / `zip` | Plugin / theme install via zip |
| `nano` / `vim-tiny` | Debugging inside the container |
| `less` | Log reading |
| `mariadb-client` | `wp-cli db` operations, remote DB access |
| `msmtp` | Sendmail replacement for `wp_mail()` |

### PHP defaults

| Setting | Value | Notes |
|---|---|---|
| `memory_limit` | 512M | Sufficient for most WP stacks |
| `max_execution_time` | 300 s | Required for bulk operations |
| `max_input_time` | 300 s | Match execution time |
| `max_input_vars` | 5000 | Handles large admin forms |
| `upload_max_filesize` | 256M | Large media uploads |
| `post_max_size` | 256M | Match upload limit |
| `max_file_uploads` | 100 | Bulk media uploads |
| `display_errors` | Off | Never expose errors in prod |
| `error_reporting` | E_ALL & ~NOTICE & ~STRICT | Production-safe level |
| `expose_php` | Off | Remove `X-Powered-By` equivalent |
| `date.timezone` | Asia/Singapore | Configurable |
| `realpath_cache_size` | 4096K | Reduce syscalls |
| `session.cookie_httponly` | On | XSS session protection |
| `session.cookie_secure` | *(default Off)* | HTTPS-only — enable via `PHP_SESSION_COOKIE_SECURE=On` in prod |

### OPcache tuning

| Setting | Value | Purpose |
|---|---|---|
| `memory_consumption` | 256 MB | Cache size |
| `max_accelerated_files` | 100 000 | Number of cached scripts |
| `validate_timestamps` | 0 (Off) | Production — no stat() on every request |
| `revalidate_freq` | 0 | Immediate cache invalidation signal |
| `interned_strings_buffer` | 32 MB | Repeated string deduplication |
| JIT | disabled | WordPress is I/O-bound; JIT provides negligible benefit with segfault risk |

### Apache hardening

- `ServerTokens Prod` — remove version disclosure (Debian Apache)
- `ServerSignature Off` — no version on error pages
- TRACE blocked via `<LimitExcept>`
- `Options -Indexes` — no directory listing
- `Options +FollowSymLinks` — required for WordPress RewriteRule; symlinks escaping the docroot are still blocked at the server level
- `KeepAlive On` — persistent connections
- `mod_deflate` — gzip compression for all text assets
- `mod_expires` — browser caching for static assets
- `LimitRequestBody 268435456` — 256 MB Apache-level body limit

### Security headers (via `mod_headers`)

| Header | Value | Purpose |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-Frame-Options` | `SAMEORIGIN` | Clickjacking protection |
| `X-XSS-Protection` | `1; mode=block` | Legacy XSS filter |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Referrer leakage control |
| `Permissions-Policy` | minimal flags | Disable unused browser APIs |

A relaxed CSP is applied inside `/wp-admin/` and `/wp-login.php` to avoid breaking the WordPress admin UI (which uses extensive inline scripts and styles).

---

## Configuration reference

All environment variables are **inherited from the official WordPress image** and work identically:

| Variable | Default | Description |
|---|---|---|
| `WORDPRESS_DB_HOST` | `mysql` | Database hostname |
| `WORDPRESS_DB_NAME` | `wordpress` | Database name |
| `WORDPRESS_DB_USER` | `wordpress` | Database user |
| `WORDPRESS_DB_PASSWORD` | *(unset)* | Database password |
| `WORDPRESS_TABLE_PREFIX` | `wp_` | Table prefix |
| `WORDPRESS_DEBUG` | *(unset)* | Enable WP_DEBUG mode |
| `PHP_UPLOAD_MAX_FILESIZE` | `256M` | Upload limit |
| `PHP_POST_MAX_SIZE` | `256M` | POST data limit |

**Additional variables added by this image:**

| Variable | Default | Description |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `512M` | Override memory_limit |
| `PHP_MAX_EXECUTION_TIME` | `300` | Override max_execution_time |

---

## Creating a downstream project

### Step 1 — Create a new project directory

```bash
mkdir my-wordpress-site && cd my-wordpress-site
```

### Step 2 — Add your Dockerfile

```dockerfile
# my-wordpress-site/Dockerfile
FROM ghcr.io/applabx/wordpress-base:latest

# ── Install additional system packages ────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ghostscript \
    && rm -rf /var/lib/apt/lists/*

# ── Install WordPress plugins via WP-CLI ──────────────────
# (Only during image build; prefer auto-install via docker-compose
#  if plugins change frequently)
RUN wp plugin install \
        wordpress-seo \
        wp-super-cache \
        redis-cache \
    --allow-root

# ── Install a specific theme ──────────────────────────────
RUN wp theme install astra --activate --allow-root

# ── Copy custom configuration (optional) ───────────────────
# COPY wp-content/uploads/.htaccess /var/www/html/wp-content/uploads/.htaccess
```

### Step 3 — Add docker-compose.yml

```yaml
# docker-compose.yml
services:
  wordpress:
    build: .
    container_name: my-wordpress-site
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_NAME: my_wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: "${DB_PASSWORD}"
      WORDPRESS_TABLE_PREFIX: wp_
    volumes:
      - wordpress_data:/var/www/html
      # Mount custom uploads dir for persistence
      - ./uploads:/var/www/html/wp-content/uploads
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_started

  mysql:
    image: mysql:8.0
    container_name: my-wordpress-mysql
    environment:
      MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASSWORD}"
      MYSQL_DATABASE: my_wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: "${DB_PASSWORD}"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: my-wordpress-redis
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data

volumes:
  wordpress_data:
  mysql_data:
  redis_data:
```

### Step 4 — Add .env

```bash
# .env
DB_ROOT_PASSWORD=change-me-in-production
DB_PASSWORD=change-me-in-production
```

### Step 5 — Build and start

```bash
docker compose up -d --build
```

See [`examples/downstream-example/`](examples/downstream-example/) for a complete minimal project.

---

## Local development

### Using the base image directly

```bash
docker pull ghcr.io/applabx/wordpress-base:latest
docker compose -f examples/docker-compose.yml up -d
open http://localhost:8080
```

### Using the downstream example

```bash
cd examples/downstream-example
cp .env.example .env   # edit with your values
docker compose up -d --build
open http://localhost:8080
```

### Using Coolify

1. Add a new application in Coolify.
2. Set the **Build Dockerfile** path to `Dockerfile` (in your project root).
3. Set the following environment variables in Coolify's environment editor:

| Key | Value |
|---|---|
| `WORDPRESS_DB_HOST` | `mysql` (or your managed DB host) |
| `WORDPRESS_DB_NAME` | `your_database` |
| `WORDPRESS_DB_USER` | `your_user` |
| `WORDPRESS_DB_PASSWORD` | *(your password)* |
| `WORDPRESS_TABLE_PREFIX` | `wp_` |
| `PHP_UPLOAD_MAX_FILESIZE` | `256M` |
| `PHP_POST_MAX_SIZE` | `256M` |

4. Add a persistent storage mount: source=`wordpress-data`, destination=`/var/www/html`.
5. Set the domain and deploy.

> **Note:** After updating the base image and rebuilding your downstream project, run `wp cache flush` inside the container to clear the OPcache:
> ```bash
> docker compose exec wordpress wp cache flush --allow-root
> ```

---

## Security considerations

### What this image does

- Removes Apache and PHP version disclosure
- Blocks TRACE HTTP method
- Applies security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Disables directory listing
- Prevents symlink traversal
- Sets `display_errors=Off`
- Configures `httponly` and `secure` session cookies
- Follows principle of least privilege (no unnecessary packages)

### What this image does NOT do

- **WordPress security** — keep WordPress core, themes, and plugins updated. Use a security plugin (e.g. Wordfence, Sucuri).
- **File permissions** — the `/var/www/html` directory is owned by `www-data:www-data` in production; ensure your volume mounts preserve this.
- **Network security** — put the container behind a reverse proxy (Traefik, Nginx) with TLS termination and a WAF.
- **Malicious plugin/theme code** — audit third-party code before installing.
- **Database security** — use strong DB passwords, TLS connections, and private networking.

### Hardening checklist before going live

- [ ] Change all default database passwords
- [ ] Enable HTTPS (uncomment `Strict-Transport-Security` in `apache-security.conf`)
- [ ] Configure `wp-config.php` with secure keys (`wp_generate_passwords` or `wp-cli config shuffle-keys`)
- [ ] Set `WORDPRESS_TABLE_PREFIX` to a non-default value
- [ ] Enable Redis object cache (see "Redis" section below)
- [ ] Set up automated backups of the database and uploads volume
- [ ] Restrict `wp-admin` access by IP (`.htaccess` or reverse proxy rule)

---

## Troubleshooting

### "Allowed memory size exhausted" error

Increase `memory_limit` in the Coolify environment editor:

```
PHP_MEMORY_LIMIT=1024M
```

Or mount a custom `php.ini`:

```yaml
volumes:
  - ./custom-php.ini:/usr/local/etc/php/conf.d/zz-custom.ini:ro
```

### OPcache serves stale code after deploy

Run inside the container:

```bash
docker compose exec wordpress wp cache flush --allow-root
```

Or trigger via WP-CLI in your CI/CD deploy pipeline:

```bash
wp cache flush --allow-root
```

### Image upload fails with "Exceeded upload limit"

Ensure both `PHP_UPLOAD_MAX_FILESIZE` and `PHP_POST_MAX_SIZE` are set in Coolify env vars (default 256M).

Also check `client_max_body_size` in any reverse proxy (Nginx/Cloudflare) in front of the container.

### Health check fails

```bash
docker inspect --format='{{json .State.Health}}' <container-id>
```

The health check hits `/` (root URL). WordPress always responds from `/` — either the front page, the install wizard, or a redirect to wp-admin. If a reverse proxy blocks `/`, update the `HEALTHCHECK` in the Dockerfile to point to a page you know is accessible (e.g. `/wp-login.php`).

---

## Roadmap

### v1.1 (near-term)

- [ ] Add `smtp` PHP extension for transactional email (Mailgun, Postmark, etc.)
- [ ] Document multi-container (Kubernetes) deployment pattern
- [ ] Add `blackfire.io` / `newrelic` profiling extension variants
- [ ] Add variant with bundled WP-CLI for bootstrap scripts

### v2.0 (mid-term)

- [ ] Multi-stage Dockerfile splitting Apache from PHP-FPM (for Kubernetes)
- [ ] Official Helm chart for Kubernetes
- [ ] Variant with pre-installed WooCommerce baseline
- [ ] Automatic OPcache invalidation on deploy (deploy hook script)

### v2.1+

- [ ]musl/Alpine variant for smaller image size (~30 % reduction)
- [ ] Arm64-native build for M-series Mac development parity
- [ ] SBOM generation in CI

---

## License

MIT — see [LICENSE](LICENSE).

---

*Maintained by the AppLabX DevOps team.*
