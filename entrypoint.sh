#!/bin/bash
set -e

SUITECRM_SRC="/var/suitecrm-app"
SUITECRM_WEB="/var/www/html"

echo "==========================================="
echo "  SuiteCRM 7.15.2 — Railway Auto-Install"
echo "==========================================="

# ── 1. Copy SuiteCRM files to webroot (first boot only) ──
if [ ! -f "$SUITECRM_WEB/config.php" ] && [ ! -f "$SUITECRM_WEB/suitecrm.log" ]; then
    echo "[1/4] First boot detected — copying SuiteCRM files..."
    cp -a "$SUITECRM_SRC/." "$SUITECRM_WEB/"
    chown -R www-data:www-data "$SUITECRM_WEB"
    echo "      Done."
else
    echo "[1/4] Files already present — skipping copy."
fi

# ── 2. Create persistent directories ──
echo "[2/4] Ensuring persistent directories..."
for dir in upload upload/upgrades custom modules themes cache data logs; do
    mkdir -p "$SUITECRM_WEB/$dir"
done
chown -R www-data:www-data "$SUITECRM_WEB"
echo "      Done."

# ── 3. Resolve DB connection + site config ──
DB_HOST="${DB_HOST:-${MYSQLHOST:-}}"
DB_PORT="${DB_PORT:-${MYSQLPORT:-3306}}"
DB_NAME="${DB_NAME:-${MYSQLDATABASE:-suitecrm}}"
DB_USER="${DB_USER:-${MYSQLUSER:-root}}"
DB_PASS="${DB_PASS:-${MYSQLPASSWORD:-}}"

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
    HOST_NAME="${RAILWAY_PUBLIC_DOMAIN}"
elif [ -n "$RAILWAY_SERVICE_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_SERVICE_DOMAIN}"
    HOST_NAME="${RAILWAY_SERVICE_DOMAIN}"
else
    SITE_URL="${APP_URL:-http://localhost}"
    HOST_NAME="localhost"
fi

echo "[3/4] DB: ${DB_HOST}:${DB_PORT} / ${DB_NAME}  User: ${DB_USER}"
echo "      Site URL: ${SITE_URL}"

# ── 4. Auto-install if first boot ──
if [ ! -f "$SUITECRM_WEB/config.php" ] && [ ! -f "$SUITECRM_WEB/suitecrm.log" ]; then
    echo "[4/4] Running silent install..."

    # Write config_si.php for SuiteCRM silent installer
    cat > "$SUITECRM_WEB/config_si.php" << SIEOF
<?php
\$sugar_config_si = array(
    'setup_db_type'                    => 'mysql',
    'setup_db_host_name'               => '${DB_HOST}',
    'setup_db_port_num'                => '${DB_PORT}',
    'setup_db_database_name'           => '${DB_NAME}',
    'setup_db_admin_user_name'         => '${DB_USER}',
    'setup_db_admin_password'          => '${DB_PASS}',
    'setup_db_create_database'         => 0,
    'setup_db_drop_tables'             => 0,
    'setup_db_username_is_privileged'  => 1,
    'setup_site_url'                   => '${SITE_URL}',
    'setup_site_admin_user_name'       => '${ADMIN_USER}',
    'setup_site_admin_password'        => '${ADMIN_PASS}',
    'setup_system_name'                => 'SuiteCRM',
    'demoData'                         => 'no',
    'default_language'                 => 'en_us',
    'default_date_format'              => 'm/d/Y',
    'default_time_format'              => 'h:i a',
    'setup_site_sugarbeet_anonymous_stats'   => 0,
    'setup_site_sugarbeet_automatic_checks'  => 0,
);
SIEOF
    chown www-data:www-data "$SUITECRM_WEB/config_si.php"

    # Write auto-install PHP script
    cat > "$SUITECRM_WEB/auto_install.php" << INSTALLEOF
<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');

\$_SERVER['HTTP_HOST']   = '${HOST_NAME}';
\$_SERVER['SERVER_NAME'] = '${HOST_NAME}';
\$_SERVER['REQUEST_URI'] = '/install.php';
\$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';
\$_SERVER['REQUEST_METHOD'] = 'GET';
\$_SERVER['QUERY_STRING'] = '';
\$_SERVER['SERVER_PORT'] = '443';
\$_SERVER['HTTPS'] = 'on';

\$_REQUEST = array(
    'goto' => 'SilentInstall',
    'cli'  => 'true',
);

chdir('${SUITECRM_WEB}');
require_once 'install.php';
INSTALLEOF
    chown www-data:www-data "$SUITECRM_WEB/auto_install.php"

    # Run silent install
    cd "$SUITECRM_WEB"
    php auto_install.php 2>&1 || true
    cd /

    # Cleanup: remove installer files
    rm -f "$SUITECRM_WEB/config_si.php"
    rm -f "$SUITECRM_WEB/auto_install.php"
    rm -rf "$SUITECRM_WEB/install" 2>/dev/null || true
    chown -R www-data:www-data "$SUITECRM_WEB"
    echo "      Install attempt finished."
else
    echo "[4/4] Already installed — skipping."
fi

# ── 5. Configure Apache and start ──
PORT="${PORT:-80}"
sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf

cat > /etc/apache2/sites-available/000-default.conf << APACHEEOF
<VirtualHost *:${PORT}>
    DocumentRoot /var/www/html
    ServerName ${RAILWAY_PUBLIC_DOMAIN:-localhost}

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteBase /

            RewriteCond %{DOCUMENT_ROOT}/config.php !-f
            RewriteRule ^(.*)$ /install.php [L]

            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ index.php?entryPoint=\$1 [QSA,L]
        </IfModule>
    </Directory>

    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options SAMEORIGIN
        Header always set X-XSS-Protection "1; mode=block"
    </IfModule>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHEEOF

chown -R www-data:www-data "$SUITECRM_WEB"
find "$SUITECRM_WEB" -type d -exec chmod 775 {} \;
find "$SUITECRM_WEB" -type f -exec chmod 664 {} \;
[ -f "$SUITECRM_WEB/config.php" ] && chmod 640 "$SUITECRM_WEB/config.php"

cat > /etc/cron.d/suitecrm << CRONEOF
* * * * * cd $SUITECRM_WEB && php -f cron.php > /dev/null 2>&1
CRONEOF
chmod 0644 /etc/cron.d/suitecrm
cron

echo "==========================================="
echo "  SuiteCRM ready at: ${SITE_URL}"
echo "==========================================="

a2dismod mpm_event 2>/dev/null || true
a2dismod mpm_worker 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

exec apache2-foreground
