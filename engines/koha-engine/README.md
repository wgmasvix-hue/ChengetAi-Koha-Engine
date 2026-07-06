# ChengetAi Koha Engine

Production-ready bundled Koha engine for `chengetai deploy koha`.

## Stack

- Koha 24.05 (`teogramm/koha:24.05`)
- MariaDB 11
- OpenSearch 2
- Memcached
- RabbitMQ (required by the Koha container runtime)
- Nginx reverse proxy with HTTPS

The engine is copied into `deployments/<name>/engine/` by `templates/koha/plugin.sh`, configured with a deployment-specific `.env`, and then started with Docker Compose.

## Layout

```text
engines/koha-engine/
├── docker/
├── scripts/
├── templates/
├── config/
├── docs/
├── docker-compose.yml
├── engine.yml
├── .env.example
└── README.md
```

## Commands

```bash
bin/chengetai-koha configure
bin/chengetai-koha install
bin/chengetai-koha create-instance
bin/chengetai-koha start
bin/chengetai-koha stop
bin/chengetai-koha backup /path/to/backup-dir
bin/chengetai-koha restore /path/to/backup-dir
bin/chengetai-koha update
bin/chengetai-koha uninstall [--purge]
bin/chengetai-koha healthcheck [--wait]
```

## What the installer does

- validates Docker and Docker Compose
- generates persistent configuration and secrets only when missing
- creates self-signed TLS certificates when custom ones are not supplied
- pulls images and starts the Koha stack
- waits for MariaDB, Memcached, OpenSearch, RabbitMQ, Koha, and Nginx health
- relies on the Koha container startup logic to create the first Koha instance
- configures Koha to use OpenSearch and Memcached
- prints the onboarding credentials, OPAC URL, and staff URL

## Environment

Copy `.env.example` when running the engine directly, or let `scripts/configure.sh` generate `.env` automatically when the plugin deploys it.

Important variables:

- `KOHA_DOMAIN` — hostname or IP used in the returned URLs and TLS certificate
- `UI_PORT` — HTTPS port for the OPAC URL
- `STAFF_PORT` / `REST_PORT` — HTTPS port for the staff URL
- `KOHA_ADMINUSER` / `KOHA_ADMINPASS` — initial Koha onboarding credentials
- `MYSQL_*` — MariaDB credentials used by Koha
- `TLS_CERT_FILE` / `TLS_KEY_FILE` — optional custom certificate paths relative to the engine directory

## Backup and restore

`backup.sh` stores:

- `koha-db.sql.gz` — MariaDB dump
- `koha-files.tar.gz` — `/etc/koha`, `/var/lib/koha`, `/var/log/koha`
- `engine-config.tar.gz` — generated `.env`, TLS assets, and Nginx config

`restore.sh` restores the same artifacts and then restarts the stack.

## Notes

- HTTPS uses a self-signed certificate by default. Replace the generated files under `config/certs/` with public certificates if required.
- The Koha container follows the community-maintained `teogramm/koha` project, which creates the first instance automatically and supports OpenSearch through the Elasticsearch-compatible configuration flags.
