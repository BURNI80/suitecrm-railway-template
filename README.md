# SuiteCRM 7.15.2 on Railway

> Fully automated deployment of [SuiteCRM 7](https://suitecrm.com) — the open-source CRM fork of SugarCRM — on Railway with MariaDB, persistent storage, and zero manual configuration.

---

## What's Included

| Component | Version | Notes |
|-----------|---------|-------|
| **SuiteCRM** | 7.15.2 (ESR) | Latest Extended Support Release |
| **PHP** | 8.2 | Apache + all required extensions |
| **MariaDB** | 10.11 (Railway) | Managed database, auto-provisioned |
| **Cron** | System cron | SuiteCRM scheduler (workflows, emails, etc.) |

### Features
- **Zero-config deployment** — DB credentials auto-injected, admin user auto-created
- **Persistent storage** — uploads, custom modules, themes, and cache survive restarts
- **Auto-install** — database schema loaded on first boot
- **Apache mod_rewrite** — clean URLs out of the box
- **OPcache** — optimized PHP performance
- **Security headers** — X-Content-Type-Options, X-Frame-Options, X-XSS-Protection

---

## Estimated Cost

| Resource | Est. Usage | Cost |
|----------|------------|------|
| SuiteCRM (PHP/Apache) | 512 MB RAM | ~$2-3/mo |
| MariaDB (Railway) | 1 GB disk | ~$1-2/mo |
| **Total** | | **~$3-5/mo** |

> Fits comfortably within Railway's $5/mo Hobby plan credit.

---

## Quick Deploy

1. **Click "Deploy on Railway"** (or use this repo)
2. Railway auto-creates MariaDB and connects it
3. Wait for the first deploy to complete (~2-3 min)
4. Click the public URL — SuiteCRM loads immediately
5. Log in with `admin` / `admin`

**That's it.** No environment variables to configure manually.

---

## Environment Variables

All variables are auto-set by Railway. You can override them if needed:

| Variable | Default | Description |
|----------|---------|-------------|
| `ADMIN_USER` | `admin` | Admin username |
| `ADMIN_PASS` | `admin` | Admin password (**change after first login!**) |
| `ADMIN_EMAIL` | `admin@example.com` | Admin email address |
| `APP_URL` | Auto-detected | Public URL (set automatically from Railway domain) |

> **Important:** Change the admin password immediately after first login via **Admin → Users**.

---

## Post-Deployment Steps

### 1. Change Admin Password
Go to **Admin → Users → Admin User** and set a strong password.

### 2. Configure System Settings
Navigate to **Admin → System Settings** and set:
- **System Name** — your company/team name
- **Default Currency** — your local currency
- **Default Timezone** — your timezone
- **Email Settings** — configure outgoing email (SMTP)

### 3. Set Up Email (Optional)
Go to **Admin → Email Settings** to configure:
- Inbound email (IMAP)
- Outbound email (SMTP)
- Email notifications

### 4. Configure Cron Jobs (Already Running)
The template includes a cron job that runs every minute for:
- Workflow automation
- Email sending
- Scheduled reports
- Scheduler tasks

No action needed — it's pre-configured.

### 5. Install Additional Modules (Optional)
SuiteCRM has a module loader at **Admin → Module Loader**. Upload `.zip` module packages to extend functionality.

---

## Custom Domains

Railway auto-assigns `<service>.up.railway.app`. To use a custom domain:

1. In Railway dashboard, go to your service → **Settings → Networking**
2. Click **Custom Domain** and enter your domain
3. Add the CNAME record shown to your DNS provider
4. Wait for TLS certificate provisioning (~1 min)

The `site_url` in `config.php` updates automatically on next deploy.

---

## Upgrading

To upgrade SuiteCRM to a newer version:

1. Back up your database (export via **Admin → Backups** or MySQL dump)
2. Update the `Dockerfile` to point to the new SuiteCRM release URL
3. Redeploy — the entrypoint will detect the new version and handle file updates
4. Visit the SuiteCRM upgrade wizard if prompted

---

## File Structure

```
/
├── Dockerfile          # PHP 8.2 + Apache + SuiteCRM
├── entrypoint.sh       # Auto-install + config generation
├── apache.conf         # Apache vhost config with mod_rewrite
├── php.ini             # Optimized PHP settings
├── .dockerignore       # Docker build exclusions
├── .gitignore          # Git exclusions
└── README.md           # This file
```

### Persistent Data (Railway Volumes)

| Path | Purpose |
|------|---------|
| `/var/www/html/upload/` | Uploaded files, attachments, documents |
| `/var/www/html/custom/` | Custom modules, vardefs, language files |
| `/var/www/html/modules/` | Module loader installed modules |
| `/var/www/html/themes/` | Custom themes |
| `/var/www/html/cache/` | Compiled templates, JS cache |
| `/var/www/html/data/` | Module data files |
| `/var/www/html/logs/` | SuiteCRM logs |

---

## Troubleshooting

### "Cannot connect to database"
- Ensure the MariaDB service is running in your Railway project
- Check that `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, `MYSQLPASSWORD` are set
- Railway auto-sets these when you add a MariaDB database

### "Permission denied" errors
The entrypoint auto-fixes permissions on each boot. If issues persist:
- Check that volumes are mounted correctly
- The container runs as `www-data` (UID 33)

### White screen / PHP errors
- Check Railway logs for the SuiteCRM service
- Look for `/var/www/html/logs/suitecrm.log`
- Set `display_errors = On` in `php.ini` for debugging (not in production!)

### Cron not working
The cron job runs every minute. Verify with:
```bash
# In Railway shell
crontab -l
```

### Slow performance
- OPcache is pre-configured
- For high traffic, increase `memory_limit` in `php.ini`
- Consider adding Redis for session caching

---

## Tech Stack

- **Runtime:** PHP 8.2 on Apache 2.4 (Debian Bookworm)
- **Database:** MariaDB 10.11 (Railway managed)
- **Image:** `php:8.2-apache` base image
- **SuiteCRM:** 7.15.2 ESR from [GitHub](https://github.com/SuiteCRM/SuiteCRM/releases/tag/v7.15.2)
- **License:** [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html) (SuiteCRM upstream)

---

## Links

- [SuiteCRM Official Website](https://suitecrm.com)
- [SuiteCRM Documentation](https://docs.suitecrm.com)
- [SuiteCRM GitHub](https://github.com/SuiteCRM/SuiteCRM)
- [Railway Documentation](https://docs.railway.com)
