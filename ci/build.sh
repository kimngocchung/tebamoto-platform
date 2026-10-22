#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
RG=rg-tbl-platform-prod-sea
echo "== SITES =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites?api-version=2022-03-01" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('value',[]): print(s['name'], s.get('kind'), s.get('location'))
" 2>/dev/null
for N in $(curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites?api-version=2022-03-01" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(' '.join(s['name'] for s in d.get('value',[])))
" 2>/dev/null); do
  echo "== appsettings $N =="
  curl -sS -H "Authorization: Bearer $ARM" -X POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/${N}/config/appsettings/list?api-version=2022-03-01" | head -c 3000; echo
done
echo "== CONTAINER APPS =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps?api-version=2023-05-01" | head -c 2000; echo
