#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea; N=app-tbl-storefront-prod
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
B="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/${N}"
for P in "config/appsettings?api-version=2022-03-01" "config/slotConfigNames?api-version=2022-03-01" "slots?api-version=2022-03-01" "hostNameBindings?api-version=2022-03-01" "siteextensions?api-version=2022-03-01" "functions?api-version=2022-03-01"; do
  echo "== $P =="
  curl -sS -H "Authorization: Bearer $ARM" "$B/$P" | head -c 1200; echo
done
