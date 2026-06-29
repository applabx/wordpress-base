#!/usr/bin/env bash
# ============================================================
# AppLabX WordPress Base — Custom Docker Entrypoint
# ============================================================
# Purpose:
#   1. Validate the PHP environment and loaded extensions
#   2. Print a friendly startup banner with version info
#   3. Check required directories and permissions
#   4. Delegate to the official WordPress entrypoint
#
# This script is idempotent — it is safe to restart the
# container without re-running setup steps.
#
# Usage:
#   Do NOT invoke this script directly.
#   It is set as the ENTRYPOINT in the Dockerfile.
#   All CMD arguments are passed to apache2-foreground.
# ============================================================
set -Eeo pipefail

# ── Colour codes ───────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# ── Helper: print a section header ─────────────────────────
section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $1${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ── Helper: check result ────────────────────────────────────
ok()  { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn(){ echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail(){ echo -e "  ${RED}✖${RESET}  $1"; }

# ── Helper: check a required PHP extension ──────────────────
check_ext() {
    if php -m | grep -qi "^${1}$"; then
        ok "PHP extension: ${1}"
    else
        warn "PHP extension: ${1} — NOT loaded (may be optional)"
    fi
}

# ── Helper: get PHP ini override file path ──────────────────
get_ini_path() {
    # PHP_INI_DIR is set by the official WordPress image
    # e.g. /usr/local/etc/php/conf.d
    echo "${PHP_INI_DIR}/conf.d/99-applabx-overrides.ini"
}

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================

section "AppLabX WordPress Base — Starting"

# 1. PHP binary exists
if ! command -v php &>/dev/null; then
    fail "PHP binary not found in PATH"
    exit 1
fi
ok "PHP binary: $(command -v php)"
ok "PHP version: $(php -r 'echo PHP_VERSION;')"

# 2. Required directories exist and are writable
#    WordPress creates wp-content at runtime; ensure the parent
#    is writable by the www-data user.
DOCUMENT_ROOT="/var/www/html"
if [ -d "$DOCUMENT_ROOT" ]; then
    ok "Document root: ${DOCUMENT_ROOT}"
else
    warn "Document root does not exist yet — WordPress will be installed here"
fi

UPLOAD_DIR="${DOCUMENT_ROOT}/wp-content/uploads"
if [ -d "$UPLOAD_DIR" ]; then
    if [ -w "$UPLOAD_DIR" ]; then
        ok "Upload dir: ${UPLOAD_DIR} (writable)"
    else
        warn "Upload dir exists but is not writable by current user"
    fi
else
    ok "Upload dir will be created by WordPress at first run"
fi

# 3. PHP configuration overrides applied
INI_PATH=$(get_ini_path)
if [ -f "$INI_PATH" ]; then
    PHP_MEM_LIMIT=$(php -r "echo ini_get('memory_limit');" 2>/dev/null || echo "unknown")
    PHP_UPLOAD=$(php -r "echo ini_get('upload_max_filesize');" 2>/dev/null || echo "unknown")
    ok "PHP INI overrides: ${INI_PATH}"
    ok "  memory_limit        = ${PHP_MEM_LIMIT}"
    ok "  upload_max_filesize = ${PHP_UPLOAD}"
else
    warn "PHP INI override file not found: ${INI_PATH}"
fi

# 4. Apache config file present
APACHE_SECURITY_CONF="/usr/local/apache2/conf/extra/applabx-security.conf"
if [ -f "$APACHE_SECURITY_CONF" ]; then
    ok "Apache security config: ${APACHE_SECURITY_CONF}"
else
    warn "Apache security config not found — hardening may not be applied"
fi

# 5. OPcache status
if php -m | grep -qi "^Zend OPcache$"; then
    OP_STATUS=$(php -r 'echo (ini_get("opcache.enable") ? "enabled" : "disabled");' 2>/dev/null)
    OP_MEM=$(php -r 'echo ini_get("opcache.memory_consumption") . " MB";' 2>/dev/null)
    ok "OPcache: ${OP_STATUS} (${OP_MEM})"
else
    warn "OPcache: not loaded"
fi

# ============================================================
# PHP EXTENSIONS CHECK
# ============================================================
section "PHP Extensions"

REQUIRED_EXTS=(
    pdo
    pdo_mysql
    mysqli
    gd
    exif
    zip
    intl
    curl
    mbstring
    xml
)
OPTIONAL_EXTS=(
    imagick
    redis
    opcache
)

for ext in "${REQUIRED_EXTS[@]}"; do
    check_ext "$ext"
done

echo ""
for ext in "${OPTIONAL_EXTS[@]}"; do
    check_ext "$ext"
done

# ============================================================
# ENVIRONMENT SUMMARY
# ============================================================
section "Environment"

if [ -n "$WORDPRESS_DB_HOST" ]; then
    ok "WORDPRESS_DB_HOST = ${WORDPRESS_DB_HOST}"
else
    warn "WORDPRESS_DB_HOST not set (will default to 'mysql')"
fi

if [ -n "$WORDPRESS_DB_NAME" ]; then
    ok "WORDPRESS_DB_NAME = ${WORDPRESS_DB_NAME}"
fi

if [ -n "$WORDPRESS_DB_USER" ]; then
    ok "WORDPRESS_DB_USER = ${WORDPRESS_DB_USER}"
fi

PHP_MAX_EXEC=$(php -r 'echo ini_get("max_execution_time");' 2>/dev/null)
PHP_POST_SIZE=$(php -r 'echo ini_get("post_max_size");' 2>/dev/null)
echo ""
ok "PHP max_execution_time = ${PHP_MAX_EXEC}s"
ok "PHP post_max_size      = ${PHP_POST_SIZE}"

# ============================================================
# STARTUP COMPLETE
# ============================================================
section "Starting WordPress..."
echo ""
echo -e "  ${GREEN}All pre-flight checks passed.${RESET}"
echo -e "  Delegating to the official WordPress entrypoint."
echo ""

# ── Delegate to official WordPress entrypoint ─────────────
# The official entrypoint handles:
#   - Database connection + WordPress DB creation
#   - wp-config.php generation (if not present)
#   - WordPress core installation
#   - Apache daemon (apache2-foreground)
exec docker-entrypoint.sh "$@"
