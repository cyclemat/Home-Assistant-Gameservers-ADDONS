#!/usr/bin/env bash
# Führt die Mock-Tests in einem Debian-Container aus (keine lokalen Abhängigkeiten nötig).
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v pwd >/dev/null && pwd -W >/dev/null 2>&1; then
  repo="$(cd "${repo}" && pwd -W)"   # Git Bash unter Windows
fi
MSYS_NO_PATHCONV=1 docker run --rm -v "${repo}:/repo:ro" debian:stable-slim bash -c \
  'apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends jq procps >/dev/null && bash /repo/tests/run_all.sh'
