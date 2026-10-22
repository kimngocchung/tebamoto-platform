#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "== MG LIST =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/providers/Microsoft.Management/managementGroups?api-version=2021-04-01" | head -c 1000; echo
echo "== TENANT ROOT SCOPE ASSIGNMENTS =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01" | head -c 1500; echo
