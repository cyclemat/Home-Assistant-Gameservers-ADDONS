#!/usr/bin/env bash
# Führt alle Mock-Tests aus. Benötigt bash, jq, tar, sha1sum, sha256sum, timeout.
# Unter Windows oder ohne jq: tests/docker.sh
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

rc=0
for t in test_vanilla.sh test_paper.sh; do
  echo "######## ${t}"
  bash "./${t}" || rc=1
  echo
done

if (( rc == 0 )); then echo "ALLE TESTS BESTANDEN"; else echo "TESTS FEHLGESCHLAGEN"; fi
exit "${rc}"
