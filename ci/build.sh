#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
for A in sttblappcfgprodx3euoz sttblcilogsprodx3euoz; do
  echo "== LISTKEYS $A =="
  curl -sS -H "Authorization: Bearer $ARM" -H "Content-Length: 0" -X POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${A}/listKeys?api-version=2023-01-01" | head -c 700; echo
done
echo "== SITE IDENTITY =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/app-tbl-storefront-prod?api-version=2022-03-01" | python3 -c "
import sys,json
d=json.load(sys.stdin); print('identity:',json.dumps(d.get('identity')))
" 2>/dev/null
echo "== ROLE DEF 17d1049b =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/providers/Microsoft.Authorization/roleDefinitions/17d1049b-9a84-46fb-8f53-869881c3d3ab?api-version=2022-04-01" | python3 -c "
import sys,json
d=json.load(sys.stdin); print(d.get('properties',{}).get('roleName'))
" 2>/dev/null
