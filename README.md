<div align="center">

# Inception

<p>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/NGINX-009639?style=for-the-badge&logo=nginx&logoColor=white" />
  <img src="https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white" />
  <img src="https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white" />
  <img src="https://img.shields.io/badge/PHP_8.2-777BB4?style=for-the-badge&logo=php&logoColor=white" />
  <img src="https://img.shields.io/badge/Debian_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white" />
  <img src="https://img.shields.io/badge/42_School-000000?style=for-the-badge&logo=42&logoColor=white" />
</p>

<p><em>A production-grade containerized web infrastructure — built from scratch with Docker Compose</em></p>

</div>

---

## Overview

**Inception** is a system administration project from the [42 curriculum](https://42.fr) that implements a complete, self-contained web hosting infrastructure using Docker. Every service is built from scratch — no pre-built application images from DockerHub, only custom `Dockerfile`s on top of `debian:bookworm`.

The result is a fully functional WordPress website served over HTTPS, backed by a MariaDB database, with all credentials managed via Docker secrets and all data persisted across container restarts and VM reboots.

### Highlights

- **3 isolated containers** communicating over a private Docker bridge network
- **Custom Dockerfiles** — built from `debian:bookworm`, no pre-made app images
- **TLS 1.2 / 1.3** encryption with NGINX as the sole internet-facing service
- **Docker secrets** for all credentials — never in environment variables or image layers
- **Idempotent setup scripts** — safe to stop and restart without data loss
- **Named volumes** with bind mount driver for reliable data persistence
- **WP-CLI** for fully automated, non-interactive WordPress installation

---

## Architecture

The infrastructure follows a classic three-tier web architecture: reverse proxy → application server → database. All three tiers run in separate containers on a private Docker bridge network named `inception`.

```
                          Internet
                              │
                   HTTPS : 443 (TLS 1.2 / 1.3)
                              │
             ┌────────────────▼────────────────┐
             │              NGINX              │
             │   Web Server  &  TLS Gateway    │
             └────────────────┬────────────────┘
                              │
                   FastCGI : 9000 (internal)
                              │
             ┌────────────────▼────────────────┐       ┌─────────────────────────┐
             │    WordPress  +  PHP 8.2-FPM    │◄──────┤        MariaDB          │
             │         Application Layer       │ 3306  │      Database Layer     │
             └────────────────┬────────────────┘       └────────────┬────────────┘
                              │                                     │
                     ┌────────▼────────┐                   ┌────────▼────────┐
                     │    wp-data      │                   │    db-data      │
                     │    volume       │                   │    volume       │
                     │ /data/wordpress │                   │  /data/mariadb  │
                     └─────────────────┘                   └─────────────────┘
```

**Traffic flow:**

1. Client connects to `https://dkot.42.fr:443`
2. NGINX terminates TLS and forwards PHP requests to `wordpress:9000` via FastCGI
3. PHP-FPM processes the request, queries `mariadb:3306` as needed
4. Response travels back through NGINX to the client over TLS

Only NGINX is reachable from outside. MariaDB and PHP-FPM are completely isolated inside the Docker network.

---

## Services

### NGINX — Web Server & TLS Gateway

The only container accessible from the internet. Handles all incoming HTTPS connections on port 443, terminates TLS, and proxies PHP requests to WordPress via the FastCGI protocol. Static files are served directly from the shared `wp-data` volume.

| Property | Value |
|----------|-------|
| Base image | `debian:bookworm` |
| Exposed port | `443` (HTTPS, mapped to host) |
| TLS versions | 1.2 and 1.3 only |
| FastCGI upstream | `wordpress:9000` |
| Static files | `/var/www/html` (read-only volume mount) |

### WordPress + PHP-FPM — Application Server

Runs PHP 8.2-FPM to process WordPress PHP files. Communicates with NGINX via FastCGI on port 9000 and with MariaDB via TCP on port 3306. WP-CLI handles the full WordPress installation automatically on first startup.

| Property | Value |
|----------|-------|
| Base image | `debian:bookworm` |
| PHP version | 8.2-FPM |
| Internal port | `9000` (FastCGI, Docker network only) |
| PHP extensions | `mysql`, `curl`, `gd`, `mbstring`, `xml`, `zip` |
| Automation | WP-CLI for core install, config, and user creation |

### MariaDB — Database Backend

Stores all WordPress data: posts, users, settings, themes, and media metadata. Runs entirely on the internal Docker network — never exposed to the outside. Credentials are injected via Docker secrets at runtime.

| Property | Value |
|----------|-------|
| Base image | `debian:bookworm` |
| Internal port | `3306` (TCP, Docker network only) |
| Credentials | Docker secrets (encrypted) |
| Persistence | Named volume → `/home/dkot/data/mariadb` |

---

## Getting Started

### Prerequisites

- Linux virtual machine (Debian / Ubuntu recommended)
- [Docker Engine 24+](https://docs.docker.com/engine/install/)
- [Docker Compose v2](https://docs.docker.com/compose/install/)
- `openssl` for TLS certificate generation
- `make`

### Installation

**1. Clone the repository**

```bash
git clone https://github.com/denyskotcode/inception.git
cd inception
```

**2. Create the secrets files**

Credentials are never stored in the repository. Create them manually before the first launch:

```bash
mkdir -p secrets

# MariaDB passwords
echo "your_db_password"   > secrets/db_password.txt
echo "your_root_password" > secrets/db_root_password.txt

# WordPress admin and editor accounts
cat > secrets/credentials.txt << 'EOF'
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=your_admin_password
WP_ADMIN_EMAIL=admin@dkot.42.fr
WP_USER=editor
WP_USER_PASSWORD=your_editor_password
WP_USER_EMAIL=editor@dkot.42.fr
EOF
```

**3. Generate a self-signed TLS certificate**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout srcs/requirements/nginx/conf/dkot.42.fr.key \
    -out    srcs/requirements/nginx/conf/dkot.42.fr.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=dkot.42.fr"
```

**4. Map the domain in `/etc/hosts`**

```bash
echo "127.0.0.1 dkot.42.fr" | sudo tee -a /etc/hosts
```

**5. Build and launch everything**

```bash
make
```

The first build takes a few minutes as Docker downloads the base image and installs all packages. Once complete, the site is available at `https://dkot.42.fr`.

> **Browser warning**: The self-signed certificate will trigger a security warning. Click **Advanced → Proceed to dkot.42.fr** to continue. This is expected behavior for a local infrastructure.

---

## Usage

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make` | Full bootstrap: create data dirs → build images → start containers |
| `make up` | Build images and start all containers in detached mode |
| `make down` | Stop and remove containers (images and data are preserved) |
| `make re` | Full restart: `down` then `up` |
| `make logs` | Follow real-time logs from all three containers |
| `make ps` | Display running container status |
| `make clean` | Full teardown: containers, images, volumes, and all persisted data |

### Access Points

| Service | URL |
|---------|-----|
| Website | `https://dkot.42.fr` |
| WordPress admin | `https://dkot.42.fr/wp-admin` |

Admin credentials are defined in `secrets/credentials.txt` under `WP_ADMIN_USER` and `WP_ADMIN_PASSWORD`.

### Container Operations

```bash
# Enter a running container for inspection
docker exec -it nginx    bash
docker exec -it wordpress bash
docker exec -it mariadb  bash

# Check a specific container's logs
docker logs -f nginx

# Inspect a volume
docker volume inspect inception_wp-data
```

---

## Configuration

### Environment Variables

Non-sensitive configuration is stored in `srcs/.env` and passed to containers via `env_file`:

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN_NAME` | Domain used in NGINX virtual host | `dkot.42.fr` |
| `MYSQL_DATABASE` | WordPress database name | `wordpress` |
| `MYSQL_USER` | MariaDB application user | `wpuser` |
| `MYSQL_HOST` | MariaDB hostname (resolved by Docker DNS) | `mariadb` |
| `WP_TITLE` | WordPress site title | `Inception` |
| `WP_URL` | WordPress site URL | `https://dkot.42.fr` |
| `DATA_PATH` | Host path for named volume bind mounts | `/home/dkot/data` |

### Docker Secrets

Sensitive credentials are managed as Docker secrets — encrypted, never visible in `docker inspect`, and only accessible to containers explicitly granted access:

| File | Secret name | Used by |
|------|-------------|---------|
| `secrets/db_password.txt` | `db_password` | WordPress, MariaDB |
| `secrets/db_root_password.txt` | `db_root_password` | MariaDB |
| `secrets/credentials.txt` | `credentials` | WordPress |

Secrets are mounted at `/run/secrets/<name>` inside each container and read in shell scripts with:

```bash
DB_PASSWORD=$(cat /run/secrets/db_password)
```

### Data Persistence

All application data survives container restarts and image rebuilds. Named volumes use the `local` driver with `driver_opts` to bind data to specific host paths:

| Volume | Host path | Container path | Used by |
|--------|-----------|----------------|---------|
| `wp-data` | `/home/dkot/data/wordpress` | `/var/www/html` | WordPress (rw), NGINX (ro) |
| `db-data` | `/home/dkot/data/mariadb` | `/var/lib/mysql` | MariaDB |

Data is destroyed only by `make clean` or manual deletion of `/home/dkot/data/`.

---

## Security

| Layer | Implementation |
|-------|----------------|
| **Transport** | TLS 1.2 and 1.3 only — no plain HTTP |
| **Network isolation** | Only NGINX exposed externally on port 443 |
| **Credential management** | Docker secrets — encrypted at rest, not in `docker inspect` |
| **Process isolation** | One service per container — a compromise in one doesn't affect others |
| **Read-only mounts** | NGINX reads WordPress files via `wp-data` in read-only mode |
| **No host network** | Bridge network only — containers cannot interfere with host services |
| **Internal ports** | MariaDB (3306) and PHP-FPM (9000) reachable only inside Docker network |
| **File permissions** | WordPress files owned by `www-data`, TLS key set to mode `600` |

---

## Project Structure

```
inception/
├── Makefile                              # Build and lifecycle automation
├── srcs/
│   ├── .env                              # Non-sensitive environment variables
│   ├── docker-compose.yml               # Service, network, and volume definitions
│   └── requirements/
│       ├── mariadb/
│       │   ├── Dockerfile               # debian:bookworm + mariadb-server
│       │   ├── conf/
│       │   │   └── my.cnf               # MariaDB server configuration
│       │   └── tools/
│       │       └── db-setup.sh          # Idempotent database initialization
│       ├── nginx/
│       │   ├── Dockerfile               # debian:bookworm + nginx
│       │   └── conf/
│       │       ├── nginx.conf           # Virtual host with TLS and FastCGI config
│       │       ├── dkot.42.fr.crt       # Self-signed TLS certificate
│       │       └── dkot.42.fr.key       # TLS private key (mode 600)
│       └── wordpress/
│           ├── Dockerfile               # debian:bookworm + PHP 8.2-FPM + WP-CLI
│           ├── conf/
│           │   └── www.conf             # PHP-FPM pool configuration
│           └── tools/
│               └── wp-setup.sh          # Automated WordPress installation script
└── secrets/                             # Not tracked in git — create manually
    ├── db_password.txt
    ├── db_root_password.txt
    └── credentials.txt
```

---

## Concepts

This section explains the core infrastructure concepts behind the project's design decisions.

### Virtual Machines vs Docker Containers

A **Virtual Machine** emulates an entire physical computer including hardware. It runs a full OS with its own kernel inside a hypervisor (VirtualBox, VMware). VMs are heavy — each one needs gigabytes of disk space and significant RAM just for the OS.

**Docker containers** share the host kernel. They package only the application and its direct dependencies. Containers start in seconds and use megabytes instead of gigabytes.

| | Virtual Machine | Docker Container |
|---|---|---|
| Isolation level | Hardware (hypervisor) | Process (kernel namespaces + cgroups) |
| OS | Full OS per VM | Shared host kernel |
| Startup time | Minutes | Seconds |
| Disk footprint | Gigabytes | Megabytes |
| Portability | Low (hardware-dependent) | High (runs anywhere Docker runs) |

This project uses both: a VM for isolating the entire infrastructure from the host machine, and Docker inside the VM for isolating individual services from each other.

---

### Docker Secrets vs Environment Variables

| | Environment Variables | Docker Secrets |
|---|---|---|
| Visibility | Readable via `docker inspect`, logs, `/proc/` | Mounted at `/run/secrets/`, not in inspect |
| Storage | Plain text in process environment | Encrypted in Docker's internal store |
| Child processes | Inherited automatically | Must be read explicitly from file |
| Best for | Non-sensitive config (URLs, names, flags) | Passwords, API keys, tokens |

In this project `.env` holds non-sensitive values like `DOMAIN_NAME` and `MYSQL_DATABASE`. All passwords live in `secrets/` and are never passed as environment variables.

---

### Docker Bridge Network vs Host Network

**Host network** (`network_mode: host`) removes network isolation between a container and the host machine. A service listening on port 80 inside the container occupies port 80 on the host directly.

**Docker bridge network** creates a virtual private subnet for containers. Each service gets its own IP address and communicates with other containers by name — Docker's internal DNS resolves `mariadb` or `wordpress` automatically.

| | Host Network | Bridge Network |
|---|---|---|
| Container isolation | None | Full isolation |
| Port conflicts with host | Possible | Impossible |
| Container-to-container DNS | Unavailable | Automatic by service name |
| Security | Low | High |

The `inception` bridge network allows NGINX to reach `wordpress:9000` and WordPress to reach `mariadb:3306` — with nothing else reachable from outside.

---

### Docker Named Volumes vs Bind Mounts

**Bind mounts** directly map a host directory path into a container. The path must exist on the host and is tightly coupled to the host filesystem layout.

**Named volumes** are managed by Docker. Docker decides where to store them and tracks their lifecycle. They are portable, visible in `docker volume ls`, and inspectable with `docker volume inspect`.

This project uses named volumes with `driver_opts` to get the best of both — Docker manages the volume, but the data is physically stored at a specific host path required by the subject:

```yaml
volumes:
  wp-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/dkot/data/wordpress
```

| | Bind Mount | Named Volume |
|---|---|---|
| Managed by | User | Docker |
| `docker volume ls` | Not visible | Visible |
| `docker volume inspect` | Not available | Full metadata |
| Portability | Low (host path must exist) | High |

---

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose reference](https://docs.docker.com/compose/compose-file/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI documentation](https://wp-cli.org/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/)
- [TLS protocol — MDN](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security)

---

<div align="center">
  <sub>Built as part of the <a href="https://42.fr">42 School</a> curriculum by <a href="https://github.com/denyskotcode">dkot</a></sub>
</div>
