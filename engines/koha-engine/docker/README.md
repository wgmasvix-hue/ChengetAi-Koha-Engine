# Docker customizations

No custom Dockerfile is required for the bundled Koha engine.

The engine uses upstream images directly:
- `teogramm/koha:24.05`
- `mariadb:11`
- `opensearchproject/opensearch:2.19.1`
- `memcached:1.6-alpine`
- `rabbitmq:3.13-management-alpine`
- `nginx:1.27-alpine`
