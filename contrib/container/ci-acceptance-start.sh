#!/bin/bash
set -euo pipefail
: "${RENDER_EXTERNAL_URL:?Dedicated HTTPS Render URL required}"
: "${INVENTREE_ADMIN_PASSWORD:?Generated isolated admin password required}"
: "${CI_INVENTREE_REDIS_URL:?Dedicated cache required}"
: "${INVENTREE_DB_HOST:?Dedicated database required}"
export INVENTREE_SITE_URL="$RENDER_EXTERNAL_URL"
export INVENTREE_WEB_PORT="${PORT:-10000}"
export INVENTREE_DEBUG=False
export INVENTREE_PLUGINS_ENABLED=False
export INVENTREE_GUNICORN_WORKERS=1
export INVENTREE_BACKGROUND_WORKERS=1
# Parse service URL without printing credentials.
export INVENTREE_CACHE_HOST="$(python -c 'import os,urllib.parse; print(urllib.parse.urlsplit(os.environ["CI_INVENTREE_REDIS_URL"]).hostname)')"
export INVENTREE_CACHE_PORT="$(python -c 'import os,urllib.parse; print(urllib.parse.urlsplit(os.environ["CI_INVENTREE_REDIS_URL"]).port or 6379)')"
export INVENTREE_CACHE_PASSWORD="$(python -c 'import os,urllib.parse; print(urllib.parse.unquote(urllib.parse.urlsplit(os.environ["CI_INVENTREE_REDIS_URL"]).password or ""))')"
test -d /home/inventree/data
invoke migrate
invoke static
invoke worker &
worker=$!
gunicorn -c ./gunicorn.conf.py InvenTree.wsgi -b "0.0.0.0:$INVENTREE_WEB_PORT" --chdir "$INVENTREE_BACKEND_DIR/InvenTree" &
web=$!
trap 'kill "$worker" "$web" 2>/dev/null || true' EXIT
wait -n "$worker" "$web"
