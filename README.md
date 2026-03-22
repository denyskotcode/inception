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
