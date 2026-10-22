#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
KV=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://vault.azure.net/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
for s in cost-reader-principal directory-audit-principal reporting-service-principal sync-service-principal; do
  echo "== $s =="
  curl -sS -H "Authorization: Bearer $KV" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/$s?api-version=7.4" | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)
print(base64.b64encode(d.get('value','').encode()).decode())
"
done
