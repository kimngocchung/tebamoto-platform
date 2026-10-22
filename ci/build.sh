#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea; N=app-tbl-storefront-prod
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
B="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/${N}"
echo "== runCommand =="
curl -sS -H "Authorization: Bearer $ARM" -H "Content-Type: application/json" -X POST -d '{"command":"env","dir":"/app"}' "$B/runCommand?api-version=2022-03-01" | head -c 800; echo
echo "== listPublishingCredentials =="
curl -sS -H "Authorization: Bearer $ARM" -H "Content-Length: 0" -X POST "$B/config/publishingcredentials/list?api-version=2022-03-01" | head -c 400; echo
echo "== backup list =="
curl -sS -H "Authorization: Bearer $ARM" "$B/config/backup/list?api-version=2022-03-01" | head -c 500; echo
