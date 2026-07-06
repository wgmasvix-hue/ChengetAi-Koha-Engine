# Koha Engine Interface

The bundled Koha engine is file-and-script based.

## Commands

- `configure` — write the deployment `.env`
- `install` — pull images, start the stack, and wait for HTTP readiness
- `start` / `stop` — lifecycle management
- `backup <dir>` — dump the MariaDB database and archive `/var/lib/koha`
- `restore <dir>` — restore the database and Koha data archive
- `healthcheck` — probe the OPAC or staff interface over HTTP

The higher-level ChengetAi Deploy Koha plugin calls these scripts from `templates/koha/plugin.sh`.
