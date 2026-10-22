#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"; APP=462d1c38-4459-48b8-9333-82e389e59514
SECRET=$(echo 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
az login --service-principal -u "$APP" -p "$SECRET" --tenant "$TENANT" -o none 2>&1 | tail -2
echo "== LOGS =="
az storage blob list --account-name sttblcilogsprodx3euoz --container-name logs --auth-mode key --query "[].name" -o tsv 2>&1 | head -50
echo "== APPCFG =="
az storage blob list --account-name sttblappcfgprodx3euoz --container-name config --auth-mode key --query "[].name" -o tsv 2>&1 | head -20
echo "== APPCFG CONTENT =="
az storage blob download --account-name sttblappcfgprodx3euoz --container-name config --name internal-config.json --auth-mode key --file - 2>&1 | head -c 1000
echo
echo "== ARCHIVE/BACKUP =="
for A in sttblarchiveprodx3euoz sttblbackupprodx3euoz; do echo "-- $A"; az storage container list --account-name $A --auth-mode key --query "[].name" -o tsv 2>&1 | head -10; done
