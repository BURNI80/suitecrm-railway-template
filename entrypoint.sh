#!/bin/bash
set -e

SUITECRM_SRC="/var/suitecrm-app"
SUITECRM_WEB="/var/www/html"

echo "==========================================="
echo "  SuiteCRM 7.15.2 — Railway Auto-Install"
echo "==========================================="

# ── 1. Copy SuiteCRM files to webroot (first boot only) ──
if [ ! -f "$SUITECRM_WEB/config.php" ] && [ ! -f "$SUITECRM_WEB/suitecrm.log" ]; then
    echo "[1/5] First boot detected — copying SuiteCRM files..."
    cp -a "$SUITECRM_SRC/." "$SUITECRM_WEB/"
    chown -R www-data:www-data "$SUITECRM_WEB"
    echo "      Done."
else
    echo "[1/5] Files already present — skipping copy."
fi

# ── 2. Create persistent directories ──
echo "[2/5] Ensuring persistent directories..."
for dir in upload upload/upgrades custom modules themes cache data logs; do
    mkdir -p "$SUITECRM_WEB/$dir"
done
chown -R www-data:www-data "$SUITECRM_WEB"
echo "      Done."

# ── 3. Resolve DB connection from Railway env vars ──
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
elif [ -n "$RAILWAY_SERVICE_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_SERVICE_DOMAIN}"
else
    SITE_URL="${APP_URL:-http://localhost}"
fi

echo "[3/5] DB: ${DB_HOST}:${DB_PORT} / ${DB_NAME}  User: ${DB_USER}"
echo "      Site URL: ${SITE_URL}"

# ── 4. Generate config.php ──
echo "[4/5] Generating config.php..."

cat > /tmp/gen_config.php << 'PHPEOF'
<?php
$db_host   = getenv('GEN_DB_HOST');
$db_port   = getenv('GEN_DB_PORT');
$db_user   = getenv('GEN_DB_USER');
$db_pass   = getenv('GEN_DB_PASS');
$db_name   = getenv('GEN_DB_NAME');
$site_url  = getenv('GEN_SITE_URL');
$out_file  = getenv('GEN_OUT_FILE');

$c = "<?php\n\$sugar_config = array();\n";
$c .= "\$sugar_config['dbconfig'] = array(\n";
$c .= "    'db_host_name' => '" . addslashes($db_host) . "',\n";
$c .= "    'db_host_port' => '" . addslashes($db_port) . "',\n";
$c .= "    'db_user_name' => '" . addslashes($db_user) . "',\n";
$c .= "    'db_password'  => '" . addslashes($db_pass) . "',\n";
$c .= "    'db_name'      => '" . addslashes($db_name) . "',\n";
$c .= "    'db_type'      => 'mysql',\n";
$c .= "    'db_connector' => '',\n";
$c .= ");\n";
$c .= "\$sugar_config['site_url'] = '" . addslashes($site_url) . "';\n";
$c .= "\$sugar_config['default_theme'] = 'SuiteP';\n";
$c .= "\$sugar_config['default_language'] = 'en_us';\n";
$c .= "\$sugar_config['log_dir'] = 'logs/';\n";
$c .= "\$sugar_config['cache_dir'] = 'cache/';\n";
$c .= "\$sugar_config['upload_dir'] = 'upload/';\n";
$c .= "\$sugar_config['custom_dir'] = 'custom/';\n";
$c .= "\$sugar_config['modules_dir'] = 'modules/';\n";
$c .= "\$sugar_config['themes_dir'] = 'themes/';\n";
$c .= "\$sugar_config['template_dir'] = 'themes/';\n";
$c .= "\$sugar_config['import_dir'] = 'cache/import/';\n";
$c .= "\$sugar_config['display_errors'] = false;\n";
$c .= "\$sugar_config['error_reporting'] = true;\n";
$c .= "\$sugar_config['test'] = false;\n";
$c .= "\$sugar_config['use_php_json'] = true;\n";
$c .= "\$sugar_config['use_cookies_for_session'] = true;\n";
$c .= "\$sugar_config['http_only'] = true;\n";
$c .= "\$sugar_config['session'] = array(\n";
$c .= "    'auto_start' => false,\n";
$c .= "    'name' => 'sugar_user_theme',\n";
$c .= ");\n";
$c .= "\$sugar_config['default_date_format'] = 'm/d/Y';\n";
$c .= "\$sugar_config['default_time_format'] = 'h:i a';\n";
$c .= "\$sugar_config['default_number_grouping'] = '3';\n";
$c .= "\$sugar_config['default_decimal_symbol'] = '.';\n";
$c .= "\$sugar_config['default_currency_significant_digits'] = '2';\n";
$c .= "\$sugar_config['default_currency_name'] = 'US Dollar';\n";
$c .= "\$sugar_config['default_currency_symbol'] = '\$';\n";
$c .= "\$sugar_config['default_locale_name_format'] = 's f l';\n";
$c .= "\$sugar_config['scanner_type'] = 'files';\n";
$c .= "\$sugar_config['admin'] = array('dir_name' => 'admin', 'default_action' => 'home');\n";
$c .= "\$sugar_config['export_max_records_per_file'] = '50000';\n";
$c .= "\$sugar_config['export_max_filesize'] = '50';\n";
$c .= "\$sugar_config['import_max_records_per_file'] = '50000';\n";
$c .= "\$sugar_config['import_max_filesize'] = '50';\n";
$c .= "\$sugar_config['import_max_execution_time'] = '60';\n";
$c .= "\$sugar_config['disable_persistent_connections'] = false;\n";
$c .= "\$sugar_config['dump_max_id'] = 100000;\n";
$c .= "\$sugar_config['max_url_length'] = 2048;\n";
$c .= "\$sugar_config['tracker_max_return'] = 1000;\n";
$c .= "\$sugar_config['job_max_run_time'] = 60;\n";

file_put_contents($out_file, $c);
PHPEOF

GEN_DB_HOST="$DB_HOST" \
GEN_DB_PORT="$DB_PORT" \
GEN_DB_USER="$DB_USER" \
GEN_DB_PASS="$DB_PASS" \
GEN_DB_NAME="$DB_NAME" \
GEN_SITE_URL="$SITE_URL" \
GEN_OUT_FILE="$SUITECRM_WEB/config.php" \
php /tmp/gen_config.php

chown www-data:www-data "$SUITECRM_WEB/config.php"
chmod 640 "$SUITECRM_WEB/config.php"
echo "      Done."

# ── 5. Set permissions + start services ──
echo "[5/5] Setting permissions and starting services..."

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
chmod 640 "$SUITECRM_WEB/config.php" 2>/dev/null || true

cat > /etc/cron.d/suitecrm << CRONEOF
* * * * * cd $SUITECRM_WEB && php -f cron.php > /dev/null 2>&1
CRONEOF
chmod 0644 /etc/cron.d/suitecrm
cron

echo "==========================================="
echo "  SuiteCRM ready at: ${SITE_URL}"
echo "  Open the URL and follow the web installer"
echo "==========================================="

a2dismod mpm_event 2>/dev/null || true
a2dismod mpm_worker 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

exec apache2-foreground
