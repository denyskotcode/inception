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
