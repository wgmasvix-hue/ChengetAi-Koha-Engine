# ChengetAi Koha Engine

Bundled deployment engine for running Koha through the main `chengetai` CLI.

It provisions a Koha stack with:
- `digibib/koha` for the application
- `mariadb` for the database
- `memcached` for caching
- `elasticsearch` for search indexing

The main entrypoint is `bin/chengetai-koha`, which wraps the scripts in `scripts/`:

```bash
bin/chengetai-koha configure
bin/chengetai-koha install
bin/chengetai-koha start
bin/chengetai-koha stop
bin/chengetai-koha backup /path/to/backup-dir
bin/chengetai-koha restore /path/to/backup-dir
bin/chengetai-koha healthcheck
```

The ChengetAi Deploy Koha plugin copies this engine into `deployments/<name>/engine/`, writes a per-deployment `.env`, and manages the lifecycle from there.
