# Koha Engine Installation

The Koha platform is deployed through the main `chengetai` CLI:

```bash
chengetai create koha <name>
chengetai deploy <name>
```

During deployment the plugin copies the bundled engine into `deployments/<name>/engine/`, generates a deployment-specific `.env`, pulls the required container images, and starts the stack with Docker Compose.

Ports:
- `UI_PORT` → Koha OPAC
- `REST_PORT` → Koha staff interface

The engine can also be operated directly for local iteration:

```bash
cd engines/koha-engine
bin/chengetai-koha help
```
