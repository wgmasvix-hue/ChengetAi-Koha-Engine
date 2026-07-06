# Koha Engine Interface

The bundled Koha engine exposes a script-based interface.

## Commands

- `configure` — generate `.env`, TLS assets, and Nginx configuration
- `install` — pull images, start the stack, wait for service health, and print access details
- `create-instance` — verify that the first Koha instance exists inside the Koha container
- `start` / `stop` — lifecycle management
- `backup <dir>` — dump MariaDB and archive Koha plus engine configuration data
- `restore <dir>` — restore the database, Koha state, TLS assets, and Nginx config
- `update` — pull newer images and restart the stack safely
- `uninstall [--purge]` — stop the stack, optionally deleting data volumes
- `healthcheck [--wait]` — verify every container plus the OPAC and staff HTTPS endpoints

The ChengetAi Deploy Koha plugin calls these scripts from `templates/koha/plugin.sh`.
