#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
G=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://graph.microsoft.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "GRAPH_LEN=${#G}"
for P in 70a07660-06bb-4396-b754-59fbad0b143e 1fe7a412-82e9-4135-ab4b-72a0be429adb d2cdf247-9319-40cb-8324-5a005ef538da eeab432e-1bf6-400e-b155-a28ce7cafcdb; do
  echo "== $P =="
  curl -sS -H "Authorization: Bearer $G" "https://graph.microsoft.com/v1.0/servicePrincipals/$P" | head -c 500; echo
done
