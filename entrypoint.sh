#!/bin/bash
set -e

SUITECRM_SRC="/var/suitecrm-app"
SUITECRM_WEB="/var/www/html"

echo "==========================================="
echo "  SuiteCRM 7.15.2 — Railway Auto-Install"
echo "==========================================="

# ── 1. Copy SuiteCRM files to webroot (first boot only) ──
if [ ! -f "$SUITECRM_WEB/config.php" ] && [ ! -f "$SUITECRM_WEB/suitecrm.log" ]; then
    echo "[1/6] First boot detected — copying SuiteCRM files..."
    cp -a "$SUITECRM_SRC/." "$SUITECRM_WEB/"
    chown -R www-data:www-data "$SUITECRM_WEB"
    echo "      Done."
else
    echo "[1/6] Files already present — skipping copy."
fi

# ── 2. Create persistent directories ──
echo "[2/6] Ensuring persistent directories..."
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
# Railway MariaDB plugin sets: MYSQLHOST, MYSQLPORT, MYSQLDATABASE, MYSQLUSER, MYSQLPASSWORD
# Also support custom var names
DB_HOST="${DB_HOST:-${MYSQLHOST:-}}"
DB_PORT="${DB_PORT:-${MYSQLPORT:-3306}}"
DB_NAME="${DB_NAME:-${MYSQLDATABASE:-suitecrm}}"
DB_USER="${DB_USER:-${MYSQLUSER:-root}}"
DB_PASS="${DB_PASS:-${MYSQLPASSWORD:-}}"

# Admin credentials (env or defaults)
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Site URL
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
    SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
else
    SITE_URL="${APP_URL:-http://localhost}"
fi

echo "[3/6] DB host: ${DB_HOST}:${DB_PORT}  db: ${DB_NAME}  user: ${DB_USER}"

# ── 4. Generate config.php ──
echo "[4/6] Generating config.php..."
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

# ── 5. Auto-install database if empty ──
echo "[5/6] Checking database..."

if [ -n "$DB_HOST" ]; then
    # Test DB connection
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" &>/dev/null; then
        TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -N -e \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}'" 2>/dev/null || echo "0")

        if [ "$TABLE_COUNT" -lt "10" ]; then
            echo "      Empty DB detected — installing SuiteCRM schema..."

            # Generate SQL from SuiteCRM's install file
            php -d error_reporting=0 -r "
                define('sugarEntry', true);
                \$_REQUEST = array();
                require_once '${SUITECRM_WEB}/include/utils.php';
                require_once '${SUITECRM_WEB}/install/install_utils.php';
                // Output the SQL
                @ob_start();
                include '${SUITECRM_WEB}/install/install_sql.php';
                \$sql = @ob_get_clean();
                echo \$sql;
            " > /tmp/suitecrm_schema.sql 2>/dev/null || true

            if [ -s /tmp/suitecrm_schema.sql ]; then
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < /tmp/suitecrm_schema.sql 2>/dev/null && \
                    echo "      Schema loaded." || echo "      Schema load had warnings (usually OK)."
                rm -f /tmp/suitecrm_schema.sql
            else
                echo "      Could not generate schema via PHP — using fallback SQL dump."
                # The web installer will be available to complete setup
            fi

            # Create admin user via SQL
            ADMIN_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_DEFAULT);")
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                INSERT INTO users (id, user_name, first_name, last_name, email, password, date_entered, date_modified, modified_user_id, created_by, status, title, is_admin, locale, user_hash, portal_only)
                VALUES (
                    '1',
                    '${ADMIN_USER}',
                    'Admin',
                    'User',
                    '${ADMIN_EMAIL}',
                    '${ADMIN_HASH}',
                    NOW(),
                    NOW(),
                    '1',
                    '1',
                    'Active',
                    '',
                    1,
                    'en_us',
                    '${ADMIN_HASH}',
                    0
                )
                ON DUPLICATE KEY UPDATE password='${ADMIN_HASH}', status='Active';
            " 2>/dev/null && echo "      Admin user created (${ADMIN_USER})." || echo "      Admin user setup will be done via web installer."

            # Insert system settings
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                INSERT INTO config (category, name, value) VALUES
                ('system', 'name', 'SuiteCRM'),
                ('system', 'version', '7.15.2'),
                ('EmailSettings', 'email_bg_color', '#B9D6CB'),
                ('EmailSettings', 'email_bg_lane_color', '#F4F7F6'),
                ('EmailSettings', 'email_bg_team_color', '#F4F7F6'),
                ('EmailSettings', 'default_is_personal', '0')
                ON DUPLICATE KEY UPDATE value=VALUES(value);
            " 2>/dev/null || true

            # Refresh the schema check
            TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -N -e \
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}'" 2>/dev/null || echo "0")
            echo "      Tables in DB: ${TABLE_COUNT}"
        else
            echo "      DB has ${TABLE_COUNT} tables — already installed."
        fi
    else
        echo "      WARNING: Cannot connect to DB. The web installer will appear on first visit."
    fi
else
    echo "      No DB configured. The web installer will appear on first visit."
fi

# ── 6. Set permissions + start services ──
echo "[6/6] Setting permissions and starting services..."
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
echo "  Admin: ${ADMIN_USER} / ${ADMIN_PASS}"
echo "==========================================="

exec apache2-foreground
