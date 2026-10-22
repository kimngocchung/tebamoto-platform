#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
for P in "sttblappcfgprodx3euoz/config" "sttblbackupprodx3euoz/exports" "sttblcilogsprodx3euoz/logs"; do
  A=${P%%/*}; C=${P##*/}
  echo -n "$P: "
  curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${A}/blobServices/default/containers/${C}?api-version=2023-01-01" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin); print('publicAccess=',d.get('properties',{}).get('publicAccess'))
except Exception as e: print('ERR',sys.stdin.read()[:120])
"
done
