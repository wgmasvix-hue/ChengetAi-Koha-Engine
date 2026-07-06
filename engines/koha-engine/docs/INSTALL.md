# Koha Engine Installation

Deploy through the main CLI:

```bash
chengetai deploy koha
```

The plugin copies this bundled engine into `deployments/<name>/engine/`, generates a deployment-specific `.env`, creates TLS assets when needed, starts the Docker Compose stack, waits for health checks, and prints the Koha onboarding credentials plus the OPAC and staff URLs.

For direct local iteration:

```bash
cd engines/koha-engine
cp .env.example .env
bin/chengetai-koha install
```
