# Developer Documentation

## Prerequisites

The following must be installed on the virtual machine before setting up the project:

**Docker:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

**Add your user to the docker group** (to run docker without sudo):
```bash
sudo usermod -aG docker dkot
newgrp docker
```

**Verify installation:**
```bash
docker --version
docker compose version
```

---

## Project structure
```
~/inception/
├── Makefile                          ← entry point, all commands start here
├── README.md                         ← project overview and concept comparisons
├── USER_DOC.md                       ← end user documentation
├── DEV_DOC.md                        ← this file
├── .gitignore                        ← secrets/ and .env are ignored
├── secrets/                          ← never committed to git
│   ├── credentials.txt               ← WordPress user accounts
│   ├── db_password.txt               ← MariaDB wpuser password
│   └── db_root_password.txt          ← MariaDB root password
└── srcs/
    ├── .env                          ← non-sensitive environment variables
    ├── docker-compose.yml            ← orchestrates all three services
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/my.cnf           ← MariaDB server configuration
        │   └── tools/db-setup.sh     ← database initialization script
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/nginx.conf       ← virtual server configuration
        │   ├── conf/dkot.42.fr.crt  ← TLS certificate
        │   └── conf/dkot.42.fr.key  ← TLS private key
        └── wordpress/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/www.conf         ← PHP-FPM pool configuration
            └── tools/wp-setup.sh     ← WordPress installation script
```

---

## Setting up from scratch

### Step 1 — Clone the repository
```bash
git clone <repository_url> ~/inception
cd ~/inception
```

### Step 2 — Create secrets

These files are ignored by git and must be created manually on each machine:
```bash
mkdir -p ~/inception/secrets

# MariaDB wpuser password
echo "your_db_password" > ~/inception/secrets/db_password.txt

# MariaDB root password
echo "your_root_password" > ~/inception/secrets/db_root_password.txt

# WordPress user accounts
cat > ~/inception/secrets/credentials.txt << EOF
WP_ADMIN_USER=yourname
WP_ADMIN_PASSWORD=your_admin_password
WP_ADMIN_EMAIL=yourname@dkot.42.fr
WP_USER=editor42
WP_USER_PASSWORD=your_editor_password
WP_USER_EMAIL=editor@dkot.42.fr
EOF
```

Rules for credentials:
- `WP_ADMIN_USER` must not contain `admin`, `Admin`, `administrator`, or `Administrator`
- All passwords should be strong (mix of letters, numbers, symbols)

### Step 3 — Verify .env
```bash
cat ~/inception/srcs/.env
```

It should contain:
```
DOMAIN_NAME=dkot.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_URL=https://dkot.42.fr
DATA_PATH=/home/dkot/data
```

### Step 4 — Generate SSL certificate
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ~/inception/srcs/requirements/nginx/conf/dkot.42.fr.key \
    -out ~/inception/srcs/requirements/nginx/conf/dkot.42.fr.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=dkot.42.fr"
```

### Step 5 — Configure domain resolution
```bash
echo "127.0.0.1 dkot.42.fr" | sudo tee -a /etc/hosts
```

Verify:
```bash
grep dkot.42.fr /etc/hosts
```

### Step 6 — Build and launch
```bash
make
```

---

## Makefile commands

| Command | What it does |
|---------|-------------|
| `make` | `setup` + `up` — full start from scratch |
| `make setup` | Creates `/home/dkot/data/mariadb` and `/home/dkot/data/wordpress` |
| `make up` | Builds images and starts all containers in background |
| `make down` | Stops and removes containers, preserves volumes and images |
| `make re` | `down` + `up` — rebuild and restart |
| `make logs` | Follow logs from all containers in real time |
| `make ps` | Show status of all project containers |
| `make clean` | Remove containers, images, volumes, and all data files |

---

## Managing containers

**Enter a running container:**
```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash
```

**Check logs of a specific container:**
```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

**Inspect a container (environment, mounts, network):**
```bash
docker inspect mariadb
docker inspect wordpress
docker inspect nginx
```

**Rebuild a single service without restarting others:**
```bash
docker compose -f srcs/docker-compose.yml build wordpress
docker compose -f srcs/docker-compose.yml up -d wordpress
```

**Check network:**
```bash
docker network ls
docker network inspect inception_inception
```

You should see all three containers listed as connected to this network.

---

## Managing volumes

**List project volumes:**
```bash
docker volume ls | grep inception
```

Expected output:
```
local     inception_db-data
local     inception_wp-data
```

**Inspect a volume (verify host path):**
```bash
docker volume inspect inception_db-data
docker volume inspect inception_wp-data
```

Look for `"device"` field — it must show `/home/dkot/data/mariadb` and
`/home/dkot/data/wordpress` respectively. This is verified during evaluation.

**Check data on host directly:**
```bash
ls /home/dkot/data/mariadb/    # MariaDB database files
ls /home/dkot/data/wordpress/  # WordPress installation files
```

---

## Where data is stored and how it persists

Docker named volumes in this project use `driver_opts` with `type: none` and
`o: bind` to store data at specific host paths:
```
/home/dkot/data/
├── mariadb/     ← mounted at /var/lib/mysql inside mariadb container
└── wordpress/   ← mounted at /var/www/html inside wordpress and nginx containers
```

Data survives:
- `make down` + `make up` — containers restart, data intact
- `docker compose down` — same
- Virtual machine reboot — data is on VM filesystem, persists across reboots

Data is destroyed only by:
- `make clean` — explicitly removes contents of both data directories
- Manual `rm -rf /home/dkot/data/`

The setup scripts are idempotent — if data already exists when containers start,
initialization is skipped. `db-setup.sh` checks for existing database files,
`wp-setup.sh` checks with `wp core is-installed` before reinstalling.

---

## Modifying a service port (evaluation scenario)

If asked to change a service port during evaluation, for example changing
PHP-FPM from port 9000 to port 9001:

**1. Change in `www.conf`:**
```ini
listen = 0.0.0.0:9001
```

**2. Change in `nginx.conf`:**
```nginx
fastcgi_pass wordpress:9001;
```

**3. Change in `docker-compose.yml`:**
```yaml
expose:
  - "9001"
```

**4. Rebuild and restart:**
```bash
make re
```

The same approach applies to any service configuration change —
edit the relevant config file, then `make re` to apply.

---

## Troubleshooting

**Containers exit immediately after starting:**
```bash
docker logs wordpress
docker logs mariadb
```
Read the error message. Common causes: wrong secret file path, MariaDB not ready,
missing directory at `/home/dkot/data/`.

**WordPress shows installation page instead of site:**
WordPress is not installed. Check if MariaDB was ready when WordPress started:
```bash
docker logs wordpress | grep "MariaDB"
```
If MariaDB was not ready, run `make re` to restart.

**Browser shows "connection refused" on port 443:**
NGINX container is not running. Check:
```bash
make ps
docker logs nginx
```

**Permission denied errors in WordPress container:**
Data directory ownership issue. Fix:
```bash
sudo chown -R www-data:www-data /home/dkot/data/wordpress
```

**Volume device path not found error on `make up`:**
Data directories do not exist. Run:
```bash
make setup
```
Then retry `make up`.