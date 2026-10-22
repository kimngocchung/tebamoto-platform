#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "== WAF POLICY =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/waftblstorefrontprod?api-version=2022-05-01" | head -c 4000; echo
echo "== AFD PROFILE =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Cdn/profiles/afd-tbl-prod?api-version=2021-06-01" | head -c 1000; echo
