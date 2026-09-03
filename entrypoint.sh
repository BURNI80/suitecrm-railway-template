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
PERSISTENT_DIRS=(
    "upload"
    "upload/upgrades"
    "custom"
    "modules"
    "themes"
    "cache"
    "data"
    "logs"
)
for dir in "${PERSISTENT_DIRS[@]}"; do
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

# Site URL from Railway - check both PRIVATE and PUBLIC domain variables
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
elif [ -n "$RAILWAY_SERVICE_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_SERVICE_DOMAIN}"
else
    SITE_URL="${APP_URL:-http://localhost}"
fi

echo "[3/5] DB host: ${DB_HOST}:${DB_PORT}  db: ${DB_NAME}  user: ${DB_USER}"
echo "      Site URL: ${SITE_URL}"

# ── 4. Generate config.php ──
echo "[4/5] Generating config.php..."
php -r "
\$db_host = '${DB_HOST}';
\$db_port = '${DB_PORT}';
\$db_user = '${DB_USER}';
\$db_pass = str_replace(\"'\", \"\\\\'\", '${DB_PASS}');
\$db_name = '${DB_NAME}';
\$site_url = '${SITE_URL}';

\$config = '<?php\n';
\$config .= '\$sugar_config = array();\n';
\$config .= '\$sugar_config[\"dbconfig\"] = array(\n';
\$config .= '    \"db_host_name\" => \"' . \$db_host . '\",\n';
\$config .= '    \"db_host_port\" => \"' . \$db_port . '\",\n';
\$config .= '    \"db_user_name\" => \"' . \$db_user . '\",\n';
\$config .= '    \"db_password\"  => \"' . \$db_pass . '\",\n';
\$config .= '    \"db_name\"      => \"' . \$db_name . '\",\n';
\$config .= '    \"db_type\"      => \"mysql\",\n';
\$config .= '    \"db_connector\" => \"\",\n';
\$config .= ');\n';
\$config .= '\$sugar_config[\"site_url\"] = \"' . \$site_url . '\";\n';
\$config .= '\$sugar_config[\"default_theme\"] = \"SuiteP\";\n';
\$config .= '\$sugar_config[\"default_language\"] = \"en_us\";\n';
\$config .= '\$sugar_config[\"log_dir\"] = \"logs/\";\n';
\$config .= '\$sugar_config[\"cache_dir\"] = \"cache/\";\n';
\$config .= '\$sugar_config[\"upload_dir\"] = \"upload/\";\n';
\$config .= '\$sugar_config[\"custom_dir\"] = \"custom/\";\n';
\$config .= '\$sugar_config[\"modules_dir\"] = \"modules/\";\n';
\$config .= '\$sugar_config[\"themes_dir\"] = \"themes/\";\n';
\$config .= '\$sugar_config[\"template_dir\"] = \"themes/\";\n';
\$config .= '\$sugar_config[\"import_dir\"] = \"cache/import/\";\n';
\$config .= '\$sugar_config[\"display_errors\"] = false;\n';
\$config .= '\$sugar_config[\"error_reporting\"] = true;\n';
\$config .= '\$sugar_config[\"test\"] = false;\n';
\$config .= '\$sugar_config[\"use_php_json\"] = true;\n';
\$config .= '\$sugar_config[\"use_cookies_for_session\"] = true;\n';
\$config .= '\$sugar_config[\"http_only\"] = true;\n';
\$config .= '\$sugar_config[\"session\"] = array(\n';
\$config .= '    \"auto_start\" => false,\n';
\$config .= '    \"name\" => \"sugar_user_theme\",\n';
\$config .= ');\n';
\$config .= '\$sugar_config[\"default_date_format\"] = \"m/d/Y\";\n';
\$config .= '\$sugar_config[\"default_time_format\"] = \"h:i a\";\n';
\$config .= '\$sugar_config[\"default_number_grouping\"] = \"3\";\n';
\$config .= '\$sugar_config[\"default_decimal_symbol\"] = \".\";\n';
\$config .= '\$sugar_config[\"default_currency_significant_digits\"] = \"2\";\n';
\$config .= '\$sugar_config[\"default_currency_name\"] = \"US Dollar\";\n';
\$config .= '\$sugar_config[\"default_currency_symbol\"] = \"\\\$\";\n';
\$config .= '\$sugar_config[\"default_locale_name_format\"] = \"s f l\";\n';
\$config .= '\$sugar_config[\"scanner_type\"] = \"files\";\n';
\$config .= '\$sugar_config[\"admin\"] = array(\n';
\$config .= '    \"dir_name\" => \"admin\",\n';
\$config .= '    \"default_action\" => \"home\",\n';
\$config .= ');\n';
\$config .= '\$sugar_config[\"export_max_records_per_file\"] = \"50000\";\n';
\$config .= '\$sugar_config[\"export_max_filesize\"] = \"50\";\n';
\$config .= '\$sugar_config[\"import_max_records_per_file\"] = \"50000\";\n';
\$config .= '\$sugar_config[\"import_max_filesize\"] = \"50\";\n';
\$config .= '\$sugar_config[\"import_max_execution_time\"] = \"60\";\n';
\$config .= '\$sugar_config[\"disable_persistent_connections\"] = false;\n';
\$config .= '\$sugar_config[\"allowUserSubscribedImpersonation\"] = true;\n';
\$config .= '\$sugar_config[\"log_memory_usage\"] = false;\n';
\$config .= '\$sugar_config[\"dump_max_id\"] = 100000;\n';
\$config .= '\$sugar_config[\"max_url_length\"] = 2048;\n';
\$config .= '\$sugar_config[\"tracker_max_return\"] = 1000;\n';
\$config .= '\$sugar_config[\"job_max_run_time\"] = 60;\n';

file_put_contents('${SUITECRM_WEB}/config.php', \$config);
"
chown www-data:www-data "$SUITECRM_WEB/config.php"
chmod 640 "$SUITECRM_WEB/config.php"
echo "      Done."

# ── 5. Set permissions + start services ──
echo "[5/5] Setting permissions and starting services..."

# Railway provides PORT env - use it, default to 80
PORT="${PORT:-80}"

# Configure Apache to listen on the right port
sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf

# Generate Apache config with correct ServerName and port
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

# Cron for SuiteCRM schedulers
cat > /etc/cron.d/suitecrm << CRONEOF
* * * * * cd $SUITECRM_WEB && php -f cron.php > /dev/null 2>&1
CRONEOF
chmod 0644 /etc/cron.d/suitecrm
cron

echo "==========================================="
echo "  SuiteCRM ready at: ${SITE_URL}"
echo "  Open the URL and follow the web installer"
echo "==========================================="

# Fix: disable all MPM modules then enable only mpm_prefork
# This runs at runtime because Railway may re-enable modules at startup
a2dismod mpm_event 2>/dev/null || true
a2dismod mpm_worker 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

exec apache2-foreground
