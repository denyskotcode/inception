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
