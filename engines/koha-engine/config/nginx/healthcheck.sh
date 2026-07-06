#!/bin/sh
set -eu

wget --no-check-certificate -q --spider https://127.0.0.1:8443/healthz >/dev/null 2>&1 || {
  echo "opac endpoint failed" >&2
  exit 1
}

wget --no-check-certificate -q --spider https://127.0.0.1:9443/healthz >/dev/null 2>&1 || {
  echo "staff endpoint failed" >&2
  exit 1
}
