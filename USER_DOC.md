# User Documentation

## What is this?

This project runs a WordPress website inside Docker containers on a virtual machine.
Three services work together to serve the site:

- **NGINX** — receives your browser requests, handles encryption (HTTPS)
- **WordPress** — the website itself, processes PHP and serves pages
- **MariaDB** — the database that stores all website content, users, and settings

As a user or administrator you never interact with these services directly.
Everything is accessible through the browser or simple terminal commands.

---

## Starting the project

Open a terminal on the virtual machine and run:
```bash
make
```

This single command does everything: creates required directories, builds Docker
images, and starts all three containers. Wait until the command finishes — it may
take a few minutes on first run because Docker needs to download the base image
and install all packages.

To verify everything started correctly:
```bash
make ps
```

You should see three containers with status `Up`:
```
NAME        STATUS
mariadb     Up X seconds
wordpress   Up X seconds
nginx       Up X seconds
```

---

## Stopping the project

To stop all containers (data is preserved):
```bash
make down
```

To restart after stopping:
```bash
make up
```

To stop and start fresh (rebuild images):
```bash
make re
```

---

## Accessing the website

Open a browser on the virtual machine and go to:
```
https://dkot.42.fr
```

The browser will show a security warning about the certificate. This is normal —
the project uses a self-signed certificate. Click **Advanced** and then
**Accept the Risk and Continue** (Firefox) or **Proceed to dkot.42.fr** (Chrome).

You should see the WordPress homepage.

---

## Accessing the admin panel

Go to:
```
https://dkot.42.fr/wp-admin
```

Enter the administrator credentials (see section below).
You will see the WordPress dashboard where you can manage posts, pages, users,
and settings.

---

## Finding credentials

All credentials are stored in the `secrets/` directory at the root of the project:
```
~/inception/secrets/
├── credentials.txt       ← WordPress user accounts
├── db_password.txt       ← MariaDB user password
└── db_root_password.txt  ← MariaDB root password
```

To view WordPress credentials:
```bash
cat ~/inception/secrets/credentials.txt
```

The file contains:
```
WP_ADMIN_USER=...       ← administrator login
WP_ADMIN_PASSWORD=...   ← administrator password
WP_ADMIN_EMAIL=...      ← administrator email
WP_USER=...             ← editor login
WP_USER_PASSWORD=...    ← editor password
WP_USER_EMAIL=...       ← editor email
```

The administrator account has full access to the WordPress dashboard.
The editor account can create and edit posts but cannot change site settings.

---

## Checking that services are running

**Check container status:**
```bash
make ps
```

**Follow live logs from all containers:**
```bash
make logs
```

Press `Ctrl+C` to stop following logs.

**Check logs of a specific container:**
```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

**Check that NGINX is reachable:**
```bash
curl -k https://dkot.42.fr
```

The `-k` flag skips certificate verification for the self-signed certificate.
You should see HTML output of the WordPress homepage.

**Check that the database is running:**
```bash
docker exec mariadb mysqladmin -u root -p$(cat ~/inception/secrets/db_root_password.txt) status
```

You should see `Uptime:` followed by seconds the server has been running.

**Check volumes exist and point to correct paths:**
```bash
docker volume inspect inception_db-data
docker volume inspect inception_wp-data
```

Look for `"device": "/home/dkot/data/mariadb"` and
`"device": "/home/dkot/data/wordpress"` in the output.

---

## Data persistence

All website data and database content survive container restarts and even
virtual machine reboots. Data is stored on the VM filesystem at:
```
/home/dkot/data/
├── mariadb/     ← all database files
└── wordpress/   ← all WordPress files (themes, plugins, uploads)
```

To verify persistence manually:
1. Create a post in WordPress admin panel
2. Run `make down` then `make up`
3. Refresh the website — the post should still be there

---

## Complete cleanup

To remove everything including all data (irreversible):
```bash
make clean
```

This removes all containers, images, volumes, and data files.
After this, `make` will perform a completely fresh installation.