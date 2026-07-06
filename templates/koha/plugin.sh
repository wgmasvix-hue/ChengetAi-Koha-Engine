#!/usr/bin/env bash
# Koha platform plugin for ChengetAi Deploy.

# shellcheck disable=SC2034  # PLUGIN_* consumed by the CLI after sourcing
PLUGIN_NAME="koha"
PLUGIN_DESCRIPTION="Koha library management system"
PLUGIN_STATUS="available"

engine_source_dir() {
    echo "$CHENGETAI_HOME/engines/koha-engine"
}

engine_dir() {
    echo "$DEPLOY_DIR/engine"
}

ui_port() {
    echo "${UI_PORT:-4000}"
}

staff_port() {
    echo "${STAFF_PORT:-${REST_PORT:-8080}}"
}

require_engine() {
    if [ ! -f "$(engine_dir)/docker-compose.yml" ] || [ ! -x "$(engine_dir)/bin/chengetai-koha" ]; then
        error "Deployment '$DEPLOY_NAME' has not been deployed yet. Run: chengetai deploy $DEPLOY_NAME"
    fi
}

pcompose() {
    docker compose -p "chengetai-$DEPLOY_NAME" \
        -f "$(engine_dir)/docker-compose.yml" \
        --env-file "$(engine_dir)/.env" \
        --project-directory "$(engine_dir)" "$@"
}

sync_engine() {
    local source target
    source=$(engine_source_dir)
    target=$(engine_dir)

    [ -d "$source" ] || error "Bundled Koha engine not found: $source"
    mkdir -p "$target"
    cp -a "$source/." "$target/"
    chmod +x "$target/bin/chengetai-koha" "$target/scripts/"*.sh
}

load_engine_env() {
    local env_file
    env_file="$(engine_dir)/.env"
    [ -f "$env_file" ] || error "Koha engine is not configured. Re-run: chengetai deploy $DEPLOY_NAME"
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
}

koha_admin_user_default() {
    local candidate
    candidate="${KOHA_ADMINUSER:-${ADMIN_EMAIL%%@*}}"
    candidate=$(echo "$candidate" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
    echo "${candidate:-admin}"
}

plugin_server_host() {
    load_engine_env
    echo "${KOHA_DOMAIN:-localhost}"
}

plugin_urls() {
    local host
    host=$(plugin_server_host)
    echo "  OPAC           : https://${host}:$(ui_port)"
    echo "  Staff interface: https://${host}:$(staff_port)"
}

configure_engine() {
    sync_engine


    KOHA_ADMINUSER="$(koha_admin_user_default)" \
    DEPLOY_NAME="$DEPLOY_NAME" \
    UI_PORT="$(ui_port)" \
    REST_PORT="$(staff_port)" \
    STAFF_PORT="$(staff_port)" \
    INSTITUTION="$INSTITUTION" \
    REPOSITORY="$REPOSITORY" \
    ADMIN_EMAIL="$ADMIN_EMAIL" \
    ADMIN_FIRST_NAME="$ADMIN_FIRST_NAME" \
    ADMIN_LAST_NAME="$ADMIN_LAST_NAME" \
    ADMIN_PASS="${ADMIN_PASS:-}" \
    KOHA_DOMAIN="${KOHA_DOMAIN:-${SERVER_IP:-localhost}}" \
    TZ="${TZ:-UTC}" \
        bash "$(engine_dir)/scripts/configure.sh"
}

plugin_deploy() {
    require_docker
    configure_engine

    info "Installing Koha services..."
    bash "$(engine_dir)/scripts/install.sh"

    echo ""
    info "Koha deployment complete."
    echo ""
    plugin_urls
    echo ""
}

plugin_start() {
    require_docker
    require_engine
    bash "$(engine_dir)/scripts/start.sh"
    echo ""
    info "Services started."
    echo ""
    plugin_urls
    echo ""
}

plugin_stop() {
    require_docker
    require_engine
    bash "$(engine_dir)/scripts/stop.sh"
    echo ""
    info "Services stopped. Data volumes are preserved."
    echo "Start again with: chengetai start $DEPLOY_NAME"
    echo ""
}

plugin_restart() {
    require_docker
    require_engine
    pcompose restart
    echo ""
    info "Services restarted."
    echo ""
    plugin_urls
    echo ""
}

plugin_status() {
    require_docker
    require_engine
    pcompose ps
    echo ""
    bash "$(engine_dir)/scripts/healthcheck.sh"
    echo ""
}

plugin_logs() {
    require_docker
    require_engine
    pcompose logs --tail=200 -f "$@"
}

plugin_backup() {
    require_docker
    require_engine

    local dest
    dest="$DEPLOY_DIR/backups/chengetai-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dest"

    bash "$(engine_dir)/scripts/backup.sh" "$dest"

    echo ""
    info "Backup complete: $dest"
    du -sh "$dest"/* | sed 's/^/  /'
    echo ""
    echo "Restore later with: chengetai restore $DEPLOY_NAME $dest"
    echo ""
}

plugin_restore() {
    require_docker
    require_engine

    local backup="${1:-}"
    if [ -z "$backup" ]; then
        backup=$(ls -1d "$DEPLOY_DIR"/backups/chengetai-backup-* 2>/dev/null | sort | tail -1)
        [ -n "$backup" ] || error "No backups found in $DEPLOY_DIR/backups. Create one with: chengetai backup $DEPLOY_NAME"
        info "No backup specified — using most recent: $backup"
    fi

    [ -f "$backup/koha-db.sql.gz" ] || error "Database dump not found: $backup/koha-db.sql.gz"
    [ -f "$backup/koha-files.tar.gz" ] || error "Koha files archive not found: $backup/koha-files.tar.gz"
    [ -f "$backup/engine-config.tar.gz" ] || error "Engine config archive not found: $backup/engine-config.tar.gz"

    echo "This will REPLACE the current Koha database and data with the contents of:"
    echo ""
    echo "  $backup"
    echo ""
    if ! confirm "Proceed with restore?"; then
        echo "Restore cancelled."
        exit 0
    fi

    bash "$(engine_dir)/scripts/restore.sh" "$backup"

    echo ""
    info "Restore complete."
    echo ""
    plugin_urls
    echo ""
}

plugin_update() {
    require_docker
    require_engine

    info "Refreshing bundled Koha engine files..."
    configure_engine

    bash "$(engine_dir)/scripts/update.sh"
}

plugin_edit() {
    local component="$1"
    local file

    case "$component" in
        config)
            require_engine
            file="$(engine_dir)/.env"
            [ -f "$file" ] || error "File not found: $file"
            echo "Opening: $file"
            echo ""
            "${EDITOR:-nano}" "$file"
            echo ""
            if confirm "Restart Koha now so the change goes live?"; then
                require_docker
                bash "$(engine_dir)/scripts/configure.sh"
                bash "$(engine_dir)/scripts/start.sh"
                echo ""
                info "Koha restarted with the updated configuration."
            else
                echo "Apply later with: chengetai restart $DEPLOY_NAME"
            fi
            ;;
        *)
            error "Unknown component '$component'. Editable components: config"
            ;;
    esac
}

plugin_remove() {
    local purge="${1:-0}"
    if [ -f "$(engine_dir)/docker-compose.yml" ] && [ -f "$(engine_dir)/.env" ]; then
        if [ "$purge" = "1" ]; then
            bash "$(engine_dir)/scripts/uninstall.sh" --purge
        else
            bash "$(engine_dir)/scripts/uninstall.sh"
        fi
    fi
}
