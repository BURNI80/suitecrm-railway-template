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
cat > "$SUITECRM_WEB/config.php" << 'CONFEOF'
<?php
$sugar_config = array();
CONFEOF

cat >> "$SUITECRM_WEB/config.php" << CONFEOF
$sugar_config['dbconfig'] = array(
    'db_host_name' => '${DB_HOST}',
    'db_host_port' => '${DB_PORT}',
    'db_user_name' => '${DB_USER}',
    'db_password'  => '${DB_PASS}',
    'db_name'      => '${DB_NAME}',
    'db_type'      => 'mysql',
    'db_connector' => '',
);
$sugar_config['site_url'] = '${SITE_URL}';
$sugar_config['default_theme'] = 'SuiteP';
$sugar_config['default_language'] = 'en_us';
$sugar_config['log_dir'] = 'logs/';
$sugar_config['cache_dir'] = 'cache/';
$sugar_config['upload_dir'] = 'upload/';
$sugar_config['custom_dir'] = 'custom/';
$sugar_config['modules_dir'] = 'modules/';
$sugar_config['themes_dir'] = 'themes/';
$sugar_config['template_dir'] = 'themes/';
$sugar_config['import_dir'] = 'cache/import/';
$sugar_config['display_errors'] = false;
$sugar_config['error_reporting'] = true;
$sugar_config['test'] = false;
$sugar_config['use_php_json'] = true;
$sugar_config['use_cookies_for_session'] = true;
$sugar_config['http_only'] = true;
$sugar_config['session'] = array(
    'auto_start' => false,
    'name' => 'sugar_user_theme',
);
$sugar_config['default_date_format'] = 'm/d/Y';
$sugar_config['default_time_format'] = 'h:i a';
$sugar_config['default_number_grouping'] = '3';
$sugar_config['default_decimal_symbol'] = '.';
$sugar_config['default_currency_significant_digits'] = '2';
$sugar_config['default_currency_name'] = 'US Dollar';
$sugar_config['default_currency_symbol'] = '\$';
$sugar_config['default_locale_name_format'] = 's f l';
$sugar_config['scanner_type'] = 'files';
$sugar_config['admin'] = array(
    'dir_name' => 'admin',
    'default_action' => 'home',
);
$sugar_config['css'] = array(
    'production' => 'grp_css',
    'developer' => 'grp_css',
    'cache_dir' => 'cache/themes/',
);
$sugar_config['javascript'] = array(
    'production' => 'grp_javascript',
    'developer' => 'grp_javascript',
    'cache_dir' => 'cache/js/',
);
$sugar_config['export_max_records_per_file'] = '50000';
$sugar_config['export_max_filesize'] = '50';
$sugar_config['import_max_records_per_file'] = '50000';
$sugar_config['import_max_filesize'] = '50';
$sugar_config['import_max_execution_time'] = '60';
$sugar_config['disable_persistent_connections'] = false;
$sugar_config['allowUserSubscribedImpersonation'] = true;
$sugar_config['log_memory_usage'] = false;
$sugar_config['dump_max_id'] = 100000;
$sugar_config['max_url_length'] = 2048;
$sugar_config['tracker_max_return'] = 1000;
$sugar_config['job_max_run_time'] = 60;
$sugar_config['impersonation'] = array(
    'admin_role_id' => '1',
);
$sugar_config['aod_settings'] = array(
    'max_notification_number' => 10,
);
$sugar_config['email_enable_auto_attachments'] = true;
$sugar_config['email_personal_to_multiple'] = true;
$sugar_config['email_marketing_track'] = true;
$sugar_config['calendar_publish_delimiter'] = ',';
$sugar_config['allow_api_updating_own_info'] = false;
$sugar_config['allow_api_delete_modules'] = false;
$sugar_config['default_module_favicon'] = false;
$sugar_config['email_allow_external_domains'] = false;
$sugar_config['email_critical_errors'] = false;
$sugar_config['email_enable_ldap'] = false;
$sugar_config['email_templates_external'] = false;
$sugar_config['email_force_ignore_savemodal'] = false;
$sugar_config['mailer_options'] = array(
    'SMTPAuth' => '',
    'SMTPAutoTLS' => '',
    'SMTPSecure' => '',
);
CONFEOF

chown www-data:www-data "$SUITECRM_WEB/config.php"
chmod 640 "$SUITECRM_WEB/config.php"
echo "      Done."

# ── 5. Set permissions + start services ──
echo "[5/5] Setting permissions and starting services..."
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

exec apache2-foreground
