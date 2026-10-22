#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "== DEPLOYMENTS =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Resources/deployments?api-version=2021-04-01" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for x in d.get('value',[])[:10]: print(x.get('name'), x.get('properties',{}).get('provisioningState'))
" 2>/dev/null
for D in $(curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Resources/deployments?api-version=2021-04-01" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(' '.join(x.get('name','') for x in d.get('value',[])[:10]))
" 2>/dev/null); do
  echo "== OUTPUTS $D =="
  curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Resources/deployments/${D}?api-version=2021-04-01" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin); o=d.get('properties',{}).get('outputs')
  print(json.dumps(o)[:1500] if o else 'none')
except Exception as e: print('ERR',e)
"
done
